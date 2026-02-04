# runtime/stdlib/errors.nim
import ../builtin

type
  GoErrorObj = object of RootObj
    msg: string

  error* = ref GoErrorObj

proc New*(text: string): error =
  new(result)
  result.msg = text

proc Error*(e: error): string =
  e.msg
