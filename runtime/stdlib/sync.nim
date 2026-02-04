# runtime/stdlib/sync.nim
import locks

type
  Mutex* = object
    L: Lock

proc Init*(m: var Mutex) =
  initLock(m.L)

proc Lock*(m: var Mutex) =
  acquire(m.L)

proc Unlock*(m: var Mutex) =
  release(m.L)

type
  WaitGroup* = object
    counter: int
    cond: Cond
    L: Lock

proc Add*(wg: var WaitGroup, delta: int) =
  acquire(wg.L)
  wg.counter += delta
  release(wg.L)

proc Done*(wg: var WaitGroup) =
  wg.Add(-1)
  if wg.counter == 0:
    signal(wg.cond)

proc Wait*(wg: var WaitGroup) =
  acquire(wg.L)
  while wg.counter > 0:
    wait(wg.cond, wg.L)
  release(wg.L)
