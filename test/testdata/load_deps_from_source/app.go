package app

import "github.com/golangci/golangci-lint/v2/test/testdata/load_deps_from_source/dep"

// Use relies on the facts of the dependency: Printf is a printf wrapper, and Old is deprecated.
func Use() int {
	dep.Printf("%d", "x")

	return dep.Old()
}
