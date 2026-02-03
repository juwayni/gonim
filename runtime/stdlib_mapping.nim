# runtime/stdlib_mapping.nim
import builtin, strutils, os

# --- fmt ---
proc fmt_init*() = discard
proc fmt_Println*(args: varargs[string, `$`]) = println(args)
proc fmt_Printf*(format: GoString, args: varargs[string, `$`]) =
  stdout.write ($format % args)
  stdout.write "\n"

# --- os ---
proc os_init*() = discard
proc os_Exit*(code: int64) = quit(code.int)

# --- time ---
proc time_init*() = discard
proc time_Sleep*(ns: int64) =
  os.sleep((ns div 1_000_000).int)
