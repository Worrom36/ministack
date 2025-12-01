#!/bin/bash
# MINIDYN - Start background updater

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if [ ! -f "config" ]; then
    echo "Error: Run ./install.sh first"
    exit 1
fi

source config

# Prompt for password if needed (not stored on disk)
if [ "$PROVIDER" = "noip" ] || [ "$PROVIDER" = "dynu" ]; then
    read -sp "Enter password for $DDNS_HOST: " DDNS_PASS
    echo ""
    export DDNS_PASS
fi

# Stop any previous instance
if [ -f "data/minidyn.pid" ]; then
    PID=$(cat data/minidyn.pid)
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null
        echo "Stopped previous instance (PID $PID)"
    fi
    rm -f data/minidyn.pid
fi

mkdir -p data

# Run initial update
./update.sh

# Start background loop
(
    while true; do
        sleep "${INTERVAL}m"
        ./update.sh
    done
) &

echo $! > data/minidyn.pid

echo ""
echo "=========================================="
echo "  MINIDYN is running!"
echo "=========================================="
echo "  Hostname: $DDNS_HOST"
echo "  Interval: Every $INTERVAL minutes"
echo "  Log:      ./data/minidyn.log"
echo "=========================================="

