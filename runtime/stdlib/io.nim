# runtime/stdlib/io.nim
import ../builtin

type
  Reader* = interface
    proc Read*(p: GoSlice[byte]): (int, GoError)

  Writer* = interface
    proc Write*(p: GoSlice[byte]): (int, GoError)

  ReadWriter* = interface
    Reader
    Writer

  Closer* = interface
    proc Close*(): GoError

proc Copy*(dst: Writer, src: Reader): (int64, GoError) =
  var buf = makeGoSlice[byte](nil, 32768, 32768)
  # Actual loop would go here
  discard

var EOF* {.global.}: GoError
# EOF = errors.New("EOF")
