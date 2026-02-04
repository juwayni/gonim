# runtime/stdlib/os.nim
import os as nimos
import ../builtin

proc Exit*(code: int) = nimos.quit(code)

proc Args*(): GoSlice[string] =
  var res: GoSlice[string]
  for arg in nimos.commandLineParams():
    res.append([arg])
  return res

proc Getwd*(): (string, GoError) =
  return (nimos.getCurrentDir(), nil)
