#!/usr/bin/env bash
# Explicitly applied only after approval. Run on Proxmox through SSH stdin.
# Arguments: --apply TEMPLATE WEB MON STORAGE BRIDGE BASE64_PUBLIC_KEY
set -euo pipefail
umask 077
if [[ $# -ne 7 || "$1" != --apply ]]; then
    printf 'Usage: bash bootstrap-proxmox.sh --apply TEMPLATE WEB MON STORAGE BRIDGE BASE64_PUBLIC_KEY\n' >&2
    exit 2
fi
template_id="$2"
web_id="$3"
mon_id="$4"
storage_id="$5"
bridge_id="$6"
public_key_b64="$7"
for id in "$template_id" "$web_id" "$mon_id"; do
    [[ "$id" =~ ^[1-9][0-9]+$ ]] || { printf 'Invalid VMID\n' >&2; exit 2; }
done
[[ "$template_id" != "$web_id" && "$template_id" != "$mon_id" && "$web_id" != "$mon_id" ]]
[[ "$storage_id" =~ ^[A-Za-z0-9_-]+$ && "$bridge_id" =~ ^vmbr[0-9]+$ ]]
[[ "$public_key_b64" =~ ^[A-Za-z0-9+/=]+$ ]]

# Validate the source and BOTH target IDs before the first mutation.
qm config "$template_id" | python3 -c '
import sys
c={line.split(":",1)[0]:line.split(":",1)[1].strip() for line in sys.stdin if ":" in line}
assert c.get("template")=="1", "Source is not a template"
assert c.get("name")=="tpl-ubuntu-2404", "Unexpected source template"
assert c.get("ciuser")=="ubuntu" and c.get("ciupgrade")=="0", "Unexpected cloud-init defaults"
assert c.get("serial0")=="socket" and c.get("vga")=="serial0", "Serial console is unavailable"
assert "sshkeys" not in c and "cipassword" not in c, "Unexpected source authentication fields"
'
for target_id in "$web_id" "$mon_id"; do
    pvesh get /cluster/nextid --vmid "$target_id" --output-format json >/dev/null
done

key_file="$(mktemp /run/ozzylogik-public-key.XXXXXX)"
trap 'rm -f -- "$key_file"' EXIT
printf '%s' "$public_key_b64" | base64 -d > "$key_file"
python3 - "$key_file" <<'PY'
from pathlib import Path
import base64, sys
lines=[line.strip() for line in Path(sys.argv[1]).read_text().splitlines() if line.strip()]
assert len(lines)==1, 'Exactly one nonempty public-key line is required'
fields=lines[0].split()
assert len(fields)>=2 and fields[0]=='ssh-ed25519', 'Expected the dedicated ed25519 lab public key'
base64.b64decode(fields[1], validate=True)
PY
ssh-keygen -lf "$key_file" >/dev/null

# Full clones retain no dependency on the template base volume.
# On any failure, retain partial NEW objects for inspection; never auto-delete.
qm clone "$template_id" "$web_id" --full 1 --name ubu1 --storage "$storage_id"
qm set "$web_id" --sockets 1 --cores 2 --cpu host --memory 2048 --balloon 0 \
    --net0 "virtio,bridge=${bridge_id}" --ipconfig0 ip=dhcp \
    --ciuser ubuntu --ciupgrade 0 --sshkeys "$key_file" \
    --agent enabled=1,fstrim_cloned_disks=1 --serial0 socket --vga serial0
qm cloudinit update "$web_id"

qm clone "$template_id" "$mon_id" --full 1 --name ubu2 --storage "$storage_id"
qm set "$mon_id" --sockets 1 --cores 2 --cpu host --memory 4096 --balloon 0 \
    --net0 "virtio,bridge=${bridge_id}" --ipconfig0 ip=dhcp \
    --ciuser ubuntu --ciupgrade 0 --sshkeys "$key_file" \
    --agent enabled=1,fstrim_cloned_disks=1 --serial0 socket --vga serial0
qm resize "$mon_id" scsi0 30G
qm cloudinit update "$mon_id"

# Neither existing VM nor the source template is started, stopped or edited.
qm start "$web_id"
qm start "$mon_id"
printf 'Created and started full clones: ubu1 VMID=%s, ubu2 VMID=%s. DHCP addresses must be discovered.\n' "$web_id" "$mon_id"
