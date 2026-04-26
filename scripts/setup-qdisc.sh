#!/bin/bash

set -euo pipefail

ACTION="${1:-apply}"
IFACE="${IFACE:-}"
RATE="${RATE:-100mbit}"
DELAY="${DELAY:-25ms}"
JITTER="${JITTER:-2ms}"
LOSS="${LOSS:-0%}"

if [[ -z "$IFACE" ]]; then
    echo "Set IFACE=<server interface>" >&2
    exit 1
fi

clear_qdisc() {
    sudo tc qdisc del dev "$IFACE" root 2>/dev/null || true
}

case "$ACTION" in
    apply)
        clear_qdisc
        sudo tc qdisc add dev "$IFACE" root handle 1: htb default 10
        sudo tc class add dev "$IFACE" parent 1: classid 1:10 htb rate "$RATE" ceil "$RATE"
        sudo tc qdisc add dev "$IFACE" parent 1:10 handle 10: netem delay "$DELAY" "$JITTER" loss "$LOSS"
        sudo tc qdisc add dev "$IFACE" parent 10:1 handle 100: fq_codel ecn limit 1000 target 5ms
        sudo tc -s qdisc show dev "$IFACE"
        sudo tc -s class show dev "$IFACE"
        ;;
    clear)
        clear_qdisc
        ;;
    show)
        sudo tc -s qdisc show dev "$IFACE"
        sudo tc -s class show dev "$IFACE"
        ;;
    *)
        echo "Usage: $0 {apply|clear|show}" >&2
        exit 1
        ;;
esac
