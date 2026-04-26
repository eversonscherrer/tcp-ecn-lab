#!/bin/bash
# setup-network.sh - Apply tc qdiscs to emulate a congested server->client link.
#
# Run inside the Linux VM as root. Defaults target the server namespace created
# by setup-lab.sh.

set -euo pipefail

NS="${NS:-accecn-server}"
IFACE="${IFACE:-veth-server}"
RATE="${RATE:-100mbit}"
DELAY="${DELAY:-25ms}"
JITTER="${JITTER:-2ms}"
LOSS="${LOSS:-0%}"

ACTION="${1:-apply}"

run_tc() {
    if [[ -n "$NS" ]]; then
        ip netns exec "$NS" tc "$@"
    else
        tc "$@"
    fi
}

cleanup_partial() {
    run_tc qdisc del dev "$IFACE" root 2>/dev/null || true
}

fail_apply() {
    cleanup_partial
    echo "ERROR: failed to apply qdisc tree." >&2
    echo "This kernel must support htb, netem, and fq_codel with ECN." >&2
    exit 1
}

case "$ACTION" in
    apply)
        trap fail_apply ERR

        echo "=== Applying network impairment on ${NS:-root}:$IFACE ==="
        echo "  rate=$RATE delay=$DELAY jitter=$JITTER loss=$LOSS"

        cleanup_partial

        run_tc qdisc add dev "$IFACE" root handle 1: htb default 10
        run_tc class add dev "$IFACE" parent 1: classid 1:10 htb \
            rate "$RATE" ceil "$RATE"
        run_tc qdisc add dev "$IFACE" parent 1:10 handle 10: \
            netem delay "$DELAY" "$JITTER" loss "$LOSS"
        run_tc qdisc add dev "$IFACE" parent 10:1 handle 100: \
            fq_codel ecn limit 1000 target 5ms

        echo "=== Final qdisc tree ==="
        run_tc -s qdisc show dev "$IFACE"
        run_tc -s class show dev "$IFACE"

        trap - ERR
        ;;
    clear)
        cleanup_partial
        echo "Cleared qdisc on ${NS:-root}:$IFACE"
        ;;
    show)
        run_tc -s qdisc show dev "$IFACE"
        run_tc -s class show dev "$IFACE"
        ;;
    *)
        echo "Usage: $0 {apply|clear|show}"
        exit 1
        ;;
esac
