#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Stopping ngIRCd..."
if [ -f "./run/ngircd.pid" ]; then
    kill $(cat ./run/ngircd.pid) 2>/dev/null || true
    rm -f ./run/ngircd.pid
fi
pkill -f "ngircd.*ministack" 2>/dev/null || true

echo "IRC Server stopped."
