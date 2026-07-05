#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

mkdir -p logs

mariadb_socket() {
    echo "$SCRIPT_DIR/mariadb/run/mariadb.sock"
}

mariadb_installed() {
    [ -x "$SCRIPT_DIR/mariadb/bin/mariadbd" ]
}

wait_for_mariadb() {
    local socket i
    socket=$(mariadb_socket)

    for i in $(seq 1 30); do
        if [ -S "$socket" ]; then
            if ./mariadb/bin/mariadb-admin --socket="$socket" ping &>/dev/null 2>&1; then
                return 0
            fi
        fi
        sleep 1
    done

    echo "ERROR: MariaDB did not become ready within 30s (see logs/mariadb.log)" >&2
    return 1
}

start_mariadb() {
    mkdir -p config mariadb/run logs

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

    if ./mariadb/bin/mariadb-admin --socket="$(mariadb_socket)" ping &>/dev/null 2>&1; then
        echo "MariaDB already running."
        return 0
    fi

    echo "Starting MariaDB..."
    ./mariadb/bin/mariadbd-safe --defaults-file=./config/my.cnf &

    if ! wait_for_mariadb; then
        return 1
    fi

    echo "MariaDB ready."
}

start_frankenphp() {
    if [ ! -x "./frankenphp" ]; then
        echo "ERROR: frankenphp not found — run ./install.sh first" >&2
        return 1
    fi

    if pgrep -f "frankenphp php-server.*--root ./htdocs" >/dev/null 2>&1; then
        echo "FrankenPHP already running."
        return 0
    fi

    echo "Starting FrankenPHP..."
    ./frankenphp php-server --listen :8080 --root ./htdocs > ./logs/frankenphp.log 2>&1 &
    sleep 1
}

if mariadb_installed; then
    start_mariadb || exit 1
fi

start_frankenphp || exit 1

echo ""
echo "=========================================="
echo "  MINISTACK is running!"
echo "=========================================="
echo "  Web:    http://localhost:8080"
if mariadb_installed; then
    echo "  MySQL:  localhost:3307"
else
    echo "  DB:     SQLite (htdocs/data.db)"
fi
echo "  Logs:   ./logs/"
echo "=========================================="
