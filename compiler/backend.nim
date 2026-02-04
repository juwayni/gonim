import json, strutils, os, tables, sequtils

type
  IRField = object
    Name: string
    Type: string

  IRType = object
    Name: string
    Kind: string
    Fields: seq[IRField]
    Methods: seq[string]
    Element: string

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
    MethodName: string
    IsInvoke: bool
    Index: int
    Field: int

  IRBlock = object
    Index: int
    Instructions: seq[IRInstruction]

  IRFunction = object
    Name: string
    Signature: string
    Params: seq[string]
    Results: seq[string]
    Blocks: seq[IRBlock]

  IRPackage = object
    Name: string
    Path: string
    Functions: seq[IRFunction]
    Types: seq[IRType]
    Globals: seq[IRField]
    ASMFiles: seq[string]

  IRRoot = object
    Packages: seq[IRPackage]

proc sanitize(name: string): string =
  if name.startsWith("\"") and name.endsWith("\""): return "makeGoString(" & name & ")"
  var s = name
  if s.contains(":"):
     let parts = s.split(":")
     if parts[0].allCharsInSet(Digits + {'-'}): return parts[0]
     s = parts[0]
  result = s.replace("$", "_").replace(".", "_").replace("/", "_").replace("*", "Ptr").replace(" ", "_").replace("{", "Struct").replace("}", "End").replace("[", "Slice").replace("]", "End").replace("(", "LP").replace(")", "RP").replace(",", "Comma").replace(";", "Semi").replace("\"", "").replace("-", "_").replace(":", "_").replace("|", "Pipe").replace("&", "Amp")

proc mapType(goType: string): string =
  if goType == "" or goType == "invalid type": return "pointer"
  if goType == "int" or goType == "int64": return "int64"
  if goType == "string": return "GoString"
  if goType == "bool": return "bool"
  if goType.startsWith("*"): return "ptr " & mapType(goType[1..^1])
  if goType.startsWith("[]"):
     let inner = goType[2..^1]
     return "GoSlice[" & mapType(inner) & "]"
  if goType == "any" or goType == "interface{}": return "GoIface"
  return sanitize(goType)

proc generateTypes(types: seq[IRType]): string =
  if types.len == 0: return ""
  result = "type\n"
  var seen = initTable[string, bool]()
  for t in types:
    let sName = sanitize(t.Name)
    if seen.hasKey(sName) or sName == "pointer" or sName == "int64" or sName == "GoIface": continue
    seen[sName] = true
    if t.Kind == "struct":
      result.add "  " & sName & "* = object\n"
      if t.Fields.len == 0: result.add "    dummy*: int\n"
      for i, f in t.Fields: result.add "    f" & $i & "*: " & mapType(f.Type) & " # " & f.Name & "\n"
    elif t.Kind == "interface":
      result.add "  " & sName & "* = GoIface\n"
  if result == "type\n": return ""
  result.add "\n"

proc generateSignature(fn: IRFunction): string =
  if fn.Blocks.len == 0: return ""
  result = "proc " & sanitize(fn.Name) & "*("
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
        if (inst.Kind == "Call" or inst.Kind == "Invoke") and not inst.HasCallResult: continue
        temps[inst.Target] = mapType(inst.Type)
  for t, ty in temps: res.add "  var " & sanitize(t) & ": " & ty & "\n"
  res.add "  var nextBlock = 0\n  while true:\n    case nextBlock:\n"
  for b in fn.Blocks:
    res.add "    of " & $b.Index & ":\n"
    for inst in b.Instructions:
      case inst.Kind
      of "BinOp": res.add "      " & sanitize(inst.Target) & " = " & sanitize(inst.Lhs) & " " & inst.Op & " " & sanitize(inst.Rhs) & "\n"
      of "UnOp":
        if inst.Op == "*": res.add "      " & sanitize(inst.Target) & " = " & sanitize(inst.X) & "[]\n"
        else: res.add "      " & sanitize(inst.Target) & " = " & inst.Op & sanitize(inst.X) & "\n"
      of "Alloc":
        if inst.Type.startsWith("*"): res.add "      " & sanitize(inst.Target) & " = cast[" & mapType(inst.Type) & "](allocShared0(sizeof(" & mapType(inst.Type[1..^1]) & ")))\n"
        else: res.add "      discard # Stack alloc\n"
      of "Store": res.add "      " & sanitize(inst.Lhs) & "[] = " & sanitize(inst.Rhs) & "\n"
      of "FieldAddr": res.add "      " & sanitize(inst.Target) & " = addr " & sanitize(inst.X) & ".f" & $inst.Field & "\n"
      of "IndexAddr": res.add "      " & sanitize(inst.Target) & " = addr " & sanitize(inst.X) & "[" & sanitize(inst.Lhs) & "]\n"
      of "Extract": res.add "      " & sanitize(inst.Target) & " = " & sanitize(inst.X) & "[" & $inst.Index & "]\n"
      of "MakeInterface": res.add "      " & sanitize(inst.Target) & " = bindInterface(" & sanitize(inst.X) & ")\n"
      of "Call":
        let call = (if inst.IsInvoke: "invokeInterface(" & sanitize(inst.X) & ", \"" & inst.MethodName & "\", [" & inst.Args.map(sanitize).join(", ") & "])" else: sanitize(inst.X) & "(" & inst.Args.map(sanitize).join(", ") & ")")
        if inst.HasCallResult: res.add "      " & sanitize(inst.Target) & " = " & call & "\n"
        else: res.add "      discard " & call & "\n"
      of "Return":
        res.add "      runDefers()\n"
        if inst.Args.len > 0: res.add "      return " & sanitize(inst.Args[0]) & "\n"
        else: res.add "      return\n"
      of "Jump": res.add "      nextBlock = " & $inst.Block & "\n"
      of "If": res.add "      if " & sanitize(inst.X) & ": nextBlock = " & $inst.True & " else: nextBlock = " & $inst.False & "\n"
      of "Phi": res.add "      " & sanitize(inst.Target) & " = " & sanitize(inst.Args[0]) & "\n"
      of "Defer": res.add "      pushDefer(proc() = discard " & sanitize(inst.X) & "(" & inst.Args.map(sanitize).join(", ") & "))\n"
      of "Go": res.add "      spawn " & sanitize(inst.X) & "(" & inst.Args.map(sanitize).join(", ") & ")\n"
      of "RunDefers": res.add "      runDefers()\n"
      of "MakeClosure": res.add "      " & sanitize(inst.Target) & " = makeClosure(" & sanitize(inst.X) & ", [" & inst.Args.map(sanitize).join(", ") & "])\n"
      else: res.add "      discard # " & inst.Kind & "\n"
  res.add "    else: break\n"
  return res

proc main() =
  let data = stdin.readAll()
  if data.strip() == "": return
  let root = data.parseJson().to(IRRoot)
  echo "import runtime/builtin, runtime/stdlib_mapping, threadpool"

  for pkg in root.Packages:
    for asm in pkg.ASMFiles:
       echo "{.link: \"" & asm & ".o\".}"

  for pkg in root.Packages:
    echo generateTypes(pkg.Types)

  for pkg in root.Packages:
    for fn in pkg.Functions:
      let sig = generateSignature(fn)
      if sig != "": echo sig & " # Forward"

  for pkg in root.Packages:
    if pkg.Globals.len > 0:
      echo "var"
      for g in pkg.Globals:
        echo "  " & sanitize(g.Name) & "*: " & mapType(g.Type)

  for pkg in root.Packages:
    for fn in pkg.Functions:
      let code = generateFunction(fn)
      if code != "": echo code

main()
echo "\ncommand_line_arguments_main()"
