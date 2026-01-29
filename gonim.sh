#!/bin/bash
# GONIM-CORE Orchestrator

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <go_file>"
    exit 1
fi

GO_FILE=$1
IR_FILE="gonim-ir.json"

echo "[1/3] Compiling Go Frontend..." >&2
go build -o compiler/gonim-frontend compiler/main.go >&2

echo "[2/3] Extracting SSA to JSON..." >&2
./compiler/gonim-frontend "$GO_FILE" > "$IR_FILE"

echo "[3/3] Generating Nim code..." >&2
export PATH=/home/jules/.nimble/bin:$PATH
nim c -o:compiler/gonim-backend --hints:off compiler/backend.nim >&2
./compiler/gonim-backend < "$IR_FILE"
