#!/bin/bash
# vm-sync.sh - Sync this repository into the VirtualBox lab VM.

set -euo pipefail

VM_USER="${VM_USER:-accecn}"
SSH_HOST="${SSH_HOST:-127.0.0.1}"
SSH_PORT="${SSH_PORT:-2222}"
REMOTE_DIR="${REMOTE_DIR:-/home/$VM_USER/accecn-tcp-experiment}"

rsync -az --delete \
    --exclude ".git/" \
    --exclude "results/" \
    --exclude "__pycache__/" \
    -e "ssh -o StrictHostKeyChecking=accept-new -p $SSH_PORT" \
    ./ "$VM_USER@$SSH_HOST:$REMOTE_DIR/"
