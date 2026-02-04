import runtime/builtin
import runtime/stdlib/fmt, runtime/stdlib/errors, runtime/stdlib/sync
proc LPPtrcontainer_list_ListRP_insert*(): void =
  let t13 = t12 + 1
  return e

proc LPPtrcontainer_list_ListRP_MoveAfter*(): void =
  var nextBlock = 0
  while true:
    case nextBlock:
    of 0:
      let t2 = t1 != l
      if t2: nextBlock = 1 else: nextBlock = 4
    of 1:
      return
    of 2:
      LPPtrcontainer_list_ListRP_move(l, e, mark)
      return
    of 3:
      let t6 = t5 != l
      if t6: nextBlock = 1 else: nextBlock = 2
    of 4:
      let t7 = e == mark
      if t7: nextBlock = 1 else: nextBlock = 3
    else: break

proc LPPtrcontainer_list_ListRP_lazyInit*(): void =
  var nextBlock = 0
  while true:
    case nextBlock:
    of 0:
      let t3 = t2 == nil
      if t3: nextBlock = 1 else: nextBlock = 2
    of 1:
      let t4 = LPPtrcontainer_list_ListRP_Init(l)
      nextBlock = 2
    of 2:
      return
    else: break

proc LPPtrcontainer_list_ListRP_PushFrontList*(): void =
  var nextBlock = 0
  while true:
    case nextBlock:
    of 0:
      LPPtrcontainer_list_ListRP_lazyInit(l)
      let t1 = LPPtrcontainer_list_ListRP_Len(other)
      let t2 = LPPtrcontainer_list_ListRP_Back(other)
      nextBlock = 1
    of 1:
      let t5 = t3 > 0
      if t5: nextBlock = 2 else: nextBlock = 3
    of 2:
      let t9 = LPPtrcontainer_list_ListRP_insertValue(l, t7, t8)
      let t10 = t3 - 1
      let t11 = LPPtrcontainer_list_ElementRP_Prev(t4)
      nextBlock = 1
    of 3:
      return
    else: break

proc LPPtrcontainer_list_ListRP_InsertBefore*(): void =
  var nextBlock = 0
  while true:
    case nextBlock:
    of 0:
      let t2 = t1 != l
      if t2: nextBlock = 1 else: nextBlock = 2
    of 1:
      return nil
    of 2:
      let t5 = LPPtrcontainer_list_ListRP_insertValue(l, v, t4)
      return t5
    else: break

proc LPPtrcontainer_list_ListRP_Len*(): void =
  return t1

proc LPPtrcontainer_list_ElementRP_Prev*(): void =
  var nextBlock = 0
  while true:
    case nextBlock:
    of 0:
      let t4 = t3 != nil
      if t4: nextBlock = 3 else: nextBlock = 2
    of 1:
      return t1
    of 2:
      return nil
    of 3:
      let t8 = t1 != t7
      if t8: nextBlock = 1 else: nextBlock = 2
    else: break

proc LPPtrcontainer_list_ListRP_Remove*(): void =
  var nextBlock = 0
  while true:
    case nextBlock:
    of 0:
      let t2 = t1 == l
      if t2: nextBlock = 1 else: nextBlock = 2
    of 1:
      LPPtrcontainer_list_ListRP_remove(l, e)
      nextBlock = 2
    of 2:
      return t5
    else: break

proc container_list_New*(): void =
  let t1 = LPPtrcontainer_list_ListRP_Init(t0)
  return t1

proc LPPtrcontainer_list_ListRP_Front*(): void =
  var nextBlock = 0
  while true:
    case nextBlock:
    of 0:
      let t2 = t1 == 0
      if t2: nextBlock = 1 else: nextBlock = 2
    of 1:
      return nil
    of 2:
      return t5
    else: break

proc LPPtrcontainer_list_ListRP_move*(): void =
  var nextBlock = 0
  while true:
    case nextBlock:
    of 0:
      let t0 = e == at
      if t0: nextBlock = 1 else: nextBlock = 2
    of 1:
      return
    of 2:
      return
    else: break

proc LPPtrcontainer_list_ListRP_MoveBefore*(): void =
  var nextBlock = 0
  while true:
    case nextBlock:
    of 0:
      let t2 = t1 != l
      if t2: nextBlock = 1 else: nextBlock = 4
    of 1:
      return
    of 2:
      LPPtrcontainer_list_ListRP_move(l, e, t4)
      return
    of 3:
      let t8 = t7 != l
      if t8: nextBlock = 1 else: nextBlock = 2
    of 4:
      let t9 = e == mark
      if t9: nextBlock = 1 else: nextBlock = 3
    else: break

proc LPPtrcontainer_list_ListRP_MoveToFront*(): void =
  var nextBlock = 0
  while true:
    case nextBlock:
    of 0:
      let t2 = t1 != l
      if t2: nextBlock = 1 else: nextBlock = 3
    of 1:
      return
    of 2:
      LPPtrcontainer_list_ListRP_move(l, e, t3)
      return
    of 3:
      let t8 = t7 == e
      if t8: nextBlock = 1 else: nextBlock = 2
    else: break

proc LPPtrcontainer_list_ElementRP_Next*(): void =
  var nextBlock = 0
  while true:
    case nextBlock:
    of 0:
      let t4 = t3 != nil
      if t4: nextBlock = 3 else: nextBlock = 2
    of 1:
      return t1
    of 2:
      return nil
    of 3:
      let t8 = t1 != t7
      if t8: nextBlock = 1 else: nextBlock = 2
    else: break

proc LPPtrcontainer_list_ListRP_PushFront*(): void =
  LPPtrcontainer_list_ListRP_lazyInit(l)
  let t2 = LPPtrcontainer_list_ListRP_insertValue(l, v, t1)
  return t2

proc LPPtrcontainer_list_ListRP_Back*(): void =
  var nextBlock = 0
  while true:
    case nextBlock:
    of 0:
      let t2 = t1 == 0
      if t2: nextBlock = 1 else: nextBlock = 2
    of 1:
      return nil
    of 2:
      return t5
    else: break

proc LPPtrcontainer_list_ListRP_InsertAfter*(): void =
  var nextBlock = 0
  while true:
    case nextBlock:
    of 0:
      let t2 = t1 != l
      if t2: nextBlock = 1 else: nextBlock = 2
    of 1:
      return nil
    of 2:
      let t3 = LPPtrcontainer_list_ListRP_insertValue(l, v, mark)
      return t3
    else: break

proc LPPtrcontainer_list_ListRP_insertValue*(): void =
  let t2 = LPPtrcontainer_list_ListRP_insert(l, t0, at)
  return t2

proc LPPtrcontainer_list_ListRP_MoveToBack*(): void =
  var nextBlock = 0
  while true:
    case nextBlock:
    of 0:
      let t2 = t1 != l
      if t2: nextBlock = 1 else: nextBlock = 3
    of 1:
      return
    of 2:
      LPPtrcontainer_list_ListRP_move(l, e, t5)
      return
    of 3:
      let t10 = t9 == e
      if t10: nextBlock = 1 else: nextBlock = 2
    else: break

proc LPPtrcontainer_list_ListRP_PushBack*(): void =
  LPPtrcontainer_list_ListRP_lazyInit(l)
  let t4 = LPPtrcontainer_list_ListRP_insertValue(l, v, t3)
  return t4

proc LPPtrcontainer_list_ListRP_PushBackList*(): void =
  var nextBlock = 0
  while true:
    case nextBlock:
    of 0:
      LPPtrcontainer_list_ListRP_lazyInit(l)
      let t1 = LPPtrcontainer_list_ListRP_Len(other)
      let t2 = LPPtrcontainer_list_ListRP_Front(other)
      nextBlock = 1
    of 1:
      let t5 = t3 > 0
      if t5: nextBlock = 2 else: nextBlock = 3
    of 2:
      let t11 = LPPtrcontainer_list_ListRP_insertValue(l, t7, t10)
      let t12 = t3 - 1
      let t13 = LPPtrcontainer_list_ElementRP_Next(t4)
      nextBlock = 1
    of 3:
      return
    else: break

proc LPPtrcontainer_list_ListRP_remove*(): void =
  let t15 = t14 - 1
  return

proc container_list_init*(): void =
  var nextBlock = 0
  while true:
    case nextBlock:
    of 0:
      if t0: nextBlock = 2 else: nextBlock = 1
    of 1:
      nextBlock = 2
    of 2:
      return
    else: break

proc LPPtrcontainer_list_ListRP_Init*(): void =
  return l
