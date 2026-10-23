#!/usr/bin/env bash
# Read-only Proxmox resource audit. No authentication secrets or VM configs.
# Run in a trusted Proxmox console. Keep the output local: internal topology.
set -euo pipefail

for tool in pvesh pveversion python3 ip hostname date; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$tool" >&2
        exit 1
    fi
done

section() { printf '\n## %s\n' "$1"; }

# This fixed projection intentionally excludes passwords, public SSH keys,
# cloud-init user data, storage configuration and arbitrary VM configuration.
project_json() {
    python3 -c '
import json, sys
keys = sys.argv[1].split(",")
rows = json.load(sys.stdin)
if not isinstance(rows, list):
    rows = [rows]
print(json.dumps([{k: row[k] for k in keys if k in row} for row in rows], indent=2))
' "$1"
}

section 'Timestamp UTC'
date -u +'%Y-%m-%dT%H:%M:%SZ'

section 'Proxmox version'
pveversion

section 'Node capacities and status'
pvesh get /nodes --output-format json |
    project_json 'node,status,cpu,maxcpu,mem,maxmem,disk,maxdisk'

section 'Existing VM and container IDs (names omitted)'
pvesh get /cluster/resources --type vm --output-format json |
    project_json 'vmid,type,node,status,mem,maxmem,disk,maxdisk,cpu,maxcpu'

section 'Candidate next VMID (not reserved)'
pvesh get /cluster/nextid --output-format json

node_name="$(hostname -s)"
section 'Local node storage capacity and capabilities'
pvesh get "/nodes/${node_name}/storage" --output-format json |
    project_json 'storage,type,active,enabled,shared,content,total,used,avail'

section 'Local node network interfaces and bridges'
pvesh get "/nodes/${node_name}/network" --output-format json |
    project_json 'iface,type,active,autostart,address,netmask,cidr,gateway,bridge_ports,bridge_vlan_aware,mtu'

section 'Current IPv4 routes'
ip -4 route show

section 'Current IPv6 routes'
ip -6 route show

printf '\nRead-only audit finished. No VMID or IP has been reserved.\n'
