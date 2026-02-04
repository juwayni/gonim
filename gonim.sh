#!/bin/bash
# GONIM-CORE Advanced Orchestrator

if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <package_paths...>"
    exit 1
fi

PACKAGES=$@
IR_FILE="gonim-ir.json"

echo "[1/3] Compiling Go Frontend..." >&2
go build -o compiler/gonim-frontend compiler/main.go >&2

echo "[2/3] Extracting SSA for $PACKAGES to JSON..." >&2
./compiler/gonim-frontend $PACKAGES > "$IR_FILE"

echo "[3/3] Generating Nim source..." >&2
export PATH=/home/jules/.nimble/bin:$PATH
nim c -o:compiler/gonim-backend --hints:off compiler/backend.nim >&2
./compiler/gonim-backend < "$IR_FILE"
