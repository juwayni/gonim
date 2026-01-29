# runtime/goslice.nim

type
  GoSliceStorage[T] = object
    data: ptr UncheckedArray[T]
    capacity: int

proc finalizeGoSliceStorage[T](s: ref GoSliceStorage[T]) =
  if s.data != nil:
    deallocShared(s.data)

type
  GoSlice*[T] = object
    data*: ptr UncheckedArray[T]
    len*: int
    cap*: int
    owner: ref GoSliceStorage[T]

func isNil*[T](s: GoSlice[T]): bool =
  s.data == nil

func makeGoSlice*[T](p: ptr UncheckedArray[T], length, capacity: int, owner: ref GoSliceStorage[T] = nil): GoSlice[T] =
  GoSlice[T](data: p, len: length, cap: capacity, owner: owner)

template `[]`*[T](s: GoSlice[T], idx: int): untyped =
  if idx < 0 or idx >= s.len:
    raise newException(IndexDefect, "panic: runtime error: index out of range")
  s.data[idx]

proc slice*[T](s: GoSlice[T], low: int, high: int): GoSlice[T] =
  if low < 0 or high > s.cap or low > high:
     raise newException(IndexDefect, "panic: runtime error: slice bounds out of range")
  result.data = if s.data == nil: nil else: cast[ptr UncheckedArray[T]](addr s.data[low])
  result.len = high - low
  result.cap = s.cap - low
  result.owner = s.owner # Preserve ownership

proc grow[T](s: GoSlice[T], n: int): GoSlice[T] =
  var newCap = s.cap
  let target = s.len + n
  if newCap == 0: newCap = target
  else:
    while newCap < target:
      if s.len < 1024: newCap *= 2
      else: newCap += newCap div 4

  let newData = cast[ptr UncheckedArray[T]](allocShared0(sizeof(T) * newCap))
  if s.data != nil:
    copyMem(newData, s.data, sizeof(T) * s.len)

  var newOwner: ref GoSliceStorage[T]
  new(newOwner, finalizeGoSliceStorage[T])
  newOwner.data = newData
  newOwner.capacity = newCap

  result.data = newData
  result.len = s.len
  result.cap = newCap
  result.owner = newOwner

proc append*[T](s: GoSlice[T], vals: openArray[T]): GoSlice[T] =
  var res = s
  if s.len + vals.len > s.cap:
    res = grow(s, vals.len)

  for i, v in vals:
    res.data[res.len + i] = v
  res.len += vals.len
  return res
