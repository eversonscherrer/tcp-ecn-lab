#!/bin/bash
# vm-ssh.sh - SSH into the VirtualBox lab VM.

set -euo pipefail

VM_USER="${VM_USER:-accecn}"
SSH_HOST="${SSH_HOST:-127.0.0.1}"
SSH_PORT="${SSH_PORT:-2222}"

exec ssh -o StrictHostKeyChecking=accept-new -p "$SSH_PORT" "$VM_USER@$SSH_HOST" "$@"
