# GONIM-CORE Bootstrap & Validation Strategy

## Phase Order
To transpile the Go standard library, we follow a strict dependency-ordered phase:

1.  **runtime**: Essential primitives (slices, maps, interfaces, memory).
2.  **internal/abi**: Platform ABI definitions.
3.  **errors**: Basic error handling.
4.  **sync**: Mutexes and atomics (requires fiber runtime).
5.  **reflect**: Type inspection (requires full TypeDesc generation).
6.  **io, os, net**: System-level libraries.

## Circular Dependency Strategy
Go packages often have circular dependencies.
**Strategy: Stub Generation & Two-Phase Compile**
- **Pass 1**: Emit Nim forward declarations for all symbols.
- **Pass 2**: Emit the full implementation logic.
- **Link-Time**: Use Nim's `{.exportc.}` and `{.importc.}` to resolve symbols across package boundaries.

## Validation Requirements

### Stdlib Parity Test Harness
A Go program that runs `go test` and compares results with `gonim` output.

### Fuzzing Strategy
Use `go-fuzz` to feed identical inputs to both Go and GONIM-compiled versions, checking for bit-level output equality.

### Memory Alias Test Suite
Verify that Go's pointer aliasing rules are preserved in Nim.
