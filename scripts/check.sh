#!/bin/bash

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
require_config

check_one() {
    local label="$1"
    local peer_ip="$2"
    shift 2

    echo
    echo "=== $label ==="
    "$@" bash -c "
        set -e
        echo \"host: \$(hostname)\"
        echo \"kernel: \$(uname -r)\"
        echo \"arch: \$(uname -m)\"
        ip route get '$peer_ip' || true
        for cmd in sudo ip tc iperf3 tcpdump ss python3; do
            command -v \"\$cmd\" >/dev/null && echo \"\$cmd: ok\" || echo \"\$cmd: missing\"
        done
        sudo -n true >/dev/null 2>&1 && echo \"sudo nopasswd: ok\" || echo \"sudo nopasswd: missing\"
        sysctl net.ipv4.tcp_ecn || true
        sysctl net.ipv4.tcp_ecn_option || true
    "
}

check_one "accecn1/server" "$CLIENT_IP" server_ssh
check_one "accecn2/client" "$SERVER_IP" client_ssh

echo
echo "=== ping client -> server ==="
client_ssh "ping -c 2 '$SERVER_IP'"
