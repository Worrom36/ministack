#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Stopping Ergo..."
if [ -f "./run/ergo.pid" ]; then
    kill $(cat ./run/ergo.pid) 2>/dev/null || true
    rm -f ./run/ergo.pid
fi
pkill -f "ergo.*ministack" 2>/dev/null || true

echo "IRC Server stopped."
