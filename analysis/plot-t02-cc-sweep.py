#!/usr/bin/env python3
"""T02 — CC Algorithm Sweep: compare Cubic, Reno, BBR and DCTCP across ECN modes.

Reads summary.csv and produces a 4-panel figure:
  1. Throughput heatmap  (CC algo × ECN mode)
  2. Grouped bar chart   (throughput per CC, coloured by ECN mode)
  3. Retransmissions     (grouped bar, same layout)
  4. Mean RTT            (grouped bar, same layout)

Usage:
    python3 analysis/plot-t02-cc-sweep.py [--results results/summary.csv]
                                           [--output  results/t02-cc-sweep.png]
"""

import argparse
import csv
import sys
from pathlib import Path

import matplotlib
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np

# ── colour palettes ────────────────────────────────────────────────────────────
MODE_COLORS = {
    "none":    "#e74c3c",
    "classic": "#3498db",
    "accecn":  "#2ecc71",
    "dctcp":   "#f39c12",
}
MODE_LABELS = {
    "none":    "No ECN",
    "classic": "Classic ECN",
    "accecn":  "AccECN",
    "dctcp":   "DCTCP",
}

# canonical display order
CC_ORDER    = ["cubic", "reno", "bbr", "dctcp"]
MODE_ORDER  = ["none", "classic", "accecn", "dctcp"]


def _effective_cc(row: dict) -> str:
    """Return the actual CC used: explicit cc_algo if set, else mode=dctcp → 'dctcp'."""
    cc = row.get("cc_algo", "").strip()
    if cc:
        return cc
    if row.get("mode", "") == "dctcp":
        return "dctcp"
    return "cubic"   # default when cc_algo is blank and mode != dctcp


def load(csv_path: Path) -> list[dict]:
    rows = []
    with csv_path.open() as f:
        for row in csv.DictReader(f):
            # Only include T02 rows: those with an explicit cc_algo OR dctcp mode
            cc = row.get("cc_algo", "").strip()
            mode = row.get("mode", "").strip()
            if cc or mode == "dctcp":
                rows.append(row)
    return rows


def aggregate(rows, cc: str, mode: str, metric: str) -> float | None:
    vals = []
    for r in rows:
        if _effective_cc(r) == cc and r.get("mode", "") == mode:
            try:
                v = float(r[metric])
                vals.append(v)
            except (ValueError, KeyError):
                pass
    return float(np.mean(vals)) if vals else None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--results", default="results/summary.csv")
    ap.add_argument("--output",  default="results/t02-cc-sweep.png")
    args = ap.parse_args()

    csv_path = Path(args.results)
    if not csv_path.exists():
        print(f"File not found: {csv_path}", file=sys.stderr)
        return 1

    rows = load(csv_path)
    if not rows:
        print("No T02 rows found in summary.csv.\n"
              "Run python3 analysis/parse-results.py after the T02 experiments.",
              file=sys.stderr)
        return 1

    # Determine which CC algos and ECN modes are present in the data
    cc_present   = [c for c in CC_ORDER   if any(_effective_cc(r) == c for r in rows)]
    mode_present = [m for m in MODE_ORDER if any(r.get("mode") == m  for r in rows)]

    # ── build figure ──────────────────────────────────────────────────────────
    fig = plt.figure(figsize=(16, 11))
    fig.suptitle(
        "T02 — Congestion Control × ECN Mode Comparison\n"
        "100 Mbps · 25 ms RTT · fq_codel · 60 s runs",
        fontsize=13, fontweight="bold", y=1.01,
    )

    gs = fig.add_gridspec(2, 2, hspace=0.42, wspace=0.32)
    ax_heat  = fig.add_subplot(gs[0, 0])
    ax_tput  = fig.add_subplot(gs[0, 1])
    ax_retr  = fig.add_subplot(gs[1, 0])
    ax_rtt   = fig.add_subplot(gs[1, 1])

    # ── Panel 1: throughput heatmap ────────────────────────────────────────────
    heat = np.full((len(cc_present), len(mode_present)), np.nan)
    for ri, cc in enumerate(cc_present):
        for ci, mode in enumerate(mode_present):
            v = aggregate(rows, cc, mode, "throughput_recv_mbps")
            if v is not None:
                heat[ri, ci] = v

    im = ax_heat.imshow(heat, aspect="auto", cmap="YlGn",
                        vmin=0, vmax=np.nanmax(heat) * 1.05)
    ax_heat.set_xticks(range(len(mode_present)))
    ax_heat.set_xticklabels([MODE_LABELS.get(m, m) for m in mode_present],
                             rotation=20, ha="right", fontsize=9)
    ax_heat.set_yticks(range(len(cc_present)))
    ax_heat.set_yticklabels([c.upper() for c in cc_present], fontsize=10)
    ax_heat.set_title("Throughput Heatmap (Mbps)", fontsize=10)
    for ri in range(len(cc_present)):
        for ci in range(len(mode_present)):
            v = heat[ri, ci]
            if not np.isnan(v):
                ax_heat.text(ci, ri, f"{v:.1f}", ha="center", va="center",
                             fontsize=9, fontweight="bold",
                             color="white" if v < np.nanmax(heat) * 0.5 else "black")
    fig.colorbar(im, ax=ax_heat, fraction=0.046, pad=0.04, label="Mbps")

    # ── helper: grouped bar chart ──────────────────────────────────────────────
    def grouped_bars(ax, metric, title, ylabel, scale=1.0):
        x = np.arange(len(cc_present))
        w = 0.72 / max(len(mode_present), 1)
        offset = -(len(mode_present) - 1) / 2
        for i, mode in enumerate(mode_present):
            y = [(aggregate(rows, cc, mode, metric) or 0) * scale
                 for cc in cc_present]
            ax.bar(x + (offset + i) * w, y, w,
                   color=MODE_COLORS.get(mode, "gray"),
                   label=MODE_LABELS.get(mode, mode), alpha=0.85)
        ax.set_xticks(x)
        ax.set_xticklabels([c.upper() for c in cc_present], fontsize=10)
        ax.set_title(title, fontsize=10)
        ax.set_ylabel(ylabel, fontsize=9)
        ax.legend(fontsize=8, loc="upper right")
        ax.grid(True, alpha=0.3, axis="y")
        ax.set_ylim(bottom=0)

    grouped_bars(ax_tput, "throughput_recv_mbps",
                 "Throughput by CC and ECN Mode", "Throughput (Mbps)")
    grouped_bars(ax_retr, "retransmits",
                 "Retransmissions by CC and ECN Mode", "Retransmissions")
    grouped_bars(ax_rtt,  "rtt_mean_ms",
                 "Mean RTT by CC and ECN Mode", "RTT (ms)")

    plt.tight_layout()
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(out, dpi=150, bbox_inches="tight")
    print(f"Saved: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
