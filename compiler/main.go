package main

import (
	"encoding/json"
	"fmt"
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
	Kind    string
	Fields  []IRField `json:",omitempty"`
	Methods []string  `json:",omitempty"`
	Element string    `json:",omitempty"`
	Key     string    `json:",omitempty"`
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
}

type IRPackage struct {
	Name      string
	Path      string
	Functions []IRFunction
	Types     []IRType
	Globals   []IRField
}

type IRRoot struct {
	Packages []IRPackage
}

var fset *token.FileSet
var typeMap = make(map[string]bool)
var irTypes = make([]IRType, 0)

var remadeLibs = map[string]bool{
	"errors":  true,
	"fmt":     true,
	"sync":    true,
	"math":    true,
	"time":    true,
	"reflect": true,
	"io":      true,
	"net":     true,
}

func registerType(t types.Type) {
	if t == nil { return }
	str := t.String()
	if typeMap[str] { return }
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
	default: it.Kind = "basic"
	}
	irTypes = append(irTypes, it)
}

func main() {
	if len(os.Args) < 2 { log.Fatal("Usage: gonim-frontend <package>") }
	fset = token.NewFileSet()
	cfg := &packages.Config{Mode: packages.LoadAllSyntax, Fset: fset}
	pkgs, err := packages.Load(cfg, os.Args[1:]...)
	if err != nil { log.Fatal(err) }
	prog, _ := ssautil.AllPackages(pkgs, ssa.BuilderMode(0))
	prog.Build()
	root := IRRoot{Packages: make([]IRPackage, 0)}
	for _, p := range prog.AllPackages() {
		if p == nil { continue }
		path := p.Pkg.Path()
		if remadeLibs[path] || path == "unsafe" { continue }
		irPkg := IRPackage{Name: p.Pkg.Name(), Path: path, Functions: make([]IRFunction, 0)}
		allFuncs := ssautil.AllFunctions(prog)
		for fn := range allFuncs {
			if fn.Package() == p { irPkg.Functions = append(irPkg.Functions, lowerFunction(fn)) }
		}
		for _, m := range p.Members {
			switch v := m.(type) {
			case *ssa.Global:
				irPkg.Globals = append(irPkg.Globals, IRField{Name: v.Name(), Type: v.Type().String()})
				registerType(v.Type())
			case *ssa.Type: registerType(v.Type())
			}
		}
		irPkg.Types = irTypes
		irTypes = make([]IRType, 0)
		root.Packages = append(root.Packages, irPkg)
	}
	data, _ := json.MarshalIndent(root, "", "  ")
	os.Stdout.Write(data)
}

func lowerFunction(fn *ssa.Function) IRFunction {
	irFn := IRFunction{Name: fn.String(), Signature: fn.Signature.String(), Params: make([]string, 0), Results: make([]string, 0), Blocks: make([]IRBlock, 0)}
	for _, p := range fn.Params {
		irFn.Params = append(irFn.Params, p.Name())
		registerType(p.Type())
	}
	for _, b := range fn.Blocks {
		irBlock := IRBlock{Index: b.Index, Instructions: make([]IRInstruction, 0)}
		for _, inst := range b.Instrs { irBlock.Instructions = append(irBlock.Instructions, lowerInstruction(inst)) }
		irFn.Blocks = append(irFn.Blocks, irBlock)
	}
	return irFn
}

func lowerInstruction(inst ssa.Instruction) IRInstruction {
	kind := fmt.Sprintf("%T", inst)
	if len(kind) > 5 { kind = kind[5:] }
	ir := IRInstruction{Kind: kind, Args: make([]string, 0)}
	if val, ok := inst.(ssa.Value); ok {
		ir.Type = val.Type().String()
		ir.Target = val.Name()
		registerType(val.Type())
	}
	switch v := inst.(type) {
	case *ssa.BinOp: ir.Op = v.Op.String(); ir.Lhs = v.X.Name(); ir.Rhs = v.Y.Name()
	case *ssa.UnOp: ir.Op = v.Op.String(); ir.X = v.X.Name()
	case *ssa.Alloc: ir.Type = v.Type().String()
	case *ssa.Store: ir.Lhs = v.Addr.Name(); ir.Rhs = v.Val.Name()
	case *ssa.Call:
		ir.X = v.Call.Value.String()
		for _, arg := range v.Call.Args { ir.Args = append(ir.Args, arg.Name()) }
		if v.Name() != "" && v.Type().String() != "()" { ir.HasCallResult = true }
		if v.Call.IsInvoke() { ir.IsInvoke = true; ir.MethodName = v.Call.Method.Name() }
	case *ssa.Return:
		for _, r := range v.Results { ir.Args = append(ir.Args, r.Name()) }
	case *ssa.Jump: ir.Block = v.Block().Succs[0].Index
	case *ssa.If: ir.X = v.Cond.Name(); ir.True = v.Block().Succs[0].Index; ir.False = v.Block().Succs[1].Index
	case *ssa.Extract: ir.X = v.Tuple.Name(); ir.Index = v.Index
	case *ssa.Phi:
		for _, edge := range v.Edges { ir.Args = append(ir.Args, edge.Name()) }
	}
	return ir
}
