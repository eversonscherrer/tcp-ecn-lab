#!/bin/bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
require_config

exec ssh -o StrictHostKeyChecking=accept-new -p "$CLIENT_PORT" $SSH_OPTS \
    "$CLIENT_USER@$CLIENT_HOST" "$@"
