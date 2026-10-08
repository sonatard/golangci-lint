#!/usr/bin/env bash
# Measures golangci-lint with run.deps-mode export and source on a project.
#
# usage: bench.sh <golangci-lint binary> <project dir> <output dir> <repetitions> [<golangci-lint binary of source-full>]
#
# Modes: export, source, and source-full (the source mode of another binary, ex: before a change).
#
# Scenarios:
# - cold: the build cache and the lint cache are empty.
# - warm-build: the build cache holds the export data of the dependencies (`go list -export`), the lint cache is empty.

set -euo pipefail

bin=$(realpath "$1")
project=$2
out=$(realpath "$3")
reps=$4
full_bin=${5:+$(realpath "$5")}

measure=$(realpath "$(dirname "$0")/measure.py")

linters=gosec,gocritic,revive,errorlint,nilerr,bodyclose,exhaustive,forcetypeassert,unconvert,unparam,prealloc,nilnesserr,makezero,noctx

cd "$project"

run() {
  local scenario=$1 mode=$2 rep=$3
  local label="${scenario}/${mode}/${rep}"
  local issues="$out/issues-${scenario}-${mode}-${rep}.json"

  local b=$bin flag=$mode
  if [ "$mode" = source-full ]; then
    b=$full_bin flag=source
  fi

  echo "=== $label" >> "$out/stderr.log"

  python3 "$measure" "$label" "$b" run -v \
    --no-config --default=standard -E "$linters" \
    --max-issues-per-linter=0 --max-same-issues=0 --uniq-by-line=false \
    --timeout=0 --deps-mode="$flag" \
    --output.json.path="$issues" \
    ./... >> "$out/results.jsonl" 2>> "$out/stderr.log" || true

  echo "$label: $(tail -n1 "$out/results.jsonl")"
}

clean_all() {
  go clean -cache
  "$bin" cache clean
}

for rep in $(seq 1 "$reps"); do
  modes="export source"
  if [ -n "$full_bin" ]; then
    modes="$modes source-full"
  fi

  for mode in $modes; do
    clean_all
    run cold "$mode" "$rep"

    clean_all
    go list -e -export -deps -test ./... > /dev/null 2>&1 || true
    run warm-build "$mode" "$rep"
  done
done
