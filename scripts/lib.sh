#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -f "$ROOT_DIR/.env" ]]; then
    set -a
    source "$ROOT_DIR/.env"
    set +a
fi

SERVER_HOST="${SERVER_HOST:-}"
SERVER_USER="${SERVER_USER:-}"
SERVER_PORT="${SERVER_PORT:-22}"
CLIENT_HOST="${CLIENT_HOST:-}"
CLIENT_USER="${CLIENT_USER:-}"
CLIENT_PORT="${CLIENT_PORT:-22}"
SERVER_IP="${SERVER_IP:-$SERVER_HOST}"
CLIENT_IP="${CLIENT_IP:-$CLIENT_HOST}"
REMOTE_DIR="${REMOTE_DIR:-/home/$SERVER_USER/accecn-tcp-experiment}"
SSH_OPTS="${SSH_OPTS:-}"

require_config() {
    local missing=0
    for var in SERVER_HOST SERVER_USER CLIENT_HOST CLIENT_USER; do
        if [[ -z "${!var:-}" ]]; then
            echo "Missing $var. Create/edit .env first." >&2
            missing=1
        fi
    done
    if [[ "$missing" -ne 0 ]]; then
        exit 1
    fi
}

server_ssh() {
    ssh -o StrictHostKeyChecking=accept-new -p "$SERVER_PORT" $SSH_OPTS \
        "$SERVER_USER@$SERVER_HOST" "$@"
}

client_ssh() {
    ssh -o StrictHostKeyChecking=accept-new -p "$CLIENT_PORT" $SSH_OPTS \
        "$CLIENT_USER@$CLIENT_HOST" "$@"
}

rsync_common_args() {
    printf '%s\n' \
        --delete \
        --exclude=.git/ \
        --exclude=.env \
        --exclude=results/ \
        --exclude=__pycache__/
}
