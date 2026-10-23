#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
venv_dir="${HOME}/.local/share/ozzylogik/venv"
if [[ ! -x "${venv_dir}/bin/ansible-playbook" ]]; then
    printf 'Prepare the pinned WSL controller environment first.\n' >&2
    exit 1
fi
# DrvFS may report the checkout as world-writable. Trust this exact project
# configuration explicitly instead of relaxing host-key checking or permissions.
export ANSIBLE_CONFIG="${project_dir}/ansible/ansible.cfg"
cd -- "${project_dir}/ansible"
exec "${venv_dir}/bin/ansible-playbook" "$@"
