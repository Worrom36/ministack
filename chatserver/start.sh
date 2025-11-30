#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting ngIRCd..."
./bin/ngircd -f ./etc/ngircd.conf -n &

echo ""
echo "=========================================="
echo "  IRC Server is running!"
echo "=========================================="
echo "  Server: irc.ministack.local"
echo "  Port:   6667"
echo "  Connect: /server localhost 6667"
echo "=========================================="
