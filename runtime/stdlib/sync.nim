# runtime/stdlib/sync.nim
import locks, std/monotimes

type
  Mutex* = object
    L: Lock

proc Init*(m: var Mutex) = initLock(m.L)
proc Lock*(m: var Mutex) = acquire(m.L)
proc Unlock*(m: var Mutex) = release(m.L)

type
  WaitGroup* = object
    counter: int
    cond: Cond
    L: Lock

proc Init*(wg: var WaitGroup) =
  initLock(wg.L)
  initCond(wg.cond)

proc Add*(wg: var WaitGroup, delta: int) =
  acquire(wg.L)
  wg.counter += delta
  release(wg.L)

proc Done*(wg: var WaitGroup) =
  acquire(wg.L)
  wg.counter -= 1
  if wg.counter == 0:
    broadcast(wg.cond)
  release(wg.L)

proc Wait*(wg: var WaitGroup) =
  acquire(wg.L)
  while wg.counter > 0:
    wait(wg.cond, wg.L)
  release(wg.L)

type
  Once* = object
    done: bool
    L: Lock

proc Init*(o: var Once) = initLock(o.L)
proc Do*(o: var Once, f: proc()) =
  acquire(o.L)
  defer: release(o.L)
  if not o.done:
    f()
    o.done = true
