#!/bin/bash
#===============================================================================
#  MINISTACK INSTALLER
#  Downloads and sets up FrankenPHP (+ optional MariaDB) portable stack
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
log_warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }
log_step()  { printf "${CYAN}[STEP]${NC} %s\n" "$1"; }

#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Versions
FRANKENPHP_VERSION="1.3.6"
MARIADB_VERSION="11.4.4"

# Options
INSTALL_MARIADB=false
CREATE_EXTRA_USER=false

# Default credentials
DB_ADMIN_USER="mini"
DB_ADMIN_PASS="stack"
DB_EXTRA_USER="horse"
DB_EXTRA_PASS="horse"

# Detect architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        FRANKENPHP_ARCH="linux-x86_64"
        MARIADB_ARCH="x86_64"
        ;;
    aarch64|arm64)
        FRANKENPHP_ARCH="linux-aarch64"
        MARIADB_ARCH="aarch64"
        ;;
    *)
        log_error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

# Download URLs
FRANKENPHP_URL="https://github.com/dunglas/frankenphp/releases/download/v${FRANKENPHP_VERSION}/frankenphp-${FRANKENPHP_ARCH}"
MARIADB_MIRROR="https://archive.mariadb.org/mariadb-${MARIADB_VERSION}/bintar-linux-systemd-${MARIADB_ARCH}/mariadb-${MARIADB_VERSION}-linux-systemd-${MARIADB_ARCH}.tar.gz"

#-------------------------------------------------------------------------------
# Ask user about MariaDB
#-------------------------------------------------------------------------------

ask_mariadb() {
    echo ""
    echo "=========================================="
    echo "  MINISTACK Installer"
    echo "=========================================="
    echo ""
    echo "  FrankenPHP (web server + PHP): ~48MB"
    echo "  MariaDB (MySQL database):      ~800MB"
    echo ""
    echo "  Without MariaDB, you can still use SQLite"
    echo "  (built into PHP, no extra download)"
    echo ""
    echo "=========================================="
    echo ""
    
    while true; do
        read -p "Install MariaDB? [y/N]: " yn
        case $yn in
            [Yy]* ) INSTALL_MARIADB=true; break;;
            [Nn]* ) INSTALL_MARIADB=false; break;;
            "" )    INSTALL_MARIADB=false; break;;
            * )     echo "Please answer y or n.";;
        esac
    done
    
    if [ "$INSTALL_MARIADB" = true ]; then
        echo ""
        while true; do
            read -p "Create additional database user? [y/N]: " yn
            case $yn in
                [Yy]* ) CREATE_EXTRA_USER=true; break;;
                [Nn]* ) CREATE_EXTRA_USER=false; break;;
                "" )    CREATE_EXTRA_USER=false; break;;
                * )     echo "Please answer y or n.";;
            esac
        done
    fi
    
    echo ""
    log_info "Architecture: $ARCH"
    log_info "Install directory: $SCRIPT_DIR"
    if [ "$INSTALL_MARIADB" = true ]; then
        log_info "Database: MariaDB"
        log_info "Admin user: $DB_ADMIN_USER"
        if [ "$CREATE_EXTRA_USER" = true ]; then
            log_info "Extra user: $DB_EXTRA_USER"
        fi
    else
        log_info "Database: SQLite (built-in)"
    fi
    echo ""
}

#-------------------------------------------------------------------------------
# Phase 1: Create directory structure
#-------------------------------------------------------------------------------

phase_directories() {
    log_step "Creating directory structure..."
    
    mkdir -p htdocs
    mkdir -p config
    mkdir -p logs
    
    if [ "$INSTALL_MARIADB" = true ]; then
        mkdir -p mariadb/run
        mkdir -p mariadb/data
    fi
    
    log_info "Directories created"
}

#-------------------------------------------------------------------------------
# Phase 2: Download FrankenPHP
#-------------------------------------------------------------------------------

phase_frankenphp() {
    log_step "Downloading FrankenPHP v${FRANKENPHP_VERSION}..."
    
    if [ -f "frankenphp" ]; then
        log_warn "frankenphp already exists, skipping download"
        return
    fi
    
    log_info "Downloading from: $FRANKENPHP_URL"
    
    if command -v curl &> /dev/null; then
        curl -L -o frankenphp "$FRANKENPHP_URL"
    elif command -v wget &> /dev/null; then
        wget -O frankenphp "$FRANKENPHP_URL"
    else
        log_error "Neither curl nor wget found. Please install one."
        exit 1
    fi
    
    chmod +x frankenphp
    log_info "FrankenPHP downloaded and made executable"
}

#-------------------------------------------------------------------------------
# Phase 3: Download MariaDB (optional)
#-------------------------------------------------------------------------------

phase_mariadb() {
    log_step "Downloading MariaDB v${MARIADB_VERSION}..."
    
    if [ -f "mariadb/bin/mariadbd" ]; then
        log_warn "MariaDB already exists, skipping download"
        return
    fi
    
    TARBALL="mariadb-${MARIADB_VERSION}.tar.gz"
    
    if [ ! -f "$TARBALL" ]; then
        log_info "Downloading from MariaDB archive..."
        
        if command -v curl &> /dev/null; then
            curl -L -o "$TARBALL" "$MARIADB_MIRROR"
        elif command -v wget &> /dev/null; then
            wget -O "$TARBALL" "$MARIADB_MIRROR"
        fi
    else
        log_info "Tarball already downloaded"
    fi
    
    log_info "Extracting MariaDB..."
    tar -xzf "$TARBALL"
    
    # Move contents to mariadb/ folder
    EXTRACTED_DIR=$(ls -d mariadb-${MARIADB_VERSION}-* 2>/dev/null | head -1)
    if [ -n "$EXTRACTED_DIR" ] && [ -d "$EXTRACTED_DIR" ]; then
        for dir in bin lib share scripts support-files include; do
            if [ -d "$EXTRACTED_DIR/$dir" ]; then
                mv "$EXTRACTED_DIR/$dir" mariadb/ 2>/dev/null || true
            fi
        done
        rm -rf "$EXTRACTED_DIR"
    fi
    
    rm -f "$TARBALL"
    
    # Remove unnecessary files to save space
    log_info "Removing unnecessary MariaDB components..."
    
    rm -f mariadb/bin/mariadb-test
    rm -f mariadb/bin/mariadb-client-test
    rm -f mariadb/bin/mariadb-test-run.pl
    rm -f mariadb/bin/mariadb-backup
    rm -f mariadb/bin/mariabackup
    rm -f mariadb/bin/garbd
    rm -f mariadb/bin/galera_recovery
    rm -f mariadb/bin/galera_new_cluster
    rm -f mariadb/bin/mariadb-ldb
    rm -f mariadb/bin/mariadb-slap
    rm -f mariadb/bin/mariadb-embedded
    rm -f mariadb/bin/mysql_client_test_embedded
    rm -f mariadb/bin/mysqltest_embedded
    rm -rf mariadb/include
    rm -rf mariadb/mysql-test
    rm -rf mariadb/mariadb-test
    
    log_info "MariaDB extracted to mariadb/"
}

#-------------------------------------------------------------------------------
# Phase 4: Initialize MariaDB (optional)
#-------------------------------------------------------------------------------

phase_init_db() {
    log_step "Initializing MariaDB database..."
    
    if [ -f "mariadb/data/mysql/global_priv.MAD" ]; then
        log_warn "Database already initialized, skipping"
        return
    fi
    
    ./mariadb/scripts/mariadb-install-db \
        --basedir="$SCRIPT_DIR/mariadb" \
        --datadir="$SCRIPT_DIR/mariadb/data" \
        --user="$(whoami)" \
        --auth-root-authentication-method=normal \
        2>&1 | tail -5
    
    log_info "MariaDB database initialized"
}

#-------------------------------------------------------------------------------
# Phase 5: Configure MariaDB users
#-------------------------------------------------------------------------------

phase_setup_users() {
    log_step "Configuring MariaDB users..."
    
    # Generate temp config
    cat > ./config/my.cnf << EOF
[mysqld]
user    = $(whoami)
basedir = $SCRIPT_DIR/mariadb
datadir = $SCRIPT_DIR/mariadb/data
socket  = $SCRIPT_DIR/mariadb/run/mariadb.sock
port    = 3307
skip-networking
bind-address = 127.0.0.1

[client]
socket  = $SCRIPT_DIR/mariadb/run/mariadb.sock
EOF

    # Start MariaDB temporarily
    log_info "Starting MariaDB temporarily..."
    ./mariadb/bin/mariadbd-safe --defaults-file=./config/my.cnf &
    MARIADB_PID=$!
    sleep 4
    
    # Create admin user and secure root
    log_info "Creating admin user '$DB_ADMIN_USER'..."
    ./mariadb/bin/mysql --socket=./mariadb/run/mariadb.sock -u root << EOF
-- Create admin user with full privileges
CREATE USER '$DB_ADMIN_USER'@'localhost' IDENTIFIED BY '$DB_ADMIN_PASS';
GRANT ALL PRIVILEGES ON *.* TO '$DB_ADMIN_USER'@'localhost' WITH GRANT OPTION;

CREATE USER '$DB_ADMIN_USER'@'127.0.0.1' IDENTIFIED BY '$DB_ADMIN_PASS';
GRANT ALL PRIVILEGES ON *.* TO '$DB_ADMIN_USER'@'127.0.0.1' WITH GRANT OPTION;

-- Disable root access
ALTER USER 'root'@'localhost' IDENTIFIED BY '$(openssl rand -base64 32)';

FLUSH PRIVILEGES;
EOF

    # Create extra user if requested
    if [ "$CREATE_EXTRA_USER" = true ]; then
        log_info "Creating extra user '$DB_EXTRA_USER'..."
        ./mariadb/bin/mysql --socket=./mariadb/run/mariadb.sock -u "$DB_ADMIN_USER" -p"$DB_ADMIN_PASS" << EOF
-- Create extra user with normal privileges
CREATE USER '$DB_EXTRA_USER'@'localhost' IDENTIFIED BY '$DB_EXTRA_PASS';
CREATE USER '$DB_EXTRA_USER'@'127.0.0.1' IDENTIFIED BY '$DB_EXTRA_PASS';

-- Grant usage (can connect but no privileges until granted per-database)
GRANT USAGE ON *.* TO '$DB_EXTRA_USER'@'localhost';
GRANT USAGE ON *.* TO '$DB_EXTRA_USER'@'127.0.0.1';

FLUSH PRIVILEGES;
EOF
    fi
    
    # Stop MariaDB
    log_info "Stopping MariaDB..."
    ./mariadb/bin/mysqladmin --socket=./mariadb/run/mariadb.sock -u "$DB_ADMIN_USER" -p"$DB_ADMIN_PASS" shutdown 2>/dev/null || kill $MARIADB_PID 2>/dev/null || true
    sleep 2
    
    log_info "MariaDB users configured"
}

#-------------------------------------------------------------------------------
# Phase 6: Create test page
#-------------------------------------------------------------------------------

phase_test_mariadb() {
    log_step "Creating test page (MariaDB)..."
    
    if [ -f "htdocs/index.php" ]; then
        log_warn "htdocs/index.php already exists, skipping"
        return
    fi
    
    cat > htdocs/index.php << 'EOF'
<?php
$dbStatus = false;
$dbError = '';
try {
    $pdo = new PDO('mysql:host=127.0.0.1;port=3307', 'mini', 'stack');
    $dbStatus = true;
    $dbVersion = $pdo->query('SELECT VERSION()')->fetchColumn();
} catch (Exception $e) {
    $dbError = $e->getMessage();
}
?>
<!DOCTYPE html>
<html>
<head>
    <title>MINISTACK</title>
    <style>
        body { font-family: system-ui; background: #1a1a2e; color: #eee; padding: 2rem; }
        .container { max-width: 500px; margin: 0 auto; }
        h1 { color: #00d9ff; }
        .status { padding: 1rem; border-radius: 8px; margin: 1rem 0; }
        .ok { background: #1e4620; border: 1px solid #4caf50; }
        .err { background: #4a1c1c; border: 1px solid #f44336; }
    </style>
</head>
<body>
    <div class="container">
        <h1>⚡ MINISTACK</h1>
        <div class="status ok">
            ✓ FrankenPHP: <?= phpversion() ?>
        </div>
        <div class="status <?= $dbStatus ? 'ok' : 'err' ?>">
            <?= $dbStatus ? "✓ MariaDB: $dbVersion" : "✗ MariaDB: $dbError" ?>
        </div>
    </div>
</body>
</html>
EOF
    
    log_info "Created htdocs/index.php"
}

phase_test_sqlite() {
    log_step "Creating test page (SQLite)..."
    
    if [ -f "htdocs/index.php" ]; then
        log_warn "htdocs/index.php already exists, skipping"
        return
    fi
    
    cat > htdocs/index.php << 'EOF'
<?php
$dbStatus = false;
$dbVersion = '';
try {
    $pdo = new PDO('sqlite:' . __DIR__ . '/data.db');
    $pdo->exec('CREATE TABLE IF NOT EXISTS test (id INTEGER PRIMARY KEY)');
    $dbStatus = true;
    $dbVersion = $pdo->query('SELECT sqlite_version()')->fetchColumn();
} catch (Exception $e) {
    $dbError = $e->getMessage();
}
?>
<!DOCTYPE html>
<html>
<head>
    <title>MINISTACK</title>
    <style>
        body { font-family: system-ui; background: #1a1a2e; color: #eee; padding: 2rem; }
        .container { max-width: 500px; margin: 0 auto; }
        h1 { color: #00d9ff; }
        .status { padding: 1rem; border-radius: 8px; margin: 1rem 0; }
        .ok { background: #1e4620; border: 1px solid #4caf50; }
        .err { background: #4a1c1c; border: 1px solid #f44336; }
        .info { background: #1e3a5f; border: 1px solid #2196f3; font-size: 0.9rem; }
    </style>
</head>
<body>
    <div class="container">
        <h1>⚡ MINISTACK</h1>
        <div class="status ok">
            ✓ FrankenPHP: <?= phpversion() ?>
        </div>
        <div class="status <?= $dbStatus ? 'ok' : 'err' ?>">
            <?= $dbStatus ? "✓ SQLite: $dbVersion" : "✗ SQLite: $dbError" ?>
        </div>
        <div class="status info">
            ℹ️ Database: htdocs/data.db
        </div>
    </div>
</body>
</html>
EOF
    
    log_info "Created htdocs/index.php"
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
    ask_mariadb
    
    phase_directories
    phase_frankenphp
    
    if [ "$INSTALL_MARIADB" = true ]; then
        phase_mariadb
        phase_init_db
        phase_setup_users
        phase_test_mariadb
    else
        phase_test_sqlite
    fi
    
    echo ""
    echo "=========================================="
    log_info "Installation complete!"
    echo "=========================================="
    echo ""
    echo "  To start:  ./start.sh"
    echo "  To stop:   ./stop.sh"
    echo "  Web URL:   http://localhost:8080"
    echo ""
    if [ "$INSTALL_MARIADB" = true ]; then
        echo "  Database:  MariaDB on port 3307"
        echo "  User:      $DB_ADMIN_USER"
        echo "  Password:  $DB_ADMIN_PASS"
        if [ "$CREATE_EXTRA_USER" = true ]; then
            echo ""
            echo "  Extra user: $DB_EXTRA_USER (password: $DB_EXTRA_PASS)"
        fi
    else
        echo "  Database:  SQLite (htdocs/data.db)"
    fi
    echo ""
}

main "$@"
