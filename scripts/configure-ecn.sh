#!/bin/bash

set -euo pipefail

MODE="${1:-}"
if [[ -z "$MODE" ]]; then
    echo "Usage: $0 {none|classic|accecn}" >&2
    exit 1
fi

apply_sysctl() {
    local key="$1"
    local value="$2"
    local required="${3:-required}"

    if [[ ! -e "/proc/sys/${key//.//}" ]]; then
        if [[ "$required" == "required" ]]; then
            echo "ERROR: $key does not exist on this kernel" >&2
            exit 1
        fi
        echo "$key: missing, skipped"
        return
    fi

    sudo sysctl -w "$key=$value" >/dev/null
    actual="$(sysctl -n "$key")"
    if [[ "$actual" != "$value" ]]; then
        echo "ERROR: $key stayed at $actual, expected $value" >&2
        exit 1
    fi
    echo "$key=$actual"
}

echo "mode=$MODE kernel=$(uname -r)"

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
        echo "Unknown mode: $MODE" >&2
        exit 1
        ;;
esac

sysctl -a 2>/dev/null | grep -E 'net.ipv4.tcp_ecn' || true
