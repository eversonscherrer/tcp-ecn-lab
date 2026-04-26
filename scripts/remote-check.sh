#!/bin/bash
# remote-check.sh - Check SSH access and basic VM capabilities.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/remote-env.sh"

command -v ssh >/dev/null || {
    echo "ssh not found on this machine." >&2
    exit 1
}

command -v rsync >/dev/null || {
    echo "rsync not found on this machine." >&2
    exit 1
}

echo "Checking SSH: $REMOTE_USER@$REMOTE_HOST:$REMOTE_PORT"
ssh_cmd bash -lc '
    set -euo pipefail
    echo "Host: $(hostname)"
    echo "Kernel: $(uname -r)"
    echo "Arch: $(uname -m)"
    command -v sudo >/dev/null && echo "sudo: ok" || echo "sudo: missing"
    command -v ip >/dev/null && echo "iproute2: ok" || echo "iproute2: missing"
    command -v tc >/dev/null && echo "tc: ok" || echo "tc: missing"
    command -v iperf3 >/dev/null && echo "iperf3: ok" || echo "iperf3: missing"
    if sysctl net.ipv4.tcp_ecn_option >/dev/null 2>&1; then
        sysctl net.ipv4.tcp_ecn_option
    else
        echo "tcp_ecn_option: missing"
    fi
'
