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
    Key: string

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
    ASTNode: string

  IRPackage = object
    Name: string
    Path: string
    Functions: seq[IRFunction]
    Types: seq[IRType]
    Globals: seq[IRField]

  IRRoot = object
    Packages: seq[IRPackage]

var globalTypes = initTable[string, IRType]()
var currentPkgPrefix = ""

proc sanitize(name: string): string =
  if name.startsWith("\"") and name.endsWith("\""): return "makeGoString(" & name & ")"
  var s = name
  if s.contains(":"):
     let parts = s.split(":")
     if parts[0].allCharsInSet(Digits + {'-'}): return parts[0]
     s = parts[0]
  result = s.replace("$", "_").replace(".", "_").replace("/", "_").replace("*", "Ptr").replace(" ", "_").replace("{", "Struct").replace("}", "End").replace("[", "Slice").replace("]", "End").replace("(", "LP").replace(")", "RP").replace(",", "Comma").replace(";", "Semi").replace("\"", "").replace("-", "_").replace(":", "_").replace("|", "Pipe").replace("&", "Amp")
  if result == "init_guard": result = currentPkgPrefix & "_init_guard"

proc mapType(goType: string): string =
  if goType == "" or goType == "invalid type": return "pointer"
  if goType == "int" or goType == "int64": return "int64"
  if goType == "uint" or goType == "uint64": return "uint64"
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
  var res = sig & " ="

  # IDIOMATIC RECONSTRUCTION PASS
  if fn.Blocks.len <= 1:
    res.add "\n"
    if fn.Blocks.len == 1:
      for inst in fn.Blocks[0].Instructions:
        case inst.Kind
        of "BinOp": res.add "  let " & sanitize(inst.Target) & " = " & sanitize(inst.Lhs) & " " & inst.Op & " " & sanitize(inst.Rhs) & "\n"
        of "Call":
          let x = sanitize(inst.X)
          let call = (if inst.IsInvoke: "invokeInterface(" & x & ", \"" & inst.MethodName & "\", [" & inst.Args.map(sanitize).join(", ") & "])" else: x & "(" & inst.Args.map(sanitize).join(", ") & ")")
          if inst.HasCallResult: res.add "  let " & sanitize(inst.Target) & " = " & call & "\n"
          else: res.add "  " & call & "\n"
        of "Return":
          res.add "  runDefers()\n"
          if inst.Args.len > 0: res.add "  return " & sanitize(inst.Args[0]) & "\n"
          else: res.add "  return\n"
        of "Alloc": res.add "  var " & sanitize(inst.Target) & ": " & mapType(inst.Type) & "\n"
        of "Store": res.add "  " & sanitize(inst.Lhs) & "[] = " & sanitize(inst.Rhs) & "\n"
        else: discard
    return res

  # Fallback to structured control flow for loops/branches
  res.add "\n  var nextBlock = 0\n  while true:\n    case nextBlock:\n"
  for b in fn.Blocks:
    res.add "    of " & $b.Index & ":\n"
    for inst in b.Instructions:
      case inst.Kind
      of "BinOp": res.add "      let " & sanitize(inst.Target) & " = " & sanitize(inst.Lhs) & " " & inst.Op & " " & sanitize(inst.Rhs) & "\n"
      of "UnOp":
        if inst.Op == "*": res.add "      let " & sanitize(inst.Target) & " = " & sanitize(inst.X) & "[]\n"
        else: res.add "      let " & sanitize(inst.Target) & " = " & inst.Op & sanitize(inst.X) & "\n"
      of "If": res.add "      if " & sanitize(inst.X) & ": nextBlock = " & $inst.True & " else: nextBlock = " & $inst.False & "\n"
      of "Jump": res.add "      nextBlock = " & $inst.Block & "\n"
      of "Return":
        res.add "      runDefers()\n"
        if inst.Args.len > 0: res.add "      return " & sanitize(inst.Args[0]) & "\n"
        else: res.add "      return\n"
      of "Call":
        let x = sanitize(inst.X)
        let call = (if inst.IsInvoke: "invokeInterface(" & x & ", \"" & inst.MethodName & "\", [" & inst.Args.map(sanitize).join(", ") & "])" else: x & "(" & inst.Args.map(sanitize).join(", ") & ")")
        if inst.HasCallResult: res.add "      let " & sanitize(inst.Target) & " = " & call & "\n"
        else: res.add "      " & call & "\n"
      of "Phi": res.add "      let " & sanitize(inst.Target) & " = " & sanitize(inst.Args[0]) & "\n"
      of "Alloc": res.add "      var " & sanitize(inst.Target) & ": " & mapType(inst.Type) & "\n"
      of "Store": res.add "      " & sanitize(inst.Lhs) & "[] = " & sanitize(inst.Rhs) & "\n"
      else: discard
  res.add "    else: break\n"
  return res

proc parseIR(data: string): IRRoot =
  let j = parseJson(data)
  result.Packages = @[]
  for jp in j["Packages"]:
    var pkg: IRPackage
    pkg.Name = jp["Name"].getStr
    pkg.Path = jp["Path"].getStr
    if jp.hasKey("Types"):
      for jt in jp["Types"]:
        var it: IRType
        it.Name = jt["Name"].getStr
        it.Kind = jt["Kind"].getStr
        if jt.hasKey("Fields"):
          for jf in jt["Fields"]: it.Fields.add IRField(Name: jf["Name"].getStr, Type: jf["Type"].getStr)
        pkg.Types.add it
    if jp.hasKey("Functions"):
      for jf in jp["Functions"]:
        var fn: IRFunction
        fn.Name = jf["Name"].getStr
        if jf.hasKey("Blocks"):
          for jb in jf["Blocks"]:
            var blk: IRBlock
            blk.Index = jb["Index"].getInt
            if jb.hasKey("Instructions"):
              for ji in jb["Instructions"]:
                var inst: IRInstruction
                inst.Kind = ji["Kind"].getStr
                if ji.hasKey("Op"): inst.Op = ji["Op"].getStr
                if ji.hasKey("Target"): inst.Target = ji["Target"].getStr
                if ji.hasKey("Lhs"): inst.Lhs = ji["Lhs"].getStr
                if ji.hasKey("Rhs"): inst.Rhs = ji["Rhs"].getStr
                if ji.hasKey("X"): inst.X = ji["X"].getStr
                if ji.hasKey("Type"): inst.Type = ji["Type"].getStr
                if ji.hasKey("True"): inst.True = ji["True"].getInt
                if ji.hasKey("False"): inst.False = ji["False"].getInt
                if ji.hasKey("Block"): inst.Block = ji["Block"].getInt
                if ji.hasKey("Index"): inst.Index = ji["Index"].getInt
                if ji.hasKey("Field"): inst.Field = ji["Field"].getInt
                if ji.hasKey("HasCallResult"): inst.HasCallResult = ji["HasCallResult"].getBool
                if ji.hasKey("IsInvoke"): inst.IsInvoke = ji["IsInvoke"].getBool
                if ji.hasKey("MethodName"): inst.MethodName = ji["MethodName"].getStr
                if ji.hasKey("Args"):
                  for ja in ji["Args"]: inst.Args.add ja.getStr
                blk.Instructions.add inst
            fn.Blocks.add blk
        pkg.Functions.add fn
    if jp.hasKey("Globals"):
      for jg in jp["Globals"]: pkg.Globals.add IRField(Name: jg["Name"].getStr, Type: jg["Type"].getStr)
    result.Packages.add pkg

proc main() =
  let data = stdin.readAll()
  if data.strip() == "": return
  let root = parseIR(data)
  echo "import runtime/builtin, runtime/stdlib_mapping"
  for pkg in root.Packages:
    currentPkgPrefix = pkg.Name.replace("-", "_")
    echo generateTypes(pkg.Types)
    for fn in pkg.Functions:
      let sig = generateSignature(fn)
      if sig != "": echo sig & " # Forward"
    for fn in pkg.Functions:
      let code = generateFunction(fn)
      if code != "": echo code
main()
