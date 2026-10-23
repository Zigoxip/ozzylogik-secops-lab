#!/usr/bin/env bash
# Read-only firewall runtime summary. No complete rule contents are emitted.
set -euo pipefail
section() { printf '\n## %s\n' "$1"; }

section 'Timestamp UTC'
date -u +'%Y-%m-%dT%H:%M:%SZ'

section 'PVE firewall status'
pve-firewall status

section 'Firewall unit runtime state'
systemctl show pve-firewall proxmox-firewall \
    --property=Id,ActiveState,SubState,UnitFileState,ExecMainStatus

section 'Native nftables table, base chain and rule counts only'
nft -j list ruleset | python3 -c '
import collections, json, sys
data=json.load(sys.stdin)
tables=[]
chains=[]
rules=collections.Counter()
for record in data.get("nftables",[]):
    if "table" in record:
        t=record["table"]
        tables.append({k:t[k] for k in ("family","name") if k in t})
    if "chain" in record:
        c=record["chain"]
        chains.append({k:c[k] for k in ("family","table","name","type","hook","policy","prio") if k in c})
    if "rule" in record:
        r=record["rule"]
        rules[(r.get("family"),r.get("table"),r.get("chain"))]+=1
print(json.dumps({"tables":tables,"chains":chains,"rule_counts":[{"family":k[0],"table":k[1],"chain":k[2],"count":v} for k,v in rules.items()]},indent=2))
'

section 'Legacy iptables chain policies and counts only'
iptables-save | python3 -c '
import collections, json, sys
tables=[]
chains=[]
counts=collections.Counter()
table=None
for line in sys.stdin:
    if line.startswith("*"):
        table=line.strip()[1:]
        tables.append(table)
    elif line.startswith(":"):
        parts=line.split()
        chains.append({"table":table,"chain":parts[0][1:],"policy":parts[1]})
    elif line.startswith("-A "):
        counts[(table,line.split()[1])]+=1
print(json.dumps({"tables":tables,"chains":chains,"rule_counts":[{"table":k[0],"chain":k[1],"count":v} for k,v in counts.items()]},indent=2))
'

printf '\nRead-only firewall summary finished. No rules have been modified.\n'
