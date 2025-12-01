#!/bin/bash
# MINIDYN - Stop background updater

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [ -f "data/minidyn.pid" ]; then
    PID=$(cat data/minidyn.pid)
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID"
        echo "MINIDYN stopped."
    else
        echo "MINIDYN not running."
    fi
    rm -f data/minidyn.pid
else
    echo "MINIDYN not running."
fi

