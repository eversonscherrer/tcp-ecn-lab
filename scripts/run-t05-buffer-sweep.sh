#!/bin/bash
# T05 — Buffer / fq_codel Target Sweep
#
# Varies the fq_codel ECN marking threshold (target) and queue size limit
# to show the trade-off between latency (bufferbloat), throughput, and
# marking frequency for each ECN mode.
#
# Two-dimensional sweep:
#   ECN_TARGETS  : marking threshold (controls sojourn-time → latency)
#   BUFFER_LIMITS: fq_codel queue depth in packets (controls tail-drop point)
#
# Usage:
#   ./scripts/run-t05-buffer-sweep.sh [duration]
#
# Overridable env vars:
#   DURATION       seconds per iperf3 run                    (default: 60)
#   ECN_TARGETS    space-separated fq_codel targets          (default: 1ms 5ms 20ms 50ms)
#   BUFFER_LIMITS  space-separated fq_codel queue limits     (default: 100 1000)
#   MODES          space-separated ECN modes                 (default: none classic accecn dctcp)
#   RATE           link rate                                  (default: 100mbit)
#   DELAY          one-way netem delay                       (default: 25ms)
#   JITTER         netem jitter                              (default: 2ms)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib.sh"
require_config

DURATION="${DURATION:-60}"
ECN_TARGETS="${ECN_TARGETS:-1ms 5ms 20ms 50ms}"
BUFFER_LIMITS="${BUFFER_LIMITS:-100 1000}"
MODES="${MODES:-none classic accecn dctcp}"
RATE="${RATE:-100mbit}"
DELAY="${DELAY:-25ms}"
JITTER="${JITTER:-2ms}"

n_targets=$(echo "$ECN_TARGETS"  | wc -w | tr -d ' ')
n_limits=$(echo  "$BUFFER_LIMITS" | wc -w | tr -d ' ')
n_modes=$(echo   "$MODES"         | wc -w | tr -d ' ')
total=$(( n_targets * n_limits * n_modes ))

echo "============================================================"
echo " T05 — Buffer / fq_codel Target Sweep"
echo "------------------------------------------------------------"
echo " ECN targets   : $ECN_TARGETS"
echo " Buffer limits : $BUFFER_LIMITS packets"
echo " Modes         : $MODES"
echo " Rate          : $RATE | Delay: $DELAY ± $JITTER"
echo " Duration      : ${DURATION}s per run"
echo " Total runs    : $total  (~$(( total * (DURATION + 10) / 60 )) min)"
echo "============================================================"

for BLIMIT in $BUFFER_LIMITS; do
    for TARGET in $ECN_TARGETS; do
        echo
        echo ">>> buffer_limit=$BLIMIT  ecn_target=$TARGET  ($(date '+%H:%M:%S'))"
        MODES="$MODES" RATE="$RATE" DELAY="$DELAY" JITTER="$JITTER" \
            ECN_TARGET="$TARGET" BUFFER_LIMIT="$BLIMIT" \
            "$SCRIPT_DIR/run.sh" "$DURATION"
    done
done

echo
echo "============================================================"
echo " T05 complete at $(date '+%H:%M:%S')"
echo " Analyse with:"
echo "   python3 analysis/parse-results.py"
echo "   python3 analysis/plot-t05-buffer-sweep.py"
echo "============================================================"
