package main

import (
	"encoding/json"
	"fmt"
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
	Fields  []IRField
	Methods []string
	Element string
}

type IRField struct {
	Name string
	Type string
}

type IRInstruction struct {
	Kind          string
	Op            string
	Target        string
	Lhs           string
	Rhs           string
	X             string
	Args          []string
	Type          string
	Val           string
	Block         int
	True          int
	False         int
	Index         int
	Field         int
	HasCallResult bool
	MethodName    string
	IsInvoke      bool
}

type IRBlock struct {
	Index        int
	Instructions []IRInstruction
}

type IRFunction struct {
	Name      string
	Signature string
	Params    []string
	Results   []string
	Blocks    []IRBlock
}

type IRPackage struct {
	Name      string
	Functions []IRFunction
	Types     []IRType
	Globals   []IRField
}

type IRRoot struct {
	Packages []IRPackage
}

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

	it := IRType{
		Name:    str,
		Fields:  make([]IRField, 0),
		Methods: make([]string, 0),
	}
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
		it.Element = v.Elem().String()
		registerType(v.Elem())
	default:
		it.Kind = "basic"
	}
	irTypes = append(irTypes, it)
}

func main() {
	if len(os.Args) < 2 {
		log.Fatal("Usage: gonim-frontend <package>")
	}

	cfg := &packages.Config{Mode: packages.LoadAllSyntax}
	pkgs, err := packages.Load(cfg, os.Args[1])
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
		irPkg := IRPackage{
			Name:      p.Pkg.Name(),
			Functions: make([]IRFunction, 0),
			Types:     make([]IRType, 0),
			Globals:   make([]IRField, 0),
		}

		for _, m := range p.Members {
			switch v := m.(type) {
			case *ssa.Function:
				irPkg.Functions = append(irPkg.Functions, lowerFunction(v))
			case *ssa.Global:
				irPkg.Globals = append(irPkg.Globals, IRField{Name: v.Name(), Type: v.Type().String()})
				registerType(v.Type())
			case *ssa.Type:
				registerType(v.Type())
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
	irFn := IRFunction{
		Name:      fn.Name(),
		Signature: fn.Signature.String(),
		Params:    make([]string, 0),
		Results:   make([]string, 0),
		Blocks:    make([]IRBlock, 0),
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
	ir := IRInstruction{Kind: kind, Args: make([]string, 0)}

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
	case *ssa.Alloc:
		ir.Type = v.Type().String()
	case *ssa.Store:
		ir.Lhs = v.Addr.Name()
		ir.Rhs = v.Val.Name()
	case *ssa.Call:
		ir.X = v.Call.Value.Name()
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
	case *ssa.Field:
		ir.X = v.X.Name()
		ir.Field = v.Field
	case *ssa.IndexAddr:
		ir.X = v.X.Name()
		ir.Lhs = v.Index.Name()
	case *ssa.Index:
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
		registerType(v.AssertedType)
	}
	return ir
}
