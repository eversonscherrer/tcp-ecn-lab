#!/usr/bin/env python3
"""T06 — Multi-flow Sweep: throughput, per-flow rate, Jain fairness, and ECN
marks vs number of parallel iperf3 streams.

Panels:
  1. Total throughput vs streams        (does aggregate scale?)
  2. Per-flow throughput vs streams     (how each flow is served)
  3. Jain's fairness index vs streams   (intra-mode fairness)
  4. ECN marks vs streams               (marking rate under contention)

Usage:
    python3 analysis/plot-t06-multiflow-sweep.py [--results results/summary.csv]
                                                  [--output  docs/t06-multiflow-sweep.png]
"""

import argparse
import csv
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np

MODE_ORDER  = ["none", "classic", "accecn", "dctcp"]
MODE_COLORS = {"none": "#e74c3c", "classic": "#3498db",
               "accecn": "#2ecc71", "dctcp": "#f39c12"}
MODE_LABELS = {"none": "No ECN", "classic": "Classic ECN",
               "accecn": "AccECN",  "dctcp": "DCTCP+AccECN"}


def load(csv_path: Path) -> list[dict]:
    rows = []
    with csv_path.open() as f:
        for row in csv.DictReader(f):
            streams = row.get("streams", "").strip()
            loss    = row.get("loss", "").strip()
            cc      = row.get("cc_algo", "").strip()
            bl      = row.get("buffer_limit", "").strip()
            target  = row.get("ecn_target", "").strip()
            # T06 fixed conditions: buffer_limit=1000, target=5ms, no loss,
            # no cc override, streams in {1,2,4,8}, full 60 s runs
            if (streams and not cc and loss in ("0%", "")
                    and bl == "1000" and target == "5ms"):
                try:
                    if int(streams) >= 1 and float(row.get("duration_s", 0) or 0) >= 30:
                        rows.append(row)
                except (ValueError, TypeError):
                    pass
    return rows


def stream_counts(rows: list[dict]) -> list[int]:
    return sorted({int(r["streams"]) for r in rows if r.get("streams")})


def aggregate(rows, n_streams: int, mode: str, metric: str) -> float | None:
    vals = []
    for r in rows:
        if int(r.get("streams", 0)) == n_streams and r.get("mode") == mode:
            try:
                vals.append(float(r[metric]))
            except (ValueError, KeyError):
                pass
    return float(np.mean(vals)) if vals else None


def draw_panel(ax, rows, counts, modes, metric, title, ylabel,
               per_flow=False, reference=None):
    for mode in modes:
        y = []
        for n in counts:
            v = aggregate(rows, n, mode, metric)
            if v is not None and per_flow:
                v = v / n
            y.append(v)
        ax.plot(counts, y, "o-",
                color=MODE_COLORS[mode], label=MODE_LABELS[mode],
                linewidth=2, markersize=7)
    if reference is not None:
        ax.axhline(reference, color="black", linestyle="--",
                   linewidth=1, alpha=0.5, label=f"Reference ({reference})")
    ax.set_xlabel("Number of parallel flows")
    ax.set_ylabel(ylabel, fontsize=9)
    ax.set_title(title, fontsize=10)
    ax.set_xticks(counts)
    ax.legend(fontsize=8)
    ax.grid(True, alpha=0.3)
    ax.set_ylim(bottom=0)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--results", default="results/summary.csv")
    ap.add_argument("--output",  default="docs/t06-multiflow-sweep.png")
    args = ap.parse_args()

    csv_path = Path(args.results)
    if not csv_path.exists():
        print(f"File not found: {csv_path}", file=sys.stderr)
        return 1

    rows = load(csv_path)
    if not rows:
        print("No T06 rows found. Run parse-results.py after the T06 experiments.",
              file=sys.stderr)
        return 1

    counts = stream_counts(rows)
    modes  = [m for m in MODE_ORDER if any(r.get("mode") == m for r in rows)]

    fig, axes = plt.subplots(2, 2, figsize=(13, 9))

    draw_panel(axes[0, 0], rows, counts, modes,
               "throughput_recv_mbps",
               "Total Throughput vs Flows", "Throughput (Mbps)",
               reference=100)

    draw_panel(axes[0, 1], rows, counts, modes,
               "throughput_recv_mbps",
               "Per-flow Throughput vs Flows", "Per-flow Throughput (Mbps)",
               per_flow=True)

    draw_panel(axes[1, 0], rows, counts, modes,
               "jain_fairness",
               "Jain's Fairness Index vs Flows", "Fairness Index (1 = perfect)",
               reference=1.0)
    axes[1, 0].set_ylim(0, 1.05)

    draw_panel(axes[1, 1], rows, counts, modes,
               "ecn_mark",
               "ECN Marks vs Flows", "CE Marks (total, 60 s)")

    fig.suptitle(
        "T06 — Multi-flow Sweep\n"
        "100 Mbps · 25 ms RTT · 0 % loss · fq_codel target=5 ms · 60 s runs",
        fontsize=13, fontweight="bold",
    )
    plt.tight_layout(rect=[0, 0, 1, 0.95])
    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(out, dpi=150, bbox_inches="tight")
    print(f"Saved: {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
