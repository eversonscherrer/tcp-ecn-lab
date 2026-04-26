#!/bin/bash
# run-all.sh - Run none/classic/accecn back-to-back for comparison.
#
# Usage:
#   ./run-all.sh [duration]    # default 30s per run

set -euo pipefail

DURATION="${1:-30}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

for MODE in none classic accecn; do
    echo
    echo "############################################################"
    echo "# Mode: $MODE"
    echo "############################################################"
    "$SCRIPT_DIR/run-experiment.sh" "$MODE" "$DURATION"
    sleep 3
done

echo
echo "All runs complete. Run analysis with:"
echo "  python3 analysis/parse-results.py results/"
echo "  python3 analysis/plot-results.py results/"
