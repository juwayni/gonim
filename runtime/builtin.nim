# runtime/builtin.nim
import goslice, gointerface
import tables, strutils, macros, std/channels

export goslice, gointerface

type
  GoString* = object
    data*: ptr UncheckedArray[byte]
    len*: int

proc `=destroy`*(s: GoString) =
  if s.data != nil:
    deallocShared(s.data)

proc `=copy`*(dest: var GoString, src: GoString) =
  if dest.data == src.data: return
  `=destroy`(dest)
  dest.len = src.len
  if src.data != nil:
    dest.data = cast[ptr UncheckedArray[byte]](allocShared(src.len))
    copyMem(dest.data, src.data, src.len)

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

# --- GoMap ---
type
  GoMap*[K, V] = ref Table[K, V]

proc makeMap*[K, V](): GoMap[K, V] =
  new(result)
  result[] = initTable[K, V]()

# --- GoChan ---
type
  GoChan*[T] = ref object
    chanObj: Channel[T]

proc makeChan*[T](size: int = 0): GoChan[T] =
  new(result)
  result.chanObj.open(size)

proc send*[T](c: GoChan[T], val: T) =
  c.chanObj.send(val)

proc recv*[T](c: GoChan[T]): T =
  return c.chanObj.recv()

# --- Builtin Functions ---
func len*(s: GoString): int = s.len
func len*[T](s: GoSlice[T]): int = s.len
func cap*[T](s: GoSlice[T]): int = s.cap

proc panic*(msg: any) =
  raise newException(CatchableError, "panic: " & $msg)

proc println*(args: varargs[string, `$`]) =
  for i, arg in args:
    if i > 0: stdout.write " "
    stdout.write arg
  stdout.write "\n"

# --- Interface Support ---
proc bindInterface*[T](obj: T): GoIface =
  return createInterface(obj, T)

macro invokeInterface*(iface: GoIface, methodName: static string, args: varargs[untyped]): untyped =
  discard

# --- Defer Stack ---
var deferStack {.threadvar.}: seq[proc() {.nimcall.}]

proc pushDefer*(p: proc() {.nimcall.}) =
  deferStack.add(p)

proc runDefers*() =
  while deferStack.len > 0:
    let p = deferStack.pop()
    p()
