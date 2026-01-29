# GONIM-CORE SSA Lowering Demonstration

## Example 1: Tuple Extraction

Go SSA:
```
t0 = call someFunc()
t1 = extract t0, 0
t2 = extract t0, 1
```

Nim Translation:
```nim
let t0 = someFunc()
let t1 = t0[0]
let t2 = t0[1]
```

### Decision Logic
Go SSA `extract` instructions operate on multi-value returns (tuples). Nim natively supports tuples and indexing. GONIM-CORE maps Go multi-value returns directly to Nim tuples to maintain zero-cost lowering and bit-level compatibility.

## Example 2: Control Flow (Blocks)

Go SSA:
```
b0:
  t0 = x < y
  if t0 goto b1 else b2
b1:
  return x
b2:
  return y
```

Nim Translation:
```nim
# Lowered as structured if-else
if x < y:
  return x
else:
  return y
```

### Decision Logic
Go SSA is a graph of basic blocks. GONIM-CORE uses Nim's `block` and `label` (if needed) to reconstruct the control flow graph. For simple if-else, it promotes blocks to structured Nim `if` statements when possible. Complex graphs with loops are lowered using a `while true` loop with a state-machine or Nim's `label`/`goto`.

## Example 3: Implicit Pointer Conversions

Go:
```go
var x int
var p *int = &x
```

Go SSA:
```
t0 = local int (x)
t1 = &t0
```

Nim Translation:
```nim
var t0: int64
let t1 = addr t0
```

### Decision Logic
Go's `local` allocations are lowered to Nim `var` declarations. The address-of operator `&` maps to Nim's `addr`. GONIM-CORE tracks address-taken variables to ensure they are not optimized away or incorrectly moved to registers.
