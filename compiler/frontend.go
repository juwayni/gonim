package main

import (
	"fmt"
	"log"

	"golang.org/x/tools/go/packages"
	"golang.org/x/tools/go/ssa"
	"golang.org/x/tools/go/ssa/ssautil"
)

func main() {
	cfg := &packages.Config{Mode: packages.LoadAllSyntax}
	// We'll create a dummy file for the purpose of this prototype
	pkgs, err := packages.Load(cfg, "fmt") // Just load fmt to show it works
	if err != nil {
		log.Fatal(err)
	}

	prog, _ := ssautil.AllPackages(pkgs, ssa.BuilderMode(0))
	prog.Build()

	fmt.Println("--- SSA Extraction (fmt) ---")
	fmtPkg := prog.Package(pkgs[0].Types)
	if fmtPkg != nil {
		count := 0
		for name, _ := range fmtPkg.Members {
			fmt.Printf("Member: %s\n", name)
			count++
			if count > 5 { break }
		}
	}
}
