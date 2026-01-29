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
        when not compiles(decltype(`T`.`methodName`)):
          error("Type " & $`T` & " does not implement method " & `m`)

  result = quote do:
    true

macro generateVTable*(T: typedesc, methods: static openArray[string]): untyped =
  var structFields = newNimNode(nnkRecList)
  for m in methods:
    let methodName = ident(m)
    structFields.add newIdentDefs(methodName, parseExpr("proc(p: pointer) {.nimcall.}"))

  let vtableType = newTree(nnkTypeSection,
    newTree(nnkTypeDef,
      ident("VTable"),
      newEmptyNode(),
      newTree(nnkObjectTy, newEmptyNode(), newEmptyNode(), structFields)
    )
  )

  result = newStmtList(vtableType)
  result.add quote do:
    var vt {.global.}: VTable
    addr vt

template bindInterface*(obj: any, T: typedesc, methods: static openArray[string]): GoIface =
  var desc {.global.}: GoTypeDesc
  desc.name = $T
  desc.vtable = generateVTable(T, methods)
  GoIface(typeinfo: addr desc, data: cast[pointer](addr obj))
