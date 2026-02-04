package main

import (
	"encoding/json"
	"fmt"
	"go/ast"
	"go/token"
	"go/types"
	"log"
	"os"

	"golang.org/x/tools/go/packages"
	"golang.org/x/tools/go/ssa"
	"golang.org/x/tools/go/ssa/ssautil"
)

type IRType struct {
	Name    string
	Kind    string // struct, interface, pointer, slice, basic, array, chan, map
	Fields  []IRField `json:",omitempty"`
	Methods []string  `json:",omitempty"`
	Element string    `json:",omitempty"`
	Key     string    `json:",omitempty"`
	Len     int64     `json:",omitempty"`
}

type IRField struct {
	Name string
	Type string
}

type IRInstruction struct {
	Kind          string
	Op            string   `json:",omitempty"`
	Target        string   `json:",omitempty"`
	Lhs           string   `json:",omitempty"`
	Rhs           string   `json:",omitempty"`
	X             string   `json:",omitempty"`
	Args          []string `json:",omitempty"`
	Type          string   `json:",omitempty"`
	Val           string   `json:",omitempty"`
	Block         int      `json:",omitempty"`
	True          int      `json:",omitempty"`
	False         int      `json:",omitempty"`
	Index         int      `json:",omitempty"`
	Field         int      `json:",omitempty"`
	HasCallResult bool     `json:",omitempty"`
	MethodName    string   `json:",omitempty"`
	IsInvoke      bool     `json:",omitempty"`
	SourcePos     string   `json:",omitempty"`
	CommaOk       bool     `json:",omitempty"`
}

type IRBlock struct {
	Index        int
	Instructions []IRInstruction
}

type IRFunction struct {
	Name       string
	Signature  string
	Params     []string
	Results    []string
	Blocks     []IRBlock
	IsClosure  bool
	ASTNode    string            `json:",omitempty"`
	LocalNames map[string]string `json:",omitempty"`
}

type IRPackage struct {
	Name      string
	Path      string
	Functions []IRFunction
	Types     []IRType
	Globals   []IRField
	Constants []IRField
}

type IRRoot struct {
	Packages []IRPackage
}

var fset *token.FileSet
var typeMap = make(map[string]bool)
var irTypes = make([]IRType, 0)

func registerType(t types.Type) {
	if t == nil {
		return
	}
	str := t.String()
	if typeMap[str] {
		return
	}
	typeMap[str] = true

	it := IRType{Name: str, Fields: make([]IRField, 0), Methods: make([]string, 0)}
	switch v := t.Underlying().(type) {
	case *types.Struct:
		it.Kind = "struct"
		for i := 0; i < v.NumFields(); i++ {
			f := v.Field(i)
			it.Fields = append(it.Fields, IRField{Name: f.Name(), Type: f.Type().String()})
			registerType(f.Type())
		}
	case *types.Interface:
		it.Kind = "interface"
		for i := 0; i < v.NumMethods(); i++ {
			m := v.Method(i)
			it.Methods = append(it.Methods, m.Name())
		}
	case *types.Pointer:
		it.Kind = "pointer"
		it.Element = v.Elem().String()
		registerType(v.Elem())
	case *types.Slice:
		it.Kind = "slice"
		it.Element = v.Elem().String()
		registerType(v.Elem())
	case *types.Array:
		it.Kind = "array"
		it.Len = v.Len()
		it.Element = v.Elem().String()
		registerType(v.Elem())
	case *types.Chan:
		it.Kind = "chan"
		it.Element = v.Elem().String()
		registerType(v.Elem())
	case *types.Map:
		it.Kind = "map"
		it.Key = v.Key().String()
		it.Element = v.Elem().String()
		registerType(v.Key())
		registerType(v.Elem())
	default:
		it.Kind = "basic"
	}
	irTypes = append(irTypes, it)
}

func main() {
	if len(os.Args) < 2 {
		log.Fatal("Usage: gonim-frontend <package_paths...>")
	}

	fset = token.NewFileSet()
	cfg := &packages.Config{
		Mode: packages.LoadAllSyntax,
		Fset: fset,
	}
	pkgs, err := packages.Load(cfg, os.Args[1:]...)
	if err != nil {
		log.Fatal(err)
	}

	prog, _ := ssautil.AllPackages(pkgs, ssa.BuilderMode(0))
	prog.Build()

	root := IRRoot{Packages: make([]IRPackage, 0)}

	for _, p := range prog.AllPackages() {
		if p == nil {
			continue
		}
		path := p.Pkg.Path()
		if path == "unsafe" {
			continue
		}

		irPkg := IRPackage{
			Name:      p.Pkg.Name(),
			Path:      path,
			Functions: make([]IRFunction, 0),
			Types:     make([]IRType, 0),
			Globals:   make([]IRField, 0),
			Constants: make([]IRField, 0),
		}

		allFuncs := ssautil.AllFunctions(prog)
		for fn := range allFuncs {
			if fn.Package() == p {
				irFn := lowerFunction(fn)
				irPkg.Functions = append(irPkg.Functions, irFn)
			}
		}

		for _, m := range p.Members {
			switch v := m.(type) {
			case *ssa.Global:
				irPkg.Globals = append(irPkg.Globals, IRField{Name: v.Name(), Type: v.Type().String()})
				registerType(v.Type())
			case *ssa.NamedConst:
				irPkg.Constants = append(irPkg.Constants, IRField{Name: v.Name(), Type: v.Type().String()})
				registerType(v.Type())
			case *ssa.Type:
				registerType(v.Type())
			}
		}
		irPkg.Types = irTypes
		irTypes = make([]IRType, 0)
		root.Packages = append(root.Packages, irPkg)
	}

	data, err := json.MarshalIndent(root, "", "  ")
	if err != nil {
		log.Fatal(err)
	}
	os.Stdout.Write(data)
}

func lowerFunction(fn *ssa.Function) IRFunction {
	irFn := IRFunction{
		Name:      fn.String(),
		Signature: fn.Signature.String(),
		Params:    make([]string, 0),
		Results:   make([]string, 0),
		Blocks:    make([]IRBlock, 0),
		IsClosure: fn.Parent() != nil,
	}

	for _, p := range fn.Params {
		irFn.Params = append(irFn.Params, p.Name())
		registerType(p.Type())
	}
	if fn.Signature.Results() != nil {
		res := fn.Signature.Results()
		for i := 0; i < res.Len(); i++ {
			irFn.Results = append(irFn.Results, res.At(i).Type().String())
			registerType(res.At(i).Type())
		}
	}

	if fn.Syntax() != nil {
		ast.Inspect(fn.Syntax(), func(n ast.Node) bool {
			switch n.(type) {
			case *ast.ForStmt:
				irFn.ASTNode = "ForStmt"
			case *ast.RangeStmt:
				irFn.ASTNode = "RangeStmt"
			case *ast.SelectStmt:
				irFn.ASTNode = "SelectStmt"
			case *ast.SwitchStmt:
				irFn.ASTNode = "SwitchStmt"
			}
			return true
		})
	}

	for _, b := range fn.Blocks {
		irBlock := IRBlock{Index: b.Index, Instructions: make([]IRInstruction, 0)}
		for _, inst := range b.Instrs {
			irBlock.Instructions = append(irBlock.Instructions, lowerInstruction(inst))
		}
		irFn.Blocks = append(irFn.Blocks, irBlock)
	}
	return irFn
}

func lowerInstruction(inst ssa.Instruction) IRInstruction {
	kind := fmt.Sprintf("%T", inst)
	if len(kind) > 5 {
		kind = kind[5:]
	}
	ir := IRInstruction{
		Kind:      kind,
		Args:      make([]string, 0),
		SourcePos: fset.Position(inst.Pos()).String(),
	}
	if val, ok := inst.(ssa.Value); ok {
		ir.Type = val.Type().String()
		ir.Target = val.Name()
		registerType(val.Type())
	}
	switch v := inst.(type) {
	case *ssa.BinOp:
		ir.Op = v.Op.String()
		ir.Lhs = v.X.Name()
		ir.Rhs = v.Y.Name()
	case *ssa.UnOp:
		ir.Op = v.Op.String()
		ir.X = v.X.Name()
		ir.CommaOk = v.CommaOk
	case *ssa.Alloc:
		ir.Type = v.Type().String()
	case *ssa.Store:
		ir.Lhs = v.Addr.Name()
		ir.Rhs = v.Val.Name()
	case *ssa.Call:
		ir.X = v.Call.Value.String()
		for _, arg := range v.Call.Args {
			ir.Args = append(ir.Args, arg.Name())
		}
		if v.Name() != "" && v.Type().String() != "()" {
			ir.HasCallResult = true
		}
		if v.Call.IsInvoke() {
			ir.IsInvoke = true
			ir.MethodName = v.Call.Method.Name()
		}
	case *ssa.Defer:
		ir.X = v.Call.Value.String()
		for _, arg := range v.Call.Args {
			ir.Args = append(ir.Args, arg.Name())
		}
	case *ssa.Go:
		ir.X = v.Call.Value.String()
		for _, arg := range v.Call.Args {
			ir.Args = append(ir.Args, arg.Name())
		}
	case *ssa.Return:
		for _, r := range v.Results {
			ir.Args = append(ir.Args, r.Name())
		}
	case *ssa.Jump:
		ir.Block = v.Block().Succs[0].Index
	case *ssa.If:
		ir.X = v.Cond.Name()
		ir.True = v.Block().Succs[0].Index
		ir.False = v.Block().Succs[1].Index
	case *ssa.Phi:
		for _, edge := range v.Edges {
			ir.Args = append(ir.Args, edge.Name())
		}
	case *ssa.FieldAddr:
		ir.X = v.X.Name()
		ir.Field = v.Field
	case *ssa.IndexAddr:
		ir.X = v.X.Name()
		ir.Lhs = v.Index.Name()
	case *ssa.Extract:
		ir.X = v.Tuple.Name()
		ir.Index = v.Index
	case *ssa.MakeInterface:
		ir.X = v.X.Name()
	case *ssa.TypeAssert:
		ir.X = v.X.Name()
		ir.Type = v.AssertedType.String()
		ir.CommaOk = v.CommaOk
		registerType(v.AssertedType)
	case *ssa.MakeClosure:
		ir.X = v.Fn.String()
		for _, binding := range v.Bindings {
			ir.Args = append(ir.Args, binding.Name())
		}
	case *ssa.MakeMap:
		if v.Reserve != nil {
			ir.X = v.Reserve.Name()
		}
	case *ssa.MakeChan:
		if v.Size != nil {
			ir.X = v.Size.Name()
		}
	case *ssa.Send:
		ir.X = v.Chan.Name()
		ir.Args = []string{v.X.Name()}
	case *ssa.Select:
		for _, state := range v.States {
			ir.Args = append(ir.Args, state.Chan.Name())
		}
	case *ssa.Range:
		ir.X = v.X.Name()
	case *ssa.Next:
		ir.X = v.Iter.Name()
		ir.CommaOk = v.IsString
	case *ssa.Panic:
		ir.X = v.X.Name()
	case *ssa.MapUpdate:
		ir.X = v.Map.Name()
		ir.Lhs = v.Key.Name()
		ir.Rhs = v.Value.Name()
	}
	return ir
}
