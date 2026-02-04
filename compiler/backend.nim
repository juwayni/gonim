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

proc getStr(j: JsonNode, key: string, default: string = ""): string =
  if j.hasKey(key) and j[key].kind == JString: result = j[key].getStr
  else: result = default

proc getInt(j: JsonNode, key: string, default: int = 0): int =
  if j.hasKey(key) and j[key].kind == JInt: result = j[key].getInt
  else: result = default

proc getBool(j: JsonNode, key: string, default: bool = false): bool =
  if j.hasKey(key) and j[key].kind == JBool: result = j[key].getBool
  else: result = default

proc getArgs(j: JsonNode): seq[string] =
  result = @[]
  if j.hasKey("Args") and j["Args"].kind == JArray:
    for arg in j["Args"]:
      result.add arg.getStr

proc parseIR(data: string): IRRoot =
  let j = parseJson(data)
  result.Packages = @[]
  for jp in j["Packages"]:
    var pkg: IRPackage
    pkg.Name = jp.getStr("Name")
    pkg.Path = jp.getStr("Path")
    pkg.Functions = @[]
    for jf in jp["Functions"]:
      var fn: IRFunction
      fn.Name = jf.getStr("Name")
      fn.Blocks = @[]
      for jb in jf["Blocks"]:
        var blk: IRBlock
        blk.Index = jb.getInt("Index")
        blk.Instructions = @[]
        for ji in jb["Instructions"]:
          var inst: IRInstruction
          inst.Kind = ji.getStr("Kind")
          inst.Op = ji.getStr("Op")
          inst.Target = ji.getStr("Target")
          inst.Lhs = ji.getStr("Lhs")
          inst.Rhs = ji.getStr("Rhs")
          inst.X = ji.getStr("X")
          inst.Args = ji.getArgs()
          inst.HasCallResult = ji.getBool("HasCallResult")
          inst.True = ji.getInt("True")
          inst.False = ji.getInt("False")
          inst.Block = ji.getInt("Block")
          blk.Instructions.add inst
        fn.Blocks.add blk
      pkg.Functions.add fn
    result.Packages.add pkg

proc sanitize(name: string): string =
  if name.startsWith("\"") and name.endsWith("\""): return "makeGoString(" & name & ")"
  var s = name
  if s.contains(":"):
     let parts = s.split(":")
     if parts[0].allCharsInSet(Digits + {'-'}): return parts[0]
     s = parts[0]
  result = s.replace("$", "_").replace(".", "_").replace("/", "_").replace("*", "Ptr").replace(" ", "_").replace("{", "Struct").replace("}", "End").replace("[", "Slice").replace("]", "End").replace("(", "LP").replace(")", "RP").replace(",", "Comma").replace(";", "Semi").replace("\"", "").replace("-", "_")

proc mapType(goType: string): string =
  if goType == "" or goType == "invalid type": return "pointer"
  if goType == "int" or goType == "int64": return "int64"
  if goType == "string": return "GoString"
  if goType == "bool": return "bool"
  if goType.startsWith("*"): return "ptr " & mapType(goType[1..^1])
  return sanitize(goType)

proc generateFunction(fn: IRFunction): string =
  if fn.Blocks.len == 0: return ""
  var res = "proc " & sanitize(fn.Name) & "*("
  for i, p in fn.Params:
    if i > 0: res.add ", "
    res.add sanitize(p) & ": any"
  res.add "): " & (if fn.Results.len > 0: mapType(fn.Results[0]) else: "void") & " ="

  if fn.Blocks.len <= 1:
    res.add "\n"
    if fn.Blocks.len == 1:
      for inst in fn.Blocks[0].Instructions:
        case inst.Kind
        of "BinOp": res.add "  let " & sanitize(inst.Target) & " = " & sanitize(inst.Lhs) & " " & inst.Op & " " & sanitize(inst.Rhs) & "\n"
        of "Call":
          var x = sanitize(inst.X)
          if x.contains("Println"): x = "Println"
          let call = x & "(" & inst.Args.map(sanitize).join(", ") & ")"
          if inst.HasCallResult: res.add "  let " & sanitize(inst.Target) & " = " & call & "\n"
          else: res.add "  " & call & "\n"
        of "Return":
          if inst.Args.len > 0: res.add "  return " & sanitize(inst.Args[0]) & "\n"
          else: res.add "  return\n"
        else: discard
    return res

  res.add "\n  var nextBlock = 0\n  while true:\n    case nextBlock:\n"
  for b in fn.Blocks:
    res.add "    of " & $b.Index & ":\n"
    for inst in b.Instructions:
      case inst.Kind
      of "BinOp": res.add "      let " & sanitize(inst.Target) & " = " & sanitize(inst.Lhs) & " " & inst.Op & " " & sanitize(inst.Rhs) & "\n"
      of "If": res.add "      if " & sanitize(inst.X) & ": nextBlock = " & $inst.True & " else: nextBlock = " & $inst.False & "\n"
      of "Jump": res.add "      nextBlock = " & $inst.Block & "\n"
      of "Return":
        if inst.Args.len > 0: res.add "      return " & sanitize(inst.Args[0]) & "\n"
        else: res.add "      return\n"
      of "Call":
        var x = sanitize(inst.X)
        if x.contains("Println"): x = "Println"
        let call = x & "(" & inst.Args.map(sanitize).join(", ") & ")"
        if inst.HasCallResult: res.add "      let " & sanitize(inst.Target) & " = " & call & "\n"
        else: res.add "      " & call & "\n"
      else: discard
  res.add "    else: break\n"
  return res

proc main() =
  let data = stdin.readAll()
  let root = parseIR(data)
  echo "import runtime/builtin"
  echo "import runtime/stdlib/fmt, runtime/stdlib/errors, runtime/stdlib/sync"
  for pkg in root.Packages:
    for fn in pkg.Functions:
      echo generateFunction(fn)
main()
