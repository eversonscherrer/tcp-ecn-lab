#!/bin/bash
# remote-env.sh - Shared SSH settings for Proxmox VM helper scripts.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$REPO_ROOT/.env" ]]; then
    set -a
    source "$REPO_ROOT/.env"
    set +a
fi

REMOTE_HOST="${REMOTE_HOST:-}"
REMOTE_USER="${REMOTE_USER:-accecn}"
REMOTE_PORT="${REMOTE_PORT:-22}"
REMOTE_DIR="${REMOTE_DIR:-/home/$REMOTE_USER/accecn-tcp-experiment}"
SSH_OPTS="${SSH_OPTS:-}"

if [[ -z "$REMOTE_HOST" ]]; then
    echo "Set REMOTE_HOST to the Proxmox VM IP or DNS name." >&2
    echo "Example: REMOTE_HOST=192.168.1.50 REMOTE_USER=accecn $0" >&2
    exit 1
fi

ssh_cmd() {
    ssh -o StrictHostKeyChecking=accept-new -p "$REMOTE_PORT" $SSH_OPTS \
        "$REMOTE_USER@$REMOTE_HOST" "$@"
}

rsync_ssh() {
    rsync -az --delete \
        --exclude ".git/" \
        --exclude "results/" \
        --exclude "__pycache__/" \
        -e "ssh -o StrictHostKeyChecking=accept-new -p $REMOTE_PORT $SSH_OPTS" \
        "$@"
}
