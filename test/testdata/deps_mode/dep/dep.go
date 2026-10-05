package dep

import "fmt"

// Printf wraps fmt.Printf.
func Printf(format string, args ...any) {
	fmt.Printf(format, args...)
}

// Old returns 1.
//
// Deprecated: use New instead.
func Old() int { return 1 }

// New returns 1.
func New() int { return 1 }
