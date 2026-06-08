#!/usr/bin/env python3
"""Generate minimalist testbed topology figure for the paper."""

from pathlib import Path
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch

fig, ax = plt.subplots(figsize=(7.2, 3.2))
ax.set_xlim(0, 10)
ax.set_ylim(0, 5)
ax.axis("off")

# ── palette ──────────────────────────────────────────────────────────────────
C_HOST   = "#f5f5f5"
C_VM     = "#ffffff"
C_BORDER = "#333333"
C_ARROW  = "#1a1a1a"
C_QDISC  = "#2c6fad"
C_DATA   = "#1a7a3c"

def box(ax, x, y, w, h, fc, ec, lw=1.2, radius=0.18):
    rect = FancyBboxPatch((x, y), w, h,
                          boxstyle=f"round,pad=0,rounding_size={radius}",
                          fc=fc, ec=ec, lw=lw, zorder=2)
    ax.add_patch(rect)

# ── Proxmox host outer box ────────────────────────────────────────────────────
box(ax, 0.3, 0.5, 9.4, 4.0, C_HOST, C_BORDER, lw=1.5)
ax.text(5.0, 4.25, "Proxmox Host (Hypervisor)",
        ha="center", va="center", fontsize=9,
        color=C_BORDER, fontweight="bold")

# ── VM boxes ─────────────────────────────────────────────────────────────────
# accecn1 — sender / server
box(ax, 0.9, 1.0, 3.2, 2.8, C_VM, C_BORDER, lw=1.0)
ax.text(2.5, 3.55, "accecn1", ha="center", va="center",
        fontsize=9.5, fontweight="bold", color=C_BORDER)
ax.text(2.5, 3.15, "Ubuntu Server 26.04", ha="center", va="center",
        fontsize=7.2, color="#555555")
ax.plot([1.05, 3.95], [2.95, 2.95], lw=0.6, color="#cccccc")
ax.text(2.5, 2.65, "iperf3  server", ha="center", va="center",
        fontsize=8.0, color=C_BORDER)
ax.text(2.5, 2.28, "(sender role / -R)", ha="center", va="center",
        fontsize=7.5, style="italic", color="#555555")
ax.text(2.5, 1.75, "10.20.241.6", ha="center", va="center",
        fontsize=7.5, color="#444444",
        bbox=dict(fc="#eef2f7", ec="#aaaaaa", lw=0.6, pad=2,
                  boxstyle="round,pad=0.2"))

# accecn2 — receiver / client
box(ax, 5.9, 1.0, 3.2, 2.8, C_VM, C_BORDER, lw=1.0)
ax.text(7.5, 3.55, "accecn2", ha="center", va="center",
        fontsize=9.5, fontweight="bold", color=C_BORDER)
ax.text(7.5, 3.15, "Ubuntu Server 26.04", ha="center", va="center",
        fontsize=7.2, color="#555555")
ax.plot([6.05, 8.95], [2.95, 2.95], lw=0.6, color="#cccccc")
ax.text(7.5, 2.65, "iperf3  client", ha="center", va="center",
        fontsize=8.0, color=C_BORDER)
ax.text(7.5, 2.28, "(receiver role / -R)", ha="center", va="center",
        fontsize=7.5, style="italic", color="#555555")
ax.text(7.5, 1.75, "10.20.241.4", ha="center", va="center",
        fontsize=7.5, color="#444444",
        bbox=dict(fc="#eef2f7", ec="#aaaaaa", lw=0.6, pad=2,
                  boxstyle="round,pad=0.2"))

# ── Data flow arrow: accecn1 → accecn2 (solid, green) ─────────────────────
ax.annotate("",
    xy=(5.85, 2.5), xytext=(4.15, 2.5),
    arrowprops=dict(arrowstyle="-|>", color=C_DATA,
                    lw=1.8, mutation_scale=16))
ax.text(5.0, 2.78, "TCP data  iperf3 -R", ha="center", va="bottom",
        fontsize=7.8, color=C_DATA, fontweight="bold")

# ── tc qdisc annotation (below data arrow) ───────────────────────────────────
ax.annotate("",
    xy=(4.15, 1.7), xytext=(5.85, 1.7),
    arrowprops=dict(arrowstyle="-|>", color=C_QDISC,
                    lw=1.2, linestyle="dashed",
                    connectionstyle="arc3,rad=0"))
ax.text(5.0, 1.42, "egress qdisc (accecn1):", ha="center", va="top",
        fontsize=7.2, color=C_QDISC)
ax.text(5.0, 1.10, "HTB → netem → fq_codel ecn", ha="center", va="top",
        fontsize=7.5, color=C_QDISC, fontweight="bold",
        bbox=dict(fc="#eaf3fb", ec=C_QDISC, lw=0.7, pad=3,
                  boxstyle="round,pad=0.25"))

# ── SSH label (run.sh initiates from accecn2) ─────────────────────────────
ax.text(5.0, 0.72, "run.sh  executed on accecn2  ·  SSH → accecn1",
        ha="center", va="center", fontsize=7.0,
        color="#888888", style="italic")

plt.tight_layout(pad=0.2)
out = Path("docs/topology.png")
out.parent.mkdir(parents=True, exist_ok=True)
plt.savefig(out, dpi=200, bbox_inches="tight", facecolor="white")
print(f"Saved: {out}")
