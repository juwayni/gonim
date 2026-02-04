# runtime/goslice.nim

type
  GoSliceStorage = object
    refCount: int
    capacity: int

type
  GoSlice*[T] = object
    data*: ptr UncheckedArray[T]
    len*: int
    cap*: int

static:
  assert sizeof(GoSlice[int]) == 24

func isNil*[T](s: GoSlice[T]): bool =
  s.data == nil

proc nextSliceCap(newLen, oldCap: int): int =
  var newcap = oldCap
  let doublecap = newcap + newcap
  if newLen > doublecap: return newLen
  const threshold = 256
  if oldCap < threshold: return doublecap
  while true:
    newcap += (newcap + 3 * threshold) div 4
    if newcap >= newLen: break
  return newcap

proc getStorage[T](s: GoSlice[T]): ptr GoSliceStorage =
  if s.data == nil: return nil
  cast[ptr GoSliceStorage](cast[uint](s.data) - cast[uint](sizeof(GoSliceStorage)))

proc `=destroy`*[T](s: GoSlice[T]) =
  let storage = s.getStorage()
  if storage != nil:
    storage.refCount -= 1
    if storage.refCount <= 0:
      deallocShared(storage)

proc `=copy`*[T](dest: var GoSlice[T], src: GoSlice[T]) =
  if dest.data == src.data: return
  `=destroy`(dest)
  dest.data = src.data
  dest.len = src.len
  dest.cap = src.cap
  let storage = dest.getStorage()
  if storage != nil:
    storage.refCount += 1

proc grow[T](s: GoSlice[T], n: int): GoSlice[T] =
  let target = s.len + n
  let newCap = nextSliceCap(target, s.cap)
  let storageSize = sizeof(GoSliceStorage) + (sizeof(T) * newCap)
  let raw = allocShared0(storageSize)
  let newData = cast[ptr UncheckedArray[T]](cast[uint](raw) + cast[uint](sizeof(GoSliceStorage)))
  let header = cast[ptr GoSliceStorage](raw)
  header.refCount = 1
  header.capacity = newCap
  if s.data != nil:
    copyMem(newData, s.data, sizeof(T) * s.len)
  result.data = newData
  result.len = s.len
  result.cap = newCap

proc append*[T](s: var GoSlice[T], vals: openArray[T]) =
  if s.len + vals.len > s.cap:
    let newSlice = grow(s, vals.len)
    `=destroy`(s)
    s = newSlice
  for i, v in vals:
    s.data[s.len + i] = v
  s.len += vals.len

func slice*[T](s: GoSlice[T], low: int, high: int): GoSlice[T] =
  if low < 0 or high > s.cap or low > high:
     raise newException(IndexDefect, "panic: runtime error: slice bounds out of range")
  result.data = if s.data == nil: nil else: cast[ptr UncheckedArray[T]](addr s.data[low])
  result.len = high - low
  result.cap = s.cap - low
  let storage = result.getStorage()
  if storage != nil: storage.refCount += 1

template `[]`*[T](s: GoSlice[T], idx: int): untyped =
  if idx < 0 or idx >= s.len:
    raise newException(IndexDefect, "panic: runtime error: index out of range")
  s.data[idx]

template `[]=`*[T](s: GoSlice[T], idx: int, val: T) =
  if idx < 0 or idx >= s.len:
    raise newException(IndexDefect, "panic: runtime error: index out of range")
  s.data[idx] = val
