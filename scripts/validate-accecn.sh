#!/bin/bash
# validate-accecn.sh - Inspects an active connection or recent handshake to
# confirm whether AccECN was negotiated.
#
# AccECN handshake signature: SYN with AE+ECE+CWR set; SYN-ACK reflects support.
# Classic ECN: SYN with ECE+CWR; SYN-ACK with ECE only.
# No ECN: neither.
#
# Usage:
#   ./validate-accecn.sh capture <iface> <port>   # capture handshake
#   ./validate-accecn.sh inspect <port>           # ss snapshot

set -euo pipefail

ACTION="${1:-}"

case "$ACTION" in
    capture)
        IFACE="${2:-eth0}"
        PORT="${3:-5201}"
        echo "Capturing TCP handshake on $IFACE port $PORT (Ctrl+C to stop)..."
        # -vv shows full TCP flags including AE bit on supported tcpdump versions
        tcpdump -i "$IFACE" -nn -vv "tcp port $PORT and (tcp[tcpflags] & tcp-syn != 0)" 2>&1 \
            | head -50
        ;;
    inspect)
        PORT="${2:-5201}"
        echo "=== ss -tin info for port $PORT ==="
        ss -tin "( sport = :$PORT or dport = :$PORT )" || true
        echo
        echo "Look for: 'ecn', 'ecnseen', 'accecn' markers in ss output"
        ;;
    *)
        echo "Usage:"
        echo "  $0 capture <iface> <port>   # capture handshake (run before iperf3)"
        echo "  $0 inspect <port>           # snapshot active connection state"
        exit 1
        ;;
esac
