# GONIM-CORE Fiber Runtime (Option B)

To preserve Go's goroutine semantics (blocking channels, select fairness, and synchronous-looking code), GONIM-CORE utilizes a **stackful fiber runtime**.

## Implementation Overview

### 1. Fiber Context
Each goroutine is mapped to a Fiber. A Fiber has its own stack and context (registers, PC).

```nim
type
  GoFiber = object
    stack: pointer
    stackSize: int
    context: pointer # pointer to ucontext_t or assembly-saved registers
    status: FiberStatus # Runnable, Waiting, Dead
```

### 2. Scheduler
The scheduler runs a pool of OS threads (M:N modeling).
- **Yield Points**: The backend (Stage 3) injects yield points during function calls or loop headers to ensure cooperative multitasking (Go 1.13-style).
- **Preemption**: For Go 1.14+ style preemption, the runtime uses signals (SIGURG) to force a yield.

### 3. Channel Blocking
When a Go code performs `<-ch`, the runtime:
1. Puts the current `GoFiber` into `Waiting` status.
2. Appends the Fiber to the channel's wait queue.
3. Calls `scheduler_yield()` to switch to another Fiber.

### 4. Select Fairness
The `select` statement is lowered to a runtime call `runtime.select(cases)`.
- It randomly shuffles the order of cases to ensure fairness.
- If no case is ready and there's no `default`, it parks the Fiber.

## Why Option B?
- **Option A (CPS)**: Requires massive transformation of all functions to "continuation-passing style", which can be slow and makes FFI difficult.
- **Option B (Fibers)**: Keeps the code looking like the original Go SSA while providing the same blocking semantics. Nim's `coro` module or `makecontext`/`swapcontext` (POSIX) are used as the foundation.
