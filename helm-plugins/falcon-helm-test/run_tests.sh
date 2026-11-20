#!/usr/bin/env bash

set -euo pipefail

cd $(git rev-parse --show-toplevel)/tests/template-tests

# Run tests
if [ $# -eq 0 ]; then
    go test ./...
else
    go test ./$1
fi
