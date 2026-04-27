#!/bin/bash

set -euo pipefail

MODE="${1:-}"
if [[ -z "$MODE" ]]; then
    echo "Usage: $0 {none|classic|accecn|dctcp}" >&2
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

# Always reset congestion control to cubic first so previous runs don't bleed over
sudo sysctl -w net.ipv4.tcp_congestion_control=cubic >/dev/null 2>&1 || true

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
        apply_sysctl net.ipv4.tcp_ecn 3
        apply_sysctl net.ipv4.tcp_ecn_option 2
        ;;
    dctcp)
        apply_sysctl net.ipv4.tcp_ecn 3
        apply_sysctl net.ipv4.tcp_ecn_option 2
        sudo modprobe tcp_dctcp 2>/dev/null || true
        apply_sysctl net.ipv4.tcp_congestion_control dctcp
        ;;
    *)
        echo "Unknown mode: $MODE" >&2
        exit 1
        ;;
esac

sysctl -a 2>/dev/null | grep -E 'net.ipv4.tcp_ecn|tcp_congestion_control' || true
