import ../runtime/gointerface

type
  File = object
    name: string

proc close*(f: File) =
  echo "Closing ", f.name

proc main() =
  var f = File(name: "test.txt")

  const methods = ["close"]
  const ok = File.implements(methods)
  assert ok

  let r: GoIface = bindInterface(f, File, methods)
  assert r.typeinfo.name == "File"

  echo "Interface validation passed with real vtable generation!"

main()
