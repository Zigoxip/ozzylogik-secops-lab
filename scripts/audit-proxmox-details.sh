#!/usr/bin/env bash
# Read-only follow-up. Selected fields only; never dump complete VM configs.
set -euo pipefail

section() { printf '\n## %s\n' "$1"; }
project_json() {
    python3 -c '
import json, sys
keys = sys.argv[1].split(",")
data = json.load(sys.stdin)
if not isinstance(data, list):
    data = [data]
print(json.dumps([{k: row[k] for k in keys if k in row} for row in data], indent=2))
' "$1"
}
node_name="$(hostname -s)"

section 'Timestamp UTC'
date -u +'%Y-%m-%dT%H:%M:%SZ'

section 'Available memory (current, not a reservation)'
free -b

section 'Thin pool usage and metadata'
lvs --units b --nosuffix --reportformat json \
    -o vg_name,lv_name,lv_size,segtype,data_percent,metadata_percent

section 'Volume group free space'
vgs --units b --nosuffix --reportformat json -o vg_name,vg_size,vg_free

section 'Explicit candidate VMID checks (not reservations)'
for candidate in 101 102; do
    pvesh get /cluster/nextid --vmid "$candidate" --output-format json
done

section 'Existing candidate template: non-secret config projection'
pvesh get "/nodes/${node_name}/qemu/9000/config" --output-format json |
    project_json 'template,ostype,agent,cores,memory,scsihw,scsi0,sata0,ide2,boot'

section 'Cluster firewall options (selected)'
pvesh get /cluster/firewall/options --output-format json |
    project_json 'enable,policy_in,policy_out'

section 'Node firewall options (selected)'
pvesh get "/nodes/${node_name}/firewall/options" --output-format json |
    project_json 'enable,policy_in,policy_out,ndp,ipfilter'

section 'Firewall service runtime (read only)'
systemctl is-active pve-firewall proxmox-firewall || true

section 'Known IPv4 neighbors on the existing LAN bridge (no probes)'
ip -4 neigh show dev vmbr0

printf '\nRead-only details finished. Existing template was not changed or cloned.\n'
