#!/bin/bash
# setup-lab.sh - Create/clear Linux network namespaces for the experiment.
#
# Run inside the Linux VM as root.

set -euo pipefail

ACTION="${1:-apply}"

CLIENT_NS="${CLIENT_NS:-accecn-client}"
SERVER_NS="${SERVER_NS:-accecn-server}"
CLIENT_IFACE="${CLIENT_IFACE:-veth-client}"
SERVER_IFACE="${SERVER_IFACE:-veth-server}"
CLIENT_IP="${CLIENT_IP:-10.99.0.20/24}"
SERVER_IP="${SERVER_IP:-10.99.0.10/24}"

clear_lab() {
    ip netns pids "$CLIENT_NS" 2>/dev/null | xargs -r kill 2>/dev/null || true
    ip netns pids "$SERVER_NS" 2>/dev/null | xargs -r kill 2>/dev/null || true
    ip netns del "$CLIENT_NS" 2>/dev/null || true
    ip netns del "$SERVER_NS" 2>/dev/null || true
}

case "$ACTION" in
    apply)
        clear_lab

        ip netns add "$CLIENT_NS"
        ip netns add "$SERVER_NS"

        ip link add "$CLIENT_IFACE" type veth peer name "$SERVER_IFACE"
        ip link set "$CLIENT_IFACE" netns "$CLIENT_NS"
        ip link set "$SERVER_IFACE" netns "$SERVER_NS"

        ip -n "$CLIENT_NS" addr add "$CLIENT_IP" dev "$CLIENT_IFACE"
        ip -n "$SERVER_NS" addr add "$SERVER_IP" dev "$SERVER_IFACE"

        ip -n "$CLIENT_NS" link set lo up
        ip -n "$SERVER_NS" link set lo up
        ip -n "$CLIENT_NS" link set "$CLIENT_IFACE" up
        ip -n "$SERVER_NS" link set "$SERVER_IFACE" up

        echo "Created namespaces:"
        ip netns list | grep -E "^(${CLIENT_NS}|${SERVER_NS})"
        ;;
    clear)
        clear_lab
        echo "Cleared lab namespaces"
        ;;
    show)
        ip netns list
        ip -n "$CLIENT_NS" addr show 2>/dev/null || true
        ip -n "$SERVER_NS" addr show 2>/dev/null || true
        ;;
    *)
        echo "Usage: $0 {apply|clear|show}"
        exit 1
        ;;
esac
