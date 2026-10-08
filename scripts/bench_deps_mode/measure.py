#!/usr/bin/env python3
"""Runs a command, and prints a JSON line with its wall time and the peak of the summed RSS of its process group.

The RSS includes the child processes (go list, the compiler, cgo), sampled every 0.5s.

usage: measure.py <label> <command> [args...]
"""

import json
import os
import subprocess
import sys
import time

PAGE_SIZE = os.sysconf("SC_PAGE_SIZE")


def group_rss(pgid):
    """Returns the summed RSS of the process group, and the RSS of its leader."""
    total = leader = 0
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        try:
            with open(f"/proc/{entry}/stat") as f:
                stat = f.read()
            # The fields after the command name: state, ppid, pgrp, ...
            fields = stat[stat.rindex(")") + 2 :].split()
            if int(fields[2]) != pgid:
                continue
            with open(f"/proc/{entry}/statm") as f:
                rss = int(f.read().split()[1]) * PAGE_SIZE
            total += rss
            if int(entry) == pgid:
                leader = rss
        except (OSError, ValueError, IndexError):
            continue
    return total, leader


def main():
    label, cmd = sys.argv[1], sys.argv[2:]

    start = time.monotonic()
    proc = subprocess.Popen(cmd, start_new_session=True, stdout=subprocess.DEVNULL, stderr=sys.stderr)

    peak = peak_leader = 0
    while proc.poll() is None:
        total, leader = group_rss(proc.pid)
        peak, peak_leader = max(peak, total), max(peak_leader, leader)
        time.sleep(0.5)

    elapsed = time.monotonic() - start

    print(json.dumps({
        "label": label,
        "seconds": round(elapsed, 1),
        "peak_rss_mb": round(peak / 2**20),
        "peak_rss_golangci_lint_mb": round(peak_leader / 2**20),
        "exit_code": proc.returncode,
    }), flush=True)


if __name__ == "__main__":
    main()
