#!/usr/bin/env python3
"""Prints two Go files of the module in the current directory, to change between two runs:

- leaf: a file of a package imported by no other package of the module.
- low: a file of the package imported by the most packages of the module.

usage: pick_files.py  (prints "leaf=<file>" and "low=<file>")
"""

import json
import os
import subprocess

out = subprocess.run(["go", "list", "-e", "-json", "./..."], check=True, capture_output=True, text=True).stdout

pkgs = []
decoder = json.JSONDecoder()
idx = 0
while idx < len(out):
    while idx < len(out) and out[idx].isspace():
        idx += 1
    if idx >= len(out):
        break
    pkg, idx = decoder.raw_decode(out, idx)
    if pkg.get("GoFiles"):
        pkgs.append(pkg)

paths = {p["ImportPath"] for p in pkgs}
importers = {p["ImportPath"]: 0 for p in pkgs}
for p in pkgs:
    for imp in p.get("Imports", []):
        if imp in paths:
            importers[imp] += 1

by_path = {p["ImportPath"]: p for p in pkgs}


def first_file(pkg):
    return os.path.join(pkg["Dir"], sorted(pkg["GoFiles"])[0])


low = max(sorted(importers), key=lambda path: importers[path])
leaves = sorted(path for path, n in importers.items() if n == 0)
leaf = leaves[0] if leaves else low

print(f"leaf={first_file(by_path[leaf])}")
print(f"low={first_file(by_path[low])}")
print(f"# leaf package {leaf}, low package {low} ({importers[low]} importers)")
