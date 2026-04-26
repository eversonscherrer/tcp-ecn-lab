#!/bin/bash
# validate-accecn.sh - Inspect a handshake or active connection in the VM lab.

set -euo pipefail

ACTION="${1:-}"
NS="${NS:-accecn-client}"
IFACE="${IFACE:-veth-client}"
PORT="${2:-5201}"

run_in_ns() {
    ip netns exec "$NS" "$@"
}

case "$ACTION" in
    capture)
        echo "Capturing TCP handshake in $NS on $IFACE port $PORT (Ctrl+C to stop)..."
        run_in_ns tcpdump -i "$IFACE" -nn -vv \
            "tcp port $PORT and (tcp[tcpflags] & tcp-syn != 0)" 2>&1 | head -50
        ;;
    inspect)
        echo "=== ss -tin info in $NS for port $PORT ==="
        run_in_ns ss -tin "( sport = :$PORT or dport = :$PORT )" || true
        echo
        echo "Look for: 'ecn', 'ecnseen', 'accecn' markers in ss output"
        ;;
    *)
        echo "Usage:"
        echo "  NS=accecn-client $0 capture [port]"
        echo "  NS=accecn-client $0 inspect [port]"
        exit 1
        ;;
esac
