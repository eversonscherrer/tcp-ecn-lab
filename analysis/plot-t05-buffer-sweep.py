#!/usr/bin/env python3
"""T05 — Buffer Sweep: throughput and CE marks vs fq_codel target and buffer limit.

2x2 layout for conference embedding:
  (0,0) Throughput — buffer=100    (0,1) Throughput — buffer=1000
  (1,0) CE Marks   — buffer=100    (1,1) CE Marks   — buffer=1000

Usage:
    python3 analysis/plot-t05-buffer-sweep.py [--results results/summary.csv]
                                               [--output  docs/t05-buffer-sweep.png]
"""

import argparse
import csv
import re
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import matplotlib.ticker as mticker
import numpy as np

MODE_ORDER  = ["none", "classic", "accecn", "dctcp"]
MODE_COLORS = {"none": "#e74c3c", "classic": "#3498db",
               "accecn": "#2ecc71", "dctcp": "#f39c12"}
MODE_LABELS = {"none": "No ECN", "classic": "Classic ECN",
               "accecn": "AccECN",  "dctcp": "DCTCP+AccECN"}
MODE_MARKERS = {"none": "s", "classic": "o", "accecn": "^", "dctcp": "D"}

TARGET_ORDER = ["1ms", "5ms", "20ms", "50ms"]
BUFFER_LIMITS = ["100", "1000"]


def target_to_ms(t: str) -> float:
    m = re.match(r"(\d+(?:\.\d+)?)\s*ms", t, re.IGNORECASE)
    return float(m.group(1)) if m else float("nan")


def load(csv_path: Path) -> list[dict]:
    rows = []
    with csv_path.open() as f:
        for row in csv.DictReader(f):
            bl   = row.get("buffer_limit", "").strip()
            cc   = row.get("cc_algo", "").strip()
            loss = row.get("loss", "").strip()
            streams = row.get("streams", "").strip()
            dur  = float(row.get("duration_s", 0) or 0)
            # T05 rows: buffer_limit set, single stream (streams=1 or blank),
            # no cc_algo override, no loss, full 60 s runs
            if bl and not cc and loss in ("0%", "") and dur >= 30:
                if not streams or streams == "1":
                    rows.append(row)
    return rows


def aggregate(rows, target, mode, buffer_limit, metric) -> float | None:
    vals = []
    for r in rows:
        if (r.get("ecn_target") == target
                and r.get("mode") == mode
                and r.get("buffer_limit") == str(buffer_limit)):
            try:
                vals.append(float(r[metric]))
            except (ValueError, KeyError):
                pass
    return float(np.mean(vals)) if vals else None


def draw_panel(ax, rows, targets, modes, buffer_limit, metric, ylabel,
               reference=None, silence_zone_target=None):
    target_ms = [target_to_ms(t) for t in targets]
    for mode in modes:
        y = [aggregate(rows, t, mode, buffer_limit, metric) for t in targets]
        ax.plot(target_ms, y,
                marker=MODE_MARKERS[mode],
                color=MODE_COLORS[mode],
                label=MODE_LABELS[mode],
                linewidth=2, markersize=8)

    if silence_zone_target is not None:
        sz_ms = target_to_ms(silence_zone_target)
        ax.axvspan(sz_ms * 0.6, sz_ms * 1.7, alpha=0.08, color="gray",
                   label="_nolegend_")
        ax.annotate("silence\nzone", xy=(sz_ms, ax.get_ylim()[1] * 0.92),
                    ha="center", va="top", fontsize=7.5,
                    color="gray",
                    xytext=(sz_ms, ax.get_ylim()[1] * 0.92))

    if reference is not None:
        ax.axhline(reference, color="black", linestyle="--",
                   linewidth=1, alpha=0.5, label=f"Link rate ({reference} Mbps)")

    ax.set_xlabel("fq_codel target (ms)", fontsize=9)
    ax.set_ylabel(ylabel, fontsize=9)
    ax.set_xscale("log")
    ax.xaxis.set_major_formatter(mticker.FuncFormatter(lambda v, _: f"{v:g}"))
    ax.set_xticks(target_ms)
    ax.tick_params(axis="both", labelsize=8)
    ax.legend(fontsize=8, loc="best")
    ax.grid(True, alpha=0.3, which="both")
    ax.set_ylim(bottom=0)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--results", default="results/summary.csv")
    ap.add_argument("--output",  default="docs/t05-buffer-sweep.png")
    args = ap.parse_args()

    csv_path = Path(args.results)
    if not csv_path.exists():
        print(f"File not found: {csv_path}", file=sys.stderr)
        return 1

    rows = load(csv_path)
    if not rows:
        print("No T05 rows found. Run parse-results.py after T05 experiments.",
              file=sys.stderr)
        return 1

    targets = [t for t in TARGET_ORDER
               if any(r.get("ecn_target") == t for r in rows)]
    modes   = [m for m in MODE_ORDER
               if any(r.get("mode") == m for r in rows)]

    fig, axes = plt.subplots(2, 2, figsize=(13, 8))

    # ---- top row: Throughput ----
    for col, bl in enumerate(BUFFER_LIMITS):
        ax = axes[0, col]
        draw_panel(ax, rows, targets, modes, bl,
                   "throughput_recv_mbps",
                   "Throughput (Mbps)",
                   reference=100,
                   silence_zone_target=("20ms" if bl == "100" else None))
        ax.set_title(f"Throughput — buffer limit = {bl} pkts",
                     fontsize=10, fontweight="bold")

    # ---- bottom row: CE Marks ----
    for col, bl in enumerate(BUFFER_LIMITS):
        ax = axes[1, col]
        draw_panel(ax, rows, targets, modes, bl,
                   "ecn_mark",
                   "CE Marks (total, 60 s)",
                   silence_zone_target=("20ms" if bl == "100" else None))
        ax.set_title(f"CE Marks — buffer limit = {bl} pkts",
                     fontsize=10, fontweight="bold")

    fig.suptitle(
        "T05 — fq_codel Buffer and Target Sweep\n"
        "100 Mbps · 25 ms RTT · 0 % loss · 60 s runs",
        fontsize=12, fontweight="bold",
    )
    plt.tight_layout(rect=[0, 0, 1, 0.93])

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(out, dpi=180, bbox_inches="tight")
    print(f"Saved: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
