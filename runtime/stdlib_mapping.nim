# runtime/stdlib_mapping.nim
import builtin
import stdlib/fmt, stdlib/os, stdlib/sync, stdlib/math

# Mapping for common Go standard library calls to their Nim shims
proc fmt_Println*(args: varargs[string, `$`]) = fmt.Println(args)
proc fmt_Printf*(format: string, args: varargs[string, `$`]) = fmt.Printf(format, args)

proc os_Exit*(code: int64) = os.Exit(code.int)

proc sync_Mutex_Lock*(m: var sync.Mutex) = sync.Lock(m)
proc sync_Mutex_Unlock*(m: var sync.Mutex) = sync.Unlock(m)

proc math_Sqrt*(x: float64): float64 = math.Sqrt(x)
