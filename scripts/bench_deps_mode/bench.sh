#!/usr/bin/env bash
# Measures golangci-lint with run.deps-mode export and source on a project.
#
# usage: bench.sh <golangci-lint binary> <project dir> <output dir> <repetitions>
#
# Scenarios:
# - cold: the build cache and the lint cache are empty.
# - warm-build: the build cache holds the export data of the dependencies (`go list -export`), the lint cache is empty.

set -euo pipefail

bin=$(realpath "$1")
project=$2
out=$(realpath "$3")
reps=$4

measure=$(realpath "$(dirname "$0")/measure.py")

linters=gosec,gocritic,revive,errorlint,nilerr,bodyclose,exhaustive,forcetypeassert,unconvert,unparam,prealloc,nilnesserr,makezero,noctx

cd "$project"

run() {
  local scenario=$1 mode=$2 rep=$3
  local label="${scenario}/${mode}/${rep}"
  local issues="$out/issues-${scenario}-${mode}-${rep}.json"

  python3 "$measure" "$label" "$bin" run \
    --no-config --default=standard -E "$linters" \
    --max-issues-per-linter=0 --max-same-issues=0 --uniq-by-line=false \
    --timeout=0 --deps-mode="$mode" \
    --output.json.path="$issues" \
    ./... >> "$out/results.jsonl" 2>> "$out/stderr.log" || true

  echo "$label: $(tail -n1 "$out/results.jsonl")"
}

clean_all() {
  go clean -cache
  "$bin" cache clean
}

for rep in $(seq 1 "$reps"); do
  for mode in export source; do
    clean_all
    run cold "$mode" "$rep"

    clean_all
    go list -e -export -deps -test ./... > /dev/null 2>&1 || true
    run warm-build "$mode" "$rep"
  done
done
