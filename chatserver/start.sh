#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting Ergo..."
./bin/ergo run --conf ./etc/ircd.yaml &
echo $! > ./run/ergo.pid

sleep 1
echo ""
echo "=========================================="
echo "  IRC Server is running!"
echo "=========================================="
echo "  Server:    irc.ministack.local"
echo "  IRC Port:  6667"
echo "  WebSocket: 6668 (ws://host:6668)"
echo ""
echo "  IRC client: /server localhost 6667"
echo "  Web chat:   Connect via WebSocket"
echo "=========================================="
