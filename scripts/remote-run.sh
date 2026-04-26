#!/bin/bash
# remote-run.sh - Run the experiment on the Proxmox VM and fetch results.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/remote-env.sh"

DURATION="${1:-30}"
LOCAL_RESULTS="${LOCAL_RESULTS:-$REPO_ROOT/results}"

"$SCRIPT_DIR/remote-sync.sh"

ssh -o StrictHostKeyChecking=accept-new -p "$REMOTE_PORT" $SSH_OPTS \
    "$REMOTE_USER@$REMOTE_HOST" bash -s <<EOF
    set -euo pipefail
    cd "$REMOTE_DIR"
    chmod +x scripts/*.sh
    sudo ./scripts/run-all.sh "$DURATION"
    python3 analysis/parse-results.py results/
    python3 analysis/plot-results.py results/
EOF

mkdir -p "$LOCAL_RESULTS"
rsync -az \
    -e "ssh -o StrictHostKeyChecking=accept-new -p $REMOTE_PORT $SSH_OPTS" \
    "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/results/" "$LOCAL_RESULTS/"

echo "Fetched results to $LOCAL_RESULTS"
