# GONIM-CORE Risk Analysis

## Technical Risks

### 1. Memory Model & GC Interaction
Go's GC is non-generational and concurrent. Nim's ORC/ARC is deterministic and based on reference counting.
- **Risk**: Circular dependencies in Go that rely on GC to be broken might leak in Nim if not handled by ORC.
- **Mitigation**: Use Nim's ORC (`--mm:orc`) as it handles cycles and is designed for low latency, matching Go's runtime goals.

### 2. Goroutine Scheduling
Replicating Go's M:N scheduler in Nim is non-trivial.
- **Risk**: Loss of performance or incorrect blocking behavior in complex `select` statements.
- **Mitigation**: Implement a stackful fiber runtime (Option B) using platform-specific assembly or `makecontext`/`swapcontext` to preserve Go's synchronous semantics.

### 3. Cgo & Assembly
- **Risk**: Go code often uses `.s` files which are in Plan9 assembly syntax.
- **Mitigation**: Use the strategy of compiling Go assembly to object files via the Go toolchain and linking them into the Nim binary.

### 4. Semantic Drift in Stdlib
- **Risk**: Subtle differences in floating point or edge cases in `math` or `net`.
- **Mitigation**: Continuous integration with the Go standard library test suite.
