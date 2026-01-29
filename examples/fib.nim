import runtime/builtin

# Package: main
proc fib(n: any): int64
proc main(): void
proc fib(n: any): int64 =
  var t5: int64
  var t0: bool
  var t4: int64
  var t2: int64
  var t1: int64
  var t3: int64
  var nextBlock = 0
  while true:
    case nextBlock:
    of 0:
      t0 = n <= 1
      if t0: nextBlock = 1 else: nextBlock = 2
    of 1:
      return n
    of 2:
      t1 = n - 1
      t2 = fib(t1)
      t3 = n - 2
      t4 = fib(t3)
      t5 = t2 + t4
      return t5
    else: break

proc main(): void =
  var t0: int64
  var nextBlock = 0
  while true:
    case nextBlock:
    of 0:
      t0 = fib(10)
      println(t0)
      return
    else: break


main()
