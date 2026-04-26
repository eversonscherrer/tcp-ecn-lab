#!/bin/bash
# setup-network.sh - Apply tc qdiscs to emulate a congested link.
#
# Uses fq_codel with ECN marking enabled, which is what makes ECN actually
# useful: without an AQM that marks packets, ECN/AccECN have nothing to do.
#
# Usage:
#   ./setup-network.sh apply    # apply impairment
#   ./setup-network.sh clear    # remove all qdiscs
#   ./setup-network.sh show     # show current qdisc
#
# Tunables (env vars):
#   IFACE       - interface (default: eth0)
#   RATE        - bottleneck rate (default: 100mbit)
#   DELAY       - one-way delay (default: 25ms)
#   JITTER      - jitter (default: 2ms)
#   LOSS        - random loss (default: 0%)

set -euo pipefail

IFACE="${IFACE:-eth0}"
RATE="${RATE:-100mbit}"
DELAY="${DELAY:-25ms}"
JITTER="${JITTER:-2ms}"
LOSS="${LOSS:-0%}"

ACTION="${1:-apply}"

case "$ACTION" in
    apply)
        echo "=== Applying network impairment on $IFACE ==="
        echo "  rate=$RATE delay=$DELAY jitter=$JITTER loss=$LOSS"

        # Clear any existing qdisc first
        tc qdisc del dev "$IFACE" root 2>/dev/null || true

        # Hierarchical: HTB rate-limits to create congestion, fq_codel does ECN marking
        tc qdisc add dev "$IFACE" root handle 1: htb default 10
        tc class add dev "$IFACE" parent 1: classid 1:10 htb \
            rate "$RATE" ceil "$RATE"
        tc qdisc add dev "$IFACE" parent 1:10 handle 10: \
            fq_codel ecn limit 1000 target 5ms

        # netem on top adds delay/jitter/loss
        tc qdisc add dev "$IFACE" parent 10: handle 100: \
            netem delay "$DELAY" "$JITTER" loss "$LOSS"

        echo "=== Final qdisc tree ==="
        tc -s qdisc show dev "$IFACE"
        ;;
    clear)
        tc qdisc del dev "$IFACE" root 2>/dev/null || true
        echo "Cleared qdisc on $IFACE"
        ;;
    show)
        tc -s qdisc show dev "$IFACE"
        tc -s class show dev "$IFACE"
        ;;
    *)
        echo "Usage: $0 {apply|clear|show}"
        exit 1
        ;;
esac
