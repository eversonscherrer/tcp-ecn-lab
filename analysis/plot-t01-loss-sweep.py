#!/usr/bin/env python3
"""T01 — Packet Loss Sweep: Throughput, Retransmissions and ECN Marks vs Loss Rate.

Usage:
    python3 analysis/plot-t01-loss-sweep.py [--results results/summary.csv]
                                             [--output  results/t01-loss-sweep.png]
"""

import argparse
import csv
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np

MODE_ORDER = ["none", "classic", "accecn", "dctcp"]
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
    "dctcp":   "DCTCP+AccECN",
}


def load(csv_path: Path) -> list[dict]:
    rows = []
    with csv_path.open() as f:
        for row in csv.DictReader(f):
            if row.get("loss", ""):
                rows.append(row)
    return rows


def aggregate(rows: list[dict], mode: str, loss: str, metric: str) -> float | None:
    vals = []
    for r in rows:
        if r["mode"] == mode and r["loss"] == loss and r.get(metric):
            try:
                vals.append(float(r[metric]))
            except ValueError:
                pass
    return float(np.mean(vals)) if vals else None


def sort_loss(loss_set: set[str]) -> list[str]:
    return sorted(loss_set, key=lambda x: float(x.rstrip("%")))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--results", default="results/summary.csv",
                    help="Path to summary.csv (default: results/summary.csv)")
    ap.add_argument("--output", default="docs/t01-loss-sweep.png",
                    help="Output image path (default: docs/t01-loss-sweep.png)")
    args = ap.parse_args()

    csv_path = Path(args.results)
    if not csv_path.exists():
        print(f"File not found: {csv_path}", file=sys.stderr)
        return 1

    rows = load(csv_path)
    if not rows:
        print("No rows with a 'loss' value found in summary.csv.\n"
              "Run python3 analysis/parse-results.py after the loss-sweep experiments.",
              file=sys.stderr)
        return 1

    loss_values = sort_loss({r["loss"] for r in rows})
    loss_nums = [float(l.rstrip("%")) for l in loss_values]
    modes = [m for m in MODE_ORDER if m in {r["mode"] for r in rows}]

    fig, axes = plt.subplots(2, 2, figsize=(14, 10))
    fig.suptitle("T01 — TCP/ECN Performance Under Packet Loss\n"
                 f"100 Mbps · 25 ms RTT · fq_codel · {len(loss_values)} loss levels",
                 fontsize=13, fontweight="bold", y=1.01)

    # ── Panel 1: Mean Throughput vs Loss ──────────────────────────────────
    ax = axes[0, 0]
    for mode in modes:
        y = [aggregate(rows, mode, l, "throughput_recv_mbps") for l in loss_values]
        ax.plot(loss_nums, y, "o-", color=MODE_COLORS[mode],
                label=MODE_LABELS[mode], linewidth=2, markersize=7)
    ax.set_xlabel("Packet Loss (%)")
    ax.set_ylabel("Mean Throughput (Mbps)")
    ax.set_title("Mean Throughput vs Packet Loss")
    ax.legend(fontsize=9)
    ax.grid(True, alpha=0.3)
    ax.set_xscale("symlog", linthresh=0.05)
    ax.xaxis.set_major_formatter(mticker.FuncFormatter(
        lambda v, _: f"{v:g}%"))
    ax.set_ylim(bottom=0)

    # ── Panel 2: Throughput StdDev (stability) ────────────────────────────
    ax = axes[0, 1]
    for mode in modes:
        y = [aggregate(rows, mode, l, "throughput_stddev_mbps") for l in loss_values]
        ax.plot(loss_nums, y, "s--", color=MODE_COLORS[mode],
                label=MODE_LABELS[mode], linewidth=2, markersize=6)
    ax.set_xlabel("Packet Loss (%)")
    ax.set_ylabel("Throughput StdDev (Mbps)")
    ax.set_title("Throughput Instability vs Packet Loss")
    ax.legend(fontsize=9)
    ax.grid(True, alpha=0.3)
    ax.set_xscale("symlog", linthresh=0.05)
    ax.xaxis.set_major_formatter(mticker.FuncFormatter(
        lambda v, _: f"{v:g}%"))
    ax.set_ylim(bottom=0)

    # ── Panel 3: Retransmissions vs Loss ──────────────────────────────────
    ax = axes[1, 0]
    x = np.arange(len(loss_values))
    w = 0.75 / max(len(modes), 1)
    offset = -(len(modes) - 1) / 2
    for i, mode in enumerate(modes):
        y = [aggregate(rows, mode, l, "retransmits") or 0 for l in loss_values]
        ax.bar(x + (offset + i) * w, y, w,
               color=MODE_COLORS[mode], label=MODE_LABELS[mode], alpha=0.85)
    ax.set_xlabel("Packet Loss (%)")
    ax.set_ylabel("Retransmissions")
    ax.set_title("Retransmissions vs Packet Loss")
    ax.set_xticks(x)
    ax.set_xticklabels(loss_values)
    ax.legend(fontsize=9)
    ax.grid(True, alpha=0.3, axis="y")
    ax.set_ylim(bottom=0)

    # ── Panel 4: ECN Marks vs Loss (ECN modes only) ───────────────────────
    ax = axes[1, 1]
    ecn_modes = [m for m in ["classic", "accecn", "dctcp"] if m in set(modes)]
    for mode in ecn_modes:
        y = [aggregate(rows, mode, l, "ecn_mark") or 0 for l in loss_values]
        ax.plot(loss_nums, y, "o-", color=MODE_COLORS[mode],
                label=MODE_LABELS[mode], linewidth=2, markersize=7)
    ax.set_xlabel("Packet Loss (%)")
    ax.set_ylabel("CE Marks (fq_codel)")
    ax.set_title("ECN Marks vs Packet Loss")
    ax.legend(fontsize=9)
    ax.grid(True, alpha=0.3)
    ax.set_xscale("symlog", linthresh=0.05)
    ax.xaxis.set_major_formatter(mticker.FuncFormatter(
        lambda v, _: f"{v:g}%"))
    ax.set_ylim(bottom=0)

    plt.tight_layout()
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(out, dpi=150, bbox_inches="tight")
    print(f"Saved: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
