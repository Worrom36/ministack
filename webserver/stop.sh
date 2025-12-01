#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "Stopping FrankenPHP..."
pkill -f "frankenphp php-server" 2>/dev/null || true

if [ -d "mariadb/bin" ]; then
echo "Stopping MariaDB..."
./mariadb/bin/mysqladmin --socket=./mariadb/run/mariadb.sock shutdown 2>/dev/null || \
        pkill -f "mariadbd.*$SCRIPT_DIR" 2>/dev/null || true
fi

echo "MINISTACK stopped."
