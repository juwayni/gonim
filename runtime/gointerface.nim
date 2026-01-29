# runtime/gointerface.nim
import macros

type
  GoTypeDesc* = object
    name*: string
    hash*: uint32
    vtable*: pointer

  GoIface* = object
    typeinfo*: ptr GoTypeDesc
    data*: pointer

func isNil*(iface: GoIface): bool =
  iface.typeinfo == nil

macro implements*(T: typedesc, methods: static openArray[string]): bool =
  var checks = newStmtList()
  for m in methods:
    let methodName = ident(m)
    checks.add quote do:
      static:
        when not compiles(block: (var x: `T`; x.`methodName`())):
          error("Type " & $`T` & " does not implement method " & `m`)

  result = quote do:
    block:
      `checks`
      true

template createInterface*(obj: any, T: typedesc): GoIface =
  var desc {.global.}: GoTypeDesc
  desc.name = $T
  GoIface(typeinfo: addr desc, data: cast[pointer](addr obj))
