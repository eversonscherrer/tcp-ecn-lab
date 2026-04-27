#!/usr/bin/env python3

import csv
import re
import subprocess
import sys
from pathlib import Path
from typing import Optional


FIELDS = [
    "timestamp",
    "mode",
    "pcap",
    "packets",
    "ect_or_ce_packets",
    "ce_packets",
    "ae_packets",
    "acc_ecn_option_packets",
    "acc_ecn_syn_packets",
    "classic_ecn_syn_packets",
]


def has_true(value: str) -> bool:
    return any(part in {"1", "True", "true"} for part in value.split(","))


def has_nonzero_ecn(value: str) -> bool:
    return any(part.strip() not in {"", "0"} for part in value.split(","))


def tshark_rows(path: Path) -> list[list[str]]:
    fields = [
        "frame.number",
        "ip.dsfield.ecn",
        "tcp.flags.syn",
        "tcp.flags.ae",
        "tcp.flags.cwr",
        "tcp.flags.ece",
        "tcp.options.acc_ecn.ee0b",
        "tcp.options.acc_ecn.eceb",
        "tcp.options.acc_ecn.ee1b",
    ]
    cmd = ["tshark", "-r", str(path), "-T", "fields"]
    for field in fields:
        cmd.extend(["-e", field])
    proc = subprocess.run(cmd, text=True, capture_output=True)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip())
    return [line.split("\t") for line in proc.stdout.splitlines() if line.strip()]


def validate_run(run_dir: Path) -> Optional[dict]:
    match = re.match(r"(\d{8}-\d{6})-(none|classic|accecn|dctcp)$", run_dir.name)
    if not match:
        return None

    pcap = run_dir / "flow.pcap"
    if not pcap.exists():
        pcap = run_dir / "handshake.pcap"
    if not pcap.exists():
        return None

    rows = tshark_rows(pcap)
    timestamp, mode = match.groups()
    stats = {
        "packets": 0,
        "ect_or_ce_packets": 0,
        "ce_packets": 0,
        "ae_packets": 0,
        "acc_ecn_option_packets": 0,
        "acc_ecn_syn_packets": 0,
        "classic_ecn_syn_packets": 0,
    }
    for row in rows:
        row += [""] * (9 - len(row))
        _, ecn, syn, ae, cwr, ece, ee0b, eceb, ee1b = row[:9]
        stats["packets"] += 1
        if has_nonzero_ecn(ecn):
            stats["ect_or_ce_packets"] += 1
        if any(part.strip() == "3" for part in ecn.split(",")):
            stats["ce_packets"] += 1
        if has_true(ae):
            stats["ae_packets"] += 1
        if ee0b or eceb or ee1b:
            stats["acc_ecn_option_packets"] += 1
        if has_true(syn) and has_true(ae) and has_true(cwr) and has_true(ece):
            stats["acc_ecn_syn_packets"] += 1
        if has_true(syn) and not has_true(ae) and has_true(cwr) and has_true(ece):
            stats["classic_ecn_syn_packets"] += 1

    return {
        "timestamp": timestamp,
        "mode": mode,
        "pcap": pcap.name,
        **stats,
    }


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent.parent / "results"
    rows = []
    for run_dir in sorted(root.iterdir()):
        if run_dir.is_dir():
            row = validate_run(run_dir)
            if row:
                rows.append(row)

    if not rows:
        print(f"No pcaps found in {root}", file=sys.stderr)
        return 1

    out = root / "pcap-validation.csv"
    with out.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)

    print(f"Wrote {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
