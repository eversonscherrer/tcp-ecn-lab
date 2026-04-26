#!/bin/bash
# configure-ecn.sh - Set TCP ECN mode in the current Linux namespace.
#
# Run inside the Linux VM. Use NS=<netns> to target a network namespace.
#
# Usage:
#   ./configure-ecn.sh none      # ECN disabled
#   ./configure-ecn.sh classic   # Classic ECN (RFC 3168)
#   ./configure-ecn.sh accecn    # Accurate ECN (RFC 9768)

set -euo pipefail

MODE="${1:-}"
NS="${NS:-}"

if [[ -z "$MODE" ]]; then
    echo "Usage: $0 {none|classic|accecn}"
    exit 1
fi

run_in_ns() {
    if [[ -n "$NS" ]]; then
        ip netns exec "$NS" "$@"
    else
        "$@"
    fi
}

sysctl_exists() {
    run_in_ns test -e "/proc/sys/${1//.//}"
}

sysctl_get() {
    run_in_ns sysctl -n "$1"
}

sysctl_set() {
    run_in_ns sysctl -w "$1=$2" >/dev/null
}

apply_sysctl() {
    local key="$1"
    local val="$2"
    local required="${3:-required}"
    if sysctl_exists "$key"; then
        sysctl_set "$key" "$val"
        actual="$(sysctl_get "$key")"
        if [[ "$actual" != "$val" ]]; then
            echo "  ERROR: ${key} stayed at ${actual}; expected ${val}" >&2
            exit 1
        fi
        echo "  ${key} = ${actual}"
    else
        if [[ "$required" == "required" ]]; then
            echo "  ERROR: ${key} is not available on this kernel" >&2
            exit 1
        fi
        echo "  ${key} -> not available on this kernel (skipping)"
    fi
}

target="${NS:-root namespace}"
echo "=== Applying ECN mode: $MODE in $target ==="
echo "Kernel: $(uname -r)"

case "$MODE" in
    none)
        apply_sysctl net.ipv4.tcp_ecn 0
        apply_sysctl net.ipv4.tcp_ecn_option 0 optional
        ;;
    classic)
        apply_sysctl net.ipv4.tcp_ecn 1
        apply_sysctl net.ipv4.tcp_ecn_option 0 optional
        ;;
    accecn)
        apply_sysctl net.ipv4.tcp_ecn 1
        apply_sysctl net.ipv4.tcp_ecn_option 2
        ;;
    *)
        echo "Unknown mode: $MODE"
        exit 1
        ;;
esac

echo "=== Current ECN-related sysctls ==="
run_in_ns sysctl -a 2>/dev/null | grep -E "tcp_ecn" || true
