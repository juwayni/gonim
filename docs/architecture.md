# GONIM-CORE Hybrid Architecture

## Overview
GONIM-CORE is a high-fidelity Go-to-Nim compiler that utilizes a hybrid AST-SSA approach to produce idiomatic, high-performance Nim source code.

## Pipeline
1. **Hybrid Frontend (Go)**: Extracts semantic SSA instructions and high-level AST structural hints.
2. **Hybrid-IR (JSON)**: A structured representation of the Go program including types, functions, and control flow hints.
3. **Idiomatic Backend (Nim)**: Reconstructs Nim source using structural hints to produce human-readable, Procedural Nim code.
4. **Remade Runtime (Nim)**: A pure-Nim implementation of Go's standard library core for native performance.

## Key Features
- **Idiomatic Output**: Reconstructs high-level `if`, `for`, and `defer` blocks.
- **Remade Stdlib**: Core packages like `fmt`, `sync`, and `errors` are remade in pure Nim.
- **Multi-Package Support**: Full path-based namespacing for complex projects.
- **Zero-Cost Primitives**: Bit-compatible Slices and Strings with ARC/ORC lifecycle hooks.
