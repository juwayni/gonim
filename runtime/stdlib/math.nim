# runtime/stdlib/math.nim
import math as nimmath

proc Abs*(x: float64): float64 = nimmath.abs(x)
proc Sqrt*(x: float64): float64 = nimmath.sqrt(x)
proc Floor*(x: float64): float64 = nimmath.floor(x)
proc Ceil*(x: float64): float64 = nimmath.ceil(x)

const
  Pi* = nimmath.PI
