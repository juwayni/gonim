import json, strutils, os, tables, sequtils

type
  IRInstruction = object
    Kind: string
    Op: string
    Target: string
    Lhs: string
    Rhs: string
    X: string
    Args: seq[string]
    Type: string
    Val: string
    Block: int
    True: int
    False: int
    HasCallResult: bool
    Index: int
    Field: int

  IRBlock = object
    Index: int
    Instructions: seq[IRInstruction]

  IRFunction = object
    Name: string
    Params: seq[string]
    Results: seq[string]
    Blocks: seq[IRBlock]

  IRPackage = object
    Name: string
    Functions: seq[IRFunction]

  IRRoot = object
    Packages: seq[IRPackage]

proc sanitize(name: string): string =
  result = name.replace("$", "_").replace(".", "_")
  if result.contains(":"):
    result = result.split(":")[0]

proc mapType(goType: string): string =
  if goType == "" or goType == "invalid type": return "pointer"
  if goType == "int" or goType == "int64": return "int64"
  if goType == "string": return "GoString"
  if goType == "bool": return "bool"
  if goType.startsWith("*"): return "ptr " & mapType(goType[1..^1])
  if goType.startsWith("[]"): return "GoSlice[" & mapType(goType[2..^1]) & "]"
  if goType.contains("struct{"): return "object"
  if goType.contains("interface{"): return "GoIface"
  return "int64" # Default for basic types like 'int' aliases

proc generateSignature(fn: IRFunction): string =
  if fn.Name == "init" or fn.Blocks.len == 0: return ""
  result = "proc " & fn.Name & "("
  for i, p in fn.Params:
    if i > 0: result.add ", "
    result.add sanitize(p) & ": any"
  result.add "): " & (if fn.Results.len > 0: mapType(fn.Results[0]) else: "void")

proc generateFunction(fn: IRFunction): string =
  let sig = generateSignature(fn)
  if sig == "": return ""

  var res = sig & " =\n"

  var temps = initTable[string, string]()
  for b in fn.Blocks:
    for inst in b.Instructions:
      if inst.Target != "" and not temps.hasKey(inst.Target):
        if inst.Kind == "Call" and not inst.HasCallResult: continue
        temps[inst.Target] = mapType(inst.Type)

  for t, ty in temps:
    res.add "  var " & sanitize(t) & ": " & ty & "\n"

  res.add "  var nextBlock = 0\n"
  res.add "  while true:\n"
  res.add "    case nextBlock:\n"

  for b in fn.Blocks:
    res.add "    of " & $b.Index & ":\n"
    for inst in b.Instructions:
      case inst.Kind
      of "BinOp":
        res.add "      " & sanitize(inst.Target) & " = " & sanitize(inst.Lhs) & " " & inst.Op & " " & sanitize(inst.Rhs) & "\n"
      of "UnOp":
        res.add "      " & sanitize(inst.Target) & " = " & inst.Op & sanitize(inst.X) & "\n"
      of "Store":
        res.add "      " & sanitize(inst.Lhs) & "[] = " & sanitize(inst.Rhs) & "\n"
      of "Call":
        if inst.HasCallResult:
          res.add "      " & sanitize(inst.Target) & " = " & sanitize(inst.X) & "(" & inst.Args.map(sanitize).join(", ") & ")\n"
        else:
          res.add "      " & sanitize(inst.X) & "(" & inst.Args.map(sanitize).join(", ") & ")\n"
      of "Return":
        if inst.Args.len > 0:
          res.add "      return " & sanitize(inst.Args[0]) & "\n"
        else:
          res.add "      return\n"
      of "Jump":
        res.add "      nextBlock = " & $inst.Block & "\n"
      of "If":
        res.add "      if " & sanitize(inst.X) & ": nextBlock = " & $inst.True & " else: nextBlock = " & $inst.False & "\n"
      else:
        res.add "      discard # " & inst.Kind & "\n"

  res.add "    else: break\n"
  return res

proc main() =
  let data = stdin.readAll()
  if data.strip() == "": return
  let root = data.parseJson().to(IRRoot)

  echo "import runtime/builtin"
  for pkg in root.Packages:
    echo "\n# Package: " & pkg.Name
    for fn in pkg.Functions:
      let sig = generateSignature(fn)
      if sig != "": echo sig

    for fn in pkg.Functions:
      let code = generateFunction(fn)
      if code != "": echo code

main()
echo "\nmain()"
