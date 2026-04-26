#!/bin/bash
# configure-ecn.sh - Sets the ECN mode inside the current container.
#
# Usage:
#   ./configure-ecn.sh none      # ECN disabled
#   ./configure-ecn.sh classic   # Classic ECN (RFC 3168)
#   ./configure-ecn.sh accecn    # Accurate ECN (RFC 9768)
#
# Note: Linux containers share the host kernel. These sysctls need to be set
# on the host or via container --sysctl. Some keys (tcp_ecn_option) only exist
# on kernels with AccECN support (>= 6.18).

set -euo pipefail

MODE="${1:-}"

if [[ -z "$MODE" ]]; then
    echo "Usage: $0 {none|classic|accecn}"
    exit 1
fi

apply_sysctl() {
    local key="$1"
    local val="$2"
    if [[ -e "/proc/sys/${key//.//}" ]]; then
        sysctl -w "${key}=${val}" >/dev/null
        echo "  ${key} = ${val}"
    else
        echo "  ${key} -> not available on this kernel (skipping)"
    fi
}

echo "=== Applying ECN mode: $MODE ==="
echo "Kernel: $(uname -r)"

case "$MODE" in
    none)
        apply_sysctl net.ipv4.tcp_ecn 0
        apply_sysctl net.ipv4.tcp_ecn_option 0
        ;;
    classic)
        # tcp_ecn=1: enable ECN both directions
        # tcp_ecn_option=0: do NOT request AccECN extension
        apply_sysctl net.ipv4.tcp_ecn 1
        apply_sysctl net.ipv4.tcp_ecn_option 0
        ;;
    accecn)
        # tcp_ecn=1: enable ECN both directions
        # tcp_ecn_option=2: actively request AccECN (RFC 9768)
        apply_sysctl net.ipv4.tcp_ecn 1
        apply_sysctl net.ipv4.tcp_ecn_option 2
        ;;
    *)
        echo "Unknown mode: $MODE"
        exit 1
        ;;
esac

echo "=== Current ECN-related sysctls ==="
sysctl -a 2>/dev/null | grep -E "tcp_ecn" || true
