# GONIM-CORE Data Layout Specification

## Core Type Mapping

| Go Type | Nim Type | Layout / Description |
| :--- | :--- | :--- |
| `int`, `int64` | `int64` | 64-bit signed integer |
| `uint64` | `uint64` | 64-bit unsigned integer |
| `string` | `GoString` | `ptr UncheckedArray[byte]` + `len: int` |
| `[]T` | `GoSlice[T]` | `ptr UncheckedArray[T]` + `len: int` + `cap: int` |
| `map[K]V` | `GoMap[K,V]` | Pointer to hash map structure |
| `chan T` | `GoChan[T]` | Pointer to channel structure |
| `interface{}` | `GoIface` | `typeinfo: ptr GoTypeDesc` + `data: pointer` |
| `func(...)` | `proc(...)` | Closure or function pointer |

## Layout Compatibility

### GoSlice[T]
To ensure bit-level compatibility with Go's runtime, `GoSlice` must be a packed object:
```nim
type
  GoSlice*[T] = object
    data*: ptr UncheckedArray[T]
    len*: int
    cap*: int
```
*Note: On 64-bit systems, `int` in Nim is typically 64-bit, matching Go's `int`.*

### GoIface (Interfaces)
Go interfaces are "fat pointers":
```nim
type
  GoTypeDesc = object
    # Metadata for runtime type identification and method dispatch
    hash: uint32
    size: uintptr
    kind: uint8
    # ... vtable pointer or methods ...

  GoIface* = object
    typeinfo*: ptr GoTypeDesc
    data*: pointer
```

### Strings
Go strings are immutable slices of bytes without capacity:
```nim
type
  GoString* = object
    data*: ptr UncheckedArray[byte]
    len*: int
```
