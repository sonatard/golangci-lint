#!/usr/bin/env bash
# Shows how golangci-lint reports a type error in a dependency outside the module, in each deps mode.
#
# usage: dep_errors.sh <golangci-lint binary>
#
# Cases:
# - decl: the type error is in a declaration of the dependency.
# - body: the type error is only in a function body of the dependency.

set -uo pipefail

bin=$(realpath "$1")

for case in decl body; do
  work=$(mktemp -d)
  mkdir -p "$work/app" "$work/dep"

  printf 'module example.com/dep\n\ngo 1.26\n' > "$work/dep/go.mod"

  if [ "$case" = decl ]; then
    printf 'package dep\n\nvar Decl int = "s"\n\nfunc Body() int {\n\treturn 1\n}\n' > "$work/dep/dep.go"
  else
    printf 'package dep\n\nvar Decl int = 1\n\nfunc Body() int {\n\tvar x int = "s"\n\treturn x\n}\n' > "$work/dep/dep.go"
  fi

  printf 'module example.com/app\n\ngo 1.26\n\nrequire example.com/dep v0.0.0\n\nreplace example.com/dep => ../dep\n' > "$work/app/go.mod"
  printf 'package main\n\nimport (\n\t"fmt"\n\n\t"example.com/dep"\n)\n\nfunc main() {\n\tfmt.Printf("%%d\\n", "x", dep.Body(), dep.Decl)\n}\n' > "$work/app/main.go"

  for mode in export source; do
    echo "### case=$case mode=$mode"
    echo '```'
    (cd "$work/app" && "$bin" run --no-config --default=none -Egovet --deps-mode="$mode" ./... 2>&1)
    echo "exit code: $?"
    echo '```'
  done
done
