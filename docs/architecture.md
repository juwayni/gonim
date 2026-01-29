# GONIM-CORE Architecture

## Overview
GONIM-CORE is a semantic Go-to-Nim transpiler that leverages Go SSA (Static Single Assignment) to produce high-performance, semantically equivalent Nim source code.

## Pipeline

### Stage 1: Frontend (Go Toolchain Integration)
- **Input**: Go source files, build tags, environment variables.
- **Process**:
    - Uses `golang.org/x/tools/go/packages` to load and type-check packages.
    - Uses `golang.org/x/tools/go/ssa` to build the SSA IR.
    - Resolves method sets, implicit pointer conversions, and constant folding.
    - Performs escape analysis to annotate memory ownership.
    - Instantiates generics (Go 1.18+).
- **Output**: GONIM-IR (SSA + semantic annotations).

### Stage 2: Middle IR (GONIM-IR)
- **Process**:
    - Augments Go SSA with Nim-specific metadata.
    - Maps Go memory model (escape zones) to Nim's memory management (ORC/ARC).
    - Identifies goroutine boundaries and channel blocking points for CPS/Fiber transformation.
    - Extracts `defer` stack metadata for scope-aware unwinding.

### Stage 3: Backend (Nim Generation)
- **Process**:
    - Uses Nim's AST NodeKind API to generate source code.
    - Injects runtime shims for Go-specific types (`GoSlice`, `GoMap`, `GoChan`, etc.).
    - Implements structural interface satisfaction at compile-time via Nim macros.
    - Emits optimized Nim pragmas for memory layout and linking.
- **Output**: Compilable Nim Source.

## Diagram
```text
+-----------------------+      +-----------------------+      +-----------------------+
|  Stage 1: Frontend    |      |  Stage 2: Middle IR   |      |  Stage 3: Backend     |
| (Go SSA + Type Check) | ---> | (Semantic Lowering)   | ---> | (Nim AST Generation)  |
+-----------+-----------+      +-----------+-----------+      +-----------+-----------+
            |                              |                              |
            v                              v                              v
      GONIM-IR                       Annotated SSA                  Compilable Nim
```
