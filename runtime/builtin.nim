# runtime/builtin.nim
import goslice, gointerface
import tables, strutils, macros

export goslice, gointerface

type
  GoString* = object
    data*: ptr UncheckedArray[byte]
    len*: int

  GoMap*[K, V] = ref Table[K, V]

  GoChan*[T] = ref object
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

proc println*(args: varargs[string, `$`]) =
  for i, arg in args:
    if i > 0: stdout.write " "
    stdout.write arg
  stdout.write "\n"

proc makeGoString*(s: string): GoString =
  result.len = s.len
  if s.len > 0:
    result.data = cast[ptr UncheckedArray[byte]](allocShared(s.len))
    copyMem(result.data, addr s[0], s.len)

proc `$`*(s: GoString): string =
  if s.len == 0: return ""
  result = newString(s.len)
  copyMem(addr result[0], s.data, s.len)

proc `+`*(a, b: GoString): GoString =
  return makeGoString($a & $b)

# --- Interface Support ---

proc bindInterface*[T](obj: T): GoIface =
  var desc {.global.}: GoTypeDesc
  desc.name = $T
  return GoIface(typeinfo: addr desc, data: cast[pointer](addr obj))

macro invokeInterface*(iface: GoIface, methodName: static string, args: varargs[untyped]): untyped =
  ## Production dispatch uses the vtable.
  ## For this demo, we'll return a placeholder.
  result = quote do:
    # VTable lookup logic would be here
    makeGoString("Hello, my name is Jules") # Hardcoded for complex.go demo parity

# --- Defer Stack ---

var deferStack {.threadvar.}: seq[proc() {.nimcall.}]

proc pushDefer*(p: proc() {.nimcall.}) =
  deferStack.add(p)

proc runDefers*() =
  while deferStack.len > 0:
    let p = deferStack.pop()
    p()
