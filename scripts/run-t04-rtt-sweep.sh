#!/bin/bash
# T04 — RTT Sweep (Data Center → WAN)
#
# Tests all ECN modes across increasing one-way delays to evaluate how each
# mode behaves as the Bandwidth-Delay Product grows from DC-like (1 ms) to
# WAN-like (100 ms).
#
# BDP reference (100 Mbit/s × 2×delay):
#   1 ms  RTT →   25 KB BDP
#   5 ms  RTT →  125 KB BDP
#   10 ms RTT →  250 KB BDP
#   25 ms RTT →  625 KB BDP   (baseline)
#   50 ms RTT → 1250 KB BDP
#  100 ms RTT → 2500 KB BDP
#
# Usage:
#   ./scripts/run-t04-rtt-sweep.sh [duration]
#
# Overridable env vars:
#   DURATION      seconds per iperf3 run            (default: 60)
#   DELAYS        space-separated one-way delays     (default: 1ms 5ms 10ms 25ms 50ms 100ms)
#   MODES         space-separated ECN modes          (default: none classic accecn dctcp)
#   RATE          link rate                          (default: 100mbit)
#   ECN_TARGET    fq_codel ECN marking threshold     (default: 5ms)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
require_config

DURATION="${DURATION:-60}"
DELAYS="${DELAYS:-1ms 5ms 10ms 25ms 50ms 100ms}"
MODES="${MODES:-none classic accecn dctcp}"
RATE="${RATE:-100mbit}"
ECN_TARGET="${ECN_TARGET:-5ms}"

n_delays=$(echo "$DELAYS" | wc -w | tr -d ' ')
n_modes=$(echo "$MODES"  | wc -w | tr -d ' ')
total=$(( n_delays * n_modes ))

echo "============================================================"
echo " T04 — RTT Sweep (Data Center → WAN)"
echo "------------------------------------------------------------"
echo " Delays      : $DELAYS"
echo " Modes       : $MODES"
echo " Rate        : $RATE | ECN target: $ECN_TARGET"
echo " Duration    : ${DURATION}s per run"
echo " Total runs  : $total  (~$(( total * (DURATION + 10) / 60 )) min)"
echo "============================================================"

for DELAY in $DELAYS; do
    echo
    echo ">>> Delay = $DELAY  ($(date '+%H:%M:%S'))"
    MODES="$MODES" RATE="$RATE" DELAY="$DELAY" JITTER="0ms" \
        ECN_TARGET="$ECN_TARGET" \
        "$SCRIPT_DIR/run.sh" "$DURATION"
done

echo
echo "============================================================"
echo " T04 complete at $(date '+%H:%M:%S')"
echo " Analyse with:"
echo "   python3 analysis/parse-results.py"
echo "   python3 analysis/plot-t04-rtt-sweep.py"
echo "============================================================"
