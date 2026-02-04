# runtime/stdlib/fmt.nim
import ../builtin
import strutils

proc Println*(args: varargs[string, `$`]) =
  println(args)

proc Printf*(format: string, args: varargs[string, `$`]) =
  stdout.write format % args
  stdout.write "\n"

proc Sprintf*(format: string, args: varargs[string, `$`]): string =
  format % args
