#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Stopping FrankenPHP..."
pkill -f "frankenphp php-server" 2>/dev/null || true

if [ -x "$SCRIPT_DIR/mariadb/bin/mariadbd" ]; then
    echo "Stopping MariaDB..."
    ./mariadb/bin/mariadb-admin --socket="$SCRIPT_DIR/mariadb/run/mariadb.sock" shutdown 2>/dev/null || \
        pkill -f "mariadbd.*$SCRIPT_DIR" 2>/dev/null || true
    sleep 2
fi

echo "MINISTACK stopped."
