package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"

	"golang.org/x/tools/go/packages"
	"golang.org/x/tools/go/ssa"
	"golang.org/x/tools/go/ssa/ssautil"
)

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
	HasCallResult bool
	Index         int
	Field         int
}

type IRBlock struct {
	Index        int
	Instructions []IRInstruction
}

type IRFunction struct {
	Name    string
	Params  []string
	Results []string
	Blocks  []IRBlock
}

type IRPackage struct {
	Name      string
	Functions []IRFunction
}

type IRRoot struct {
	Packages []IRPackage
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
		if p == nil { continue }
		irPkg := IRPackage{Name: p.Pkg.Name(), Functions: make([]IRFunction, 0)}
		for _, m := range p.Members {
			if fn, ok := m.(*ssa.Function); ok {
				irFn := lowerFunction(fn)
				irPkg.Functions = append(irPkg.Functions, irFn)
			}
		}
		root.Packages = append(root.Packages, irPkg)
	}

	data, _ := json.MarshalIndent(root, "", "  ")
	os.Stdout.Write(data)
}

func lowerFunction(fn *ssa.Function) IRFunction {
	irFn := IRFunction{
		Name:    fn.Name(),
		Params:  make([]string, 0),
		Results: make([]string, 0),
		Blocks:  make([]IRBlock, 0),
	}
	for _, p := range fn.Params {
		irFn.Params = append(irFn.Params, p.Name())
	}
	if fn.Signature.Results() != nil {
		res := fn.Signature.Results()
		for i := 0; i < res.Len(); i++ {
			irFn.Results = append(irFn.Results, res.At(i).Type().String())
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
	ir := IRInstruction{Kind: fmt.Sprintf("%T", inst)[5:], Args: make([]string, 0)}

    if val, ok := inst.(ssa.Value); ok {
        ir.Type = val.Type().String()
        ir.Target = val.Name()
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
	}
	return ir
}
