#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Check if MariaDB is installed
if [ -d "mariadb/bin" ]; then
    # Generate MariaDB config with current absolute paths
    cat > ./config/my.cnf << EOF
[mysqld]
user    = $(whoami)
basedir = $SCRIPT_DIR/mariadb
datadir = $SCRIPT_DIR/mariadb/data
socket  = $SCRIPT_DIR/mariadb/run/mariadb.sock
port    = 3307

innodb_buffer_pool_size = 32M
max_connections = 25
log_error = $SCRIPT_DIR/logs/mariadb.log
bind-address = 127.0.0.1
skip-name-resolve

[client]
socket  = $SCRIPT_DIR/mariadb/run/mariadb.sock
port    = 3307
EOF

echo "Starting MariaDB..."
    ./mariadb/bin/mariadbd-safe --defaults-file=./config/my.cnf &

echo "Waiting for MariaDB..."
sleep 3
fi

echo "Starting FrankenPHP..."
./frankenphp php-server --listen :8080 --root ./htdocs > ./logs/frankenphp.log 2>&1 &

sleep 1

echo ""
echo "=========================================="
echo "  MINISTACK is running!"
echo "=========================================="
echo "  Web:    http://localhost:8080"
if [ -d "mariadb/bin" ]; then
echo "  MySQL:  localhost:3307"
else
    echo "  DB:     SQLite (htdocs/data.db)"
fi
echo "  Logs:   ./logs/"
echo "=========================================="
