# GONIM-CORE SSA Lowering (Detailed)

## Tuple Extraction (`extract`)

Go SSA:
```
t0 = call someFunc()
t1 = extract t0, 0
```

Lowering Strategy:
Go multi-value returns are lowered to Nim tuples.
```nim
let t0 = someFunc()
let t1 = t0[0]
```

## PHI Nodes

Go SSA:
```
b1:
  t0 = ...
  jump b3
b2:
  t1 = ...
  jump b3
b3:
  t2 = phi [b1: t0, b2: t1]
```

Lowering Strategy:
Nim does not have native PHI nodes. We use "variable lifting".
```nim
var t2: T # Lifted
# ... logic in b1
t2 = t0
goto b3
# ... logic in b2
t2 = t1
goto b3
```

## Interface Dispatch

Go SSA:
```
t1 = invoke t0.Greet()
```

Lowering Strategy:
```nim
# Fat pointer dispatch
type VTable = object
  Greet: proc(data: pointer) {.nimcall.}

let vt = cast[ptr VTable](t0.typeinfo.vtable)
vt.Greet(t0.data)
```

## Memory Layout (Bit-level)

GONIM-CORE ensures that `struct` fields in Go match Nim `object` fields exactly by using `{.packed.}` where necessary and aligning with Go's alignment rules.
- `int64` -> `int64`
- `*int` -> `ptr int64`
- `string` -> `GoString` (16 bytes on 64-bit)
- `[]T` -> `GoSlice[T]` (24 bytes on 64-bit)
