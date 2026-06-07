#!/usr/bin/env python3
"""T05 — Buffer Sweep: throughput and latency vs fq_codel target and buffer limit.

Panels (one figure per buffer_limit value):
  1. Throughput vs ECN target       (line chart, one line per mode)
  2. Mean RTT vs ECN target         (latency / bufferbloat indicator)
  3. ECN Marks vs ECN target        (marking frequency)
  4. Throughput StdDev vs ECN target (stability)

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
import matplotlib.ticker as mticker
import numpy as np

MODE_ORDER  = ["none", "classic", "accecn", "dctcp"]
MODE_COLORS = {"none": "#e74c3c", "classic": "#3498db",
               "accecn": "#2ecc71", "dctcp": "#f39c12"}
MODE_LABELS = {"none": "No ECN", "classic": "Classic ECN",
               "accecn": "AccECN",  "dctcp": "DCTCP+AccECN"}

TARGET_ORDER = ["1ms", "5ms", "20ms", "50ms"]


def target_to_ms(t: str) -> float:
    m = re.match(r"(\d+(?:\.\d+)?)\s*ms", t, re.IGNORECASE)
    return float(m.group(1)) if m else float("nan")


def load(csv_path: Path) -> list[dict]:
    rows = []
    with csv_path.open() as f:
        for row in csv.DictReader(f):
            # T05 rows: buffer_limit field present, no cc_algo, loss=0% or blank
            bl  = row.get("buffer_limit", "").strip()
            cc  = row.get("cc_algo", "").strip()
            loss = row.get("loss", "").strip()
            if bl and not cc and loss in ("0%", ""):
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


def draw_panel(ax, rows, targets, modes, buffer_limit, metric, title, ylabel):
    target_ms = [target_to_ms(t) for t in targets]
    for mode in modes:
        y = [aggregate(rows, t, mode, buffer_limit, metric) for t in targets]
        ax.plot(target_ms, y, "o-",
                color=MODE_COLORS[mode], label=MODE_LABELS[mode],
                linewidth=2, markersize=7)
    ax.set_xlabel("fq_codel target (ms)")
    ax.set_ylabel(ylabel, fontsize=9)
    ax.set_title(title, fontsize=10)
    ax.set_xscale("log")
    ax.xaxis.set_major_formatter(mticker.FuncFormatter(lambda v, _: f"{v:g} ms"))
    ax.set_xticks(target_ms)
    ax.legend(fontsize=8)
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
        print("No T05 rows found. Run parse-results.py after the T05 experiments.",
              file=sys.stderr)
        return 1

    targets = [t for t in TARGET_ORDER
               if any(r.get("ecn_target") == t for r in rows)]
    modes   = [m for m in MODE_ORDER
               if any(r.get("mode") == m for r in rows)]
    limits  = sorted({r.get("buffer_limit", "") for r in rows if r.get("buffer_limit")},
                     key=lambda x: int(x) if x.isdigit() else 0)

    n_limits = len(limits)
    fig, axes = plt.subplots(n_limits * 2, 2,
                             figsize=(14, 9 * n_limits),
                             squeeze=False)

    for li, blimit in enumerate(limits):
        row_off = li * 2
        label = f"buffer limit = {blimit} packets"
        fig.text(0.5, 1 - li / n_limits - 0.01,
                 label, ha="center", fontsize=11, fontweight="bold")

        draw_panel(axes[row_off, 0], rows, targets, modes, blimit,
                   "throughput_recv_mbps",
                   f"Throughput vs ECN Target  ({label})", "Throughput (Mbps)")

        draw_panel(axes[row_off, 1], rows, targets, modes, blimit,
                   "rtt_mean_ms",
                   f"Mean RTT vs ECN Target  ({label})", "RTT (ms)")

        draw_panel(axes[row_off + 1, 0], rows, targets, modes, blimit,
                   "ecn_mark",
                   f"ECN Marks vs ECN Target  ({label})", "CE Marks")

        draw_panel(axes[row_off + 1, 1], rows, targets, modes, blimit,
                   "throughput_stddev_mbps",
                   f"Throughput StdDev vs ECN Target  ({label})", "StdDev (Mbps)")

    fig.suptitle(
        "T05 — fq_codel Target & Buffer Sweep\n"
        "100 Mbps · 25 ms RTT · 0 % loss · 60 s runs",
        fontsize=13, fontweight="bold",
    )
    plt.tight_layout(rect=[0, 0, 1, 0.97])
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(out, dpi=150, bbox_inches="tight")
    print(f"Saved: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
