# runtime/builtin.nim
import goslice, gointerface
import tables

type
  GoString* = object
    data*: ptr UncheckedArray[byte]
    len*: int

  GoMap*[K, V] = ref Table[K, V]

  GoChan*[T] = ref object
    # In production, this would be a channel with Go semantics
    # (capacity, blocking, etc.)
    dummy: int

  GoError* = GoIface

# --- Builtin Functions ---

func len*(s: GoString): int = s.len
func len*[T](s: GoSlice[T]): int = s.len
func cap*[T](s: GoSlice[T]): int = s.cap

proc makeMap*[K, V](): GoMap[K, V] =
  new(result)
  result[] = initTable[K, V]()

proc panic*(msg: string) =
  raise newException(CatchableError, "panic: " & msg)

# --- Standard Interface for error ---
# type error interface { Error() string }
# In Go, the error interface is just a method set.
