#!/usr/bin/env bash
# Measures golangci-lint with warm caches after a change, and without revive.
#
# usage: bench2.sh <golangci-lint binary> <project dir> <output dir> <repetitions> <golangci-lint binary of source-full>
#
# Modes: export, source, and source-full (the source mode of the other binary).
#
# Scenarios:
# - change-leaf: the build cache and the lint cache are warm (a previous run with the same mode),
#   then an exported function is added to a package imported by no other package of the module.
# - change-low: same, but the function is added to the package imported by the most packages of the module.
# - cold-norevive: the build cache and the lint cache are empty, and revive is not enabled.

set -euo pipefail

bin=$(realpath "$1")
project=$2
out=$(realpath "$3")
reps=$4
full_bin=$(realpath "$5")

measure=$(realpath "$(dirname "$0")/measure.py")
pick=$(realpath "$(dirname "$0")/pick_files.py")

linters=gosec,gocritic,revive,errorlint,nilerr,bodyclose,exhaustive,forcetypeassert,unconvert,unparam,prealloc,nilnesserr,makezero,noctx
linters_norevive=gosec,gocritic,errorlint,nilerr,bodyclose,exhaustive,forcetypeassert,unconvert,unparam,prealloc,nilnesserr,makezero,noctx

cd "$project"

python3 "$pick" | tee "$out/files.txt"
leaf=$(sed -n 's/^leaf=//p' "$out/files.txt")
low=$(sed -n 's/^low=//p' "$out/files.txt")

lint() {
  local label=$1 mode=$2 enabled=$3 measured=$4
  local b=$bin flag=$mode
  if [ "$mode" = source-full ]; then
    b=$full_bin flag=source
  fi

  local args=(run -v --no-config --default=standard -E "$enabled"
    --max-issues-per-linter=0 --max-same-issues=0 --uniq-by-line=false
    --timeout=0 --deps-mode="$flag")

  if [ "$measured" = no ]; then
    "$b" "${args[@]}" --output.text.path=/dev/null ./... > /dev/null 2>&1 || true
    return
  fi

  local scenario rep
  IFS=/ read -r scenario _ rep <<< "$label"

  echo "=== $label" >> "$out/stderr.log"
  python3 "$measure" "$label" "$b" "${args[@]}" \
    --output.json.path="$out/issues-${scenario}-${mode}-${rep}.json" \
    ./... >> "$out/results.jsonl" 2>> "$out/stderr.log" || true

  echo "$label: $(tail -n1 "$out/results.jsonl")"
}

clean_all() {
  go clean -cache
  "$bin" cache clean
}

change() {
  printf '\nfunc BenchDepsModeAdded() {}\n' >> "$1"
}

revert() {
  git checkout -- "$1"
}

for rep in $(seq 1 "$reps"); do
  for mode in export source source-full; do
    clean_all
    lint "warmup/$mode/$rep" "$mode" "$linters" no

    change "$leaf"
    lint "change-leaf/$mode/$rep" "$mode" "$linters" yes
    revert "$leaf"

    # Back to the cached state of the warmup.
    lint "warmup/$mode/$rep" "$mode" "$linters" no

    change "$low"
    lint "change-low/$mode/$rep" "$mode" "$linters" yes
    revert "$low"
  done

  for mode in export source; do
    clean_all
    lint "cold-norevive/$mode/$rep" "$mode" "$linters_norevive" yes
  done
done
