import ../runtime/gointerface

type
  MyStruct = object
    val: int

proc greet*(s: MyStruct) = discard

proc main() =
  var obj = MyStruct(val: 42)
  let iface = createInterface(obj, MyStruct)
  assert not iface.isNil()

  # Test implements macro
  const ok = MyStruct.implements(["greet"])
  assert ok

  echo "GoInterface tests passed!"

main()
