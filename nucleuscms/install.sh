#!/bin/bash
#===============================================================================
#  MINISTACK NUCLEUSCMS INSTALLER
#  Downloads NucleusCMS v3.8dev and deploys into webserver/htdocs/
#===============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { printf "${GREEN}[INFO]${NC} %s\n" "$1"; }
log_warn()  { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; }
log_step()  { printf "${CYAN}[STEP]${NC} %s\n" "$1"; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

INCLUDED_DIR="$SCRIPT_DIR/included"

WEBSERVER_DIR="$(cd "$SCRIPT_DIR/../webserver" && pwd)"
FRANKENPHP="$WEBSERVER_DIR/frankenphp"
NUCLEUS_URL="https://github.com/NucleusCMS/NucleusCMS/archive/refs/heads/v3.8dev.zip"
NUCLEUS_VERSION="3.8.0-dev"

DB_USER="mini"
DB_PASS="stack"
DB_HOST="127.0.0.1"
DB_PORT="3307"

SUBFOLDER="nucleus"
DB_NAME="nucleus"
STARTED_MARIADB=false

# NucleusCMS site defaults (match MINISTACK credentials)
ADMIN_USER="mini"
ADMIN_PASS="stack"
ADMIN_EMAIL="admin@localhost"
BLOG_NAME="MINISTACK Blog"
BLOG_SHORTNAME="ministack"

# Skin bundle (skins-bundle.zip) — deploy all, import all, grey as default
DEFAULT_SKIN="grey"
SKIN_BUNDLE=true
SKIP_FEED_SKIN_IMPORT="atom,rss2.0,rsd"

WIZARD_ONLY=false
SKIP_WIZARD=false
REPATCH_ONLY=false
NONINTERACTIVE=true
FRESH_INSTALL=false

#-------------------------------------------------------------------------------
# CLI arguments
#-------------------------------------------------------------------------------

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --wizard-only)
                WIZARD_ONLY=true
                shift
                ;;
            --skip-wizard)
                SKIP_WIZARD=true
                shift
                ;;
            --repatch-only)
                REPATCH_ONLY=true
                shift
                ;;
            --fresh)
                FRESH_INSTALL=true
                shift
                ;;
            -y|--yes)
                NONINTERACTIVE=true
                shift
                ;;
            -i|--interactive)
                NONINTERACTIVE=false
                shift
                ;;
            --subfolder)
                SUBFOLDER="$2"
                shift 2
                ;;
            --db-name)
                DB_NAME="$2"
                shift 2
                ;;
            --admin-user)
                ADMIN_USER="$2"
                shift 2
                ;;
            --admin-pass)
                ADMIN_PASS="$2"
                shift 2
                ;;
            --blog-name)
                BLOG_NAME="$2"
                shift 2
                ;;
            --blog-shortname)
                BLOG_SHORTNAME="$2"
                shift 2
                ;;
            --default-skin)
                DEFAULT_SKIN="$2"
                shift 2
                ;;
            --no-skin-bundle)
                SKIN_BUNDLE=false
                shift
                ;;
            -h|--help)
                echo "Usage: ./install.sh [options]"
                echo ""
                echo "  -i, --interactive   Prompt for subfolder and database name"
                echo "  -y, --yes           Non-interactive (default)"
                echo "  --skip-wizard       Deploy only, skip browser/POST wizard"
                echo "  --repatch-only      Re-apply MINISTACK PHP patches to existing deploy"
                echo "  --fresh             Drop and recreate database before wizard"
                echo "  --wizard-only       Run wizard only (reads nucleuscms/config)"
                echo "  --subfolder NAME    htdocs subfolder (default: nucleus)"
                echo "  --db-name NAME      MariaDB database (default: nucleus)"
                echo "  --admin-user USER   Nucleus admin login (default: mini)"
                echo "  --admin-pass PASS   Nucleus admin password (default: stack)"
                echo "  --blog-name NAME    Blog title"
                echo "  --blog-shortname N  Blog short name (URL slug)"
                echo "  --default-skin NAME Blog skin after install (default: grey)"
                echo "  --no-skin-bundle    Skip skins-bundle.zip extract and import"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1 (try --help)"
                exit 1
                ;;
        esac
    done
}

load_saved_config() {
    if [ -f "$SCRIPT_DIR/config" ]; then
        # shellcheck source=/dev/null
        source "$SCRIPT_DIR/config"
        log_info "Loaded settings from nucleuscms/config"
    fi
}

#-------------------------------------------------------------------------------
# Prerequisites
#-------------------------------------------------------------------------------

check_prerequisites() {
    log_step "Checking prerequisites..."

    if [ ! -f "$FRANKENPHP" ]; then
        log_error "FrankenPHP not found. Run webserver/install.sh first."
        exit 1
    fi

    if [ ! -f "$WEBSERVER_DIR/mariadb/bin/mariadbd" ]; then
        log_error "MariaDB not found. NucleusCMS requires MySQL/MariaDB."
        echo ""
        echo "  Re-run webserver/install.sh and choose Y to install MariaDB."
        exit 1
    fi

    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        log_error "Neither curl nor wget found. Please install one."
        exit 1
    fi

    log_info "Prerequisites OK"
}

#-------------------------------------------------------------------------------
# Interactive configuration
#-------------------------------------------------------------------------------

ask_config() {
    echo ""
    echo "=========================================="
    echo "  MINISTACK NucleusCMS Installer"
    echo "=========================================="
    echo ""
    echo "  NucleusCMS v${NUCLEUS_VERSION} (v3.8dev branch)"
    echo "  Requires: FrankenPHP + MariaDB (already detected)"
    echo ""
    echo "=========================================="
    echo ""

    if [ "$NONINTERACTIVE" = true ]; then
        log_info "Non-interactive — subfolder: $SUBFOLDER, database: $DB_NAME"
        log_info "Admin: $ADMIN_USER, blog: $BLOG_NAME"
        echo ""
        return
    fi

    read -p "Subfolder under htdocs [$SUBFOLDER]: " input
    SUBFOLDER="${input:-$SUBFOLDER}"

    if [[ ! "$SUBFOLDER" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid subfolder name. Use letters, numbers, hyphens, underscores."
        exit 1
    fi

    read -p "Database name [$DB_NAME]: " input
    DB_NAME="${input:-$DB_NAME}"

    if [[ ! "$DB_NAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
        log_error "Invalid database name."
        exit 1
    fi

    if [ "$SUBFOLDER" != "nucleus" ]; then
        log_warn "Custom subfolder '$SUBFOLDER' — add htdocs/$SUBFOLDER/ to webserver/.gitignore if needed"
    fi

    echo ""
    log_info "Deploy to:  htdocs/$SUBFOLDER/"
    log_info "Database:   $DB_NAME"
    log_info "DB creds:   $DB_USER / $DB_PASS @ ${DB_HOST}:${DB_PORT}"
    echo ""
}

#-------------------------------------------------------------------------------
# Ensure MariaDB is running
#-------------------------------------------------------------------------------

wait_for_mariadb() {
    local i
    for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
        if [ -S "$WEBSERVER_DIR/mariadb/run/mariadb.sock" ]; then
            if "$WEBSERVER_DIR/mariadb/bin/mysqladmin" \
                --socket="$WEBSERVER_DIR/mariadb/run/mariadb.sock" \
                -u "$DB_USER" -p"$DB_PASS" ping &>/dev/null; then
                return 0
            fi
        fi
        sleep 1
    done
    return 1
}

ensure_mariadb() {
    if wait_for_mariadb; then
        log_info "MariaDB is running"
        return
    fi

    log_info "Starting MariaDB temporarily..."
    mkdir -p "$WEBSERVER_DIR/config" "$WEBSERVER_DIR/mariadb/run" "$WEBSERVER_DIR/logs"

    cat > "$WEBSERVER_DIR/config/my.cnf" << EOF
[mysqld]
user    = $(whoami)
basedir = $WEBSERVER_DIR/mariadb
datadir = $WEBSERVER_DIR/mariadb/data
socket  = $WEBSERVER_DIR/mariadb/run/mariadb.sock
port    = $DB_PORT
bind-address = 127.0.0.1
skip-name-resolve
log_error = $WEBSERVER_DIR/logs/mariadb.log

[client]
socket  = $WEBSERVER_DIR/mariadb/run/mariadb.sock
port    = $DB_PORT
EOF

    "$WEBSERVER_DIR/mariadb/bin/mariadbd-safe" --defaults-file="$WEBSERVER_DIR/config/my.cnf" &
    STARTED_MARIADB=true

    if ! wait_for_mariadb; then
        log_error "Could not start MariaDB. Run webserver/start.sh and try again."
        exit 1
    fi

    log_info "MariaDB started"
}

stop_mariadb_if_started() {
    if [ "$STARTED_MARIADB" = true ]; then
        log_info "Stopping temporary MariaDB instance..."
        "$WEBSERVER_DIR/mariadb/bin/mysqladmin" \
            --socket="$WEBSERVER_DIR/mariadb/run/mariadb.sock" \
            -u "$DB_USER" -p"$DB_PASS" shutdown 2>/dev/null || true
    fi
}

#-------------------------------------------------------------------------------
# PHP wrapper for Composer (FrankenPHP php-cli)
#-------------------------------------------------------------------------------

setup_php_wrapper() {
    mkdir -p "$INCLUDED_DIR"
    cat > "$INCLUDED_DIR/php-wrapper" << EOF
#!/usr/bin/env bash
FRANKENPHP="$FRANKENPHP"
args=()
skip=0
for arg in "\$@"; do
    if [ "\$skip" -eq 1 ]; then
        skip=0
        continue
    fi
    if [ "\$arg" = "-d" ]; then
        skip=1
        continue
    fi
    args+=("\$arg")
done
exec "\$FRANKENPHP" php-cli "\${args[@]}"
EOF
    chmod +x "$INCLUDED_DIR/php-wrapper"
}

#-------------------------------------------------------------------------------
# Download and extract
#-------------------------------------------------------------------------------

download_nucleus() {
    log_step "Downloading NucleusCMS v${NUCLEUS_VERSION}..."

    DEPLOY_DIR="$WEBSERVER_DIR/htdocs/$SUBFOLDER"
    TMP_DIR=$(mktemp -d)
    ZIP_FILE="$TMP_DIR/nucleus.zip"

    if command -v curl &> /dev/null; then
        curl -L -o "$ZIP_FILE" "$NUCLEUS_URL"
    else
        wget -O "$ZIP_FILE" "$NUCLEUS_URL"
    fi

    log_info "Extracting to htdocs/$SUBFOLDER/..."
    EXTRACT_DIR="$TMP_DIR/extract"
    mkdir -p "$EXTRACT_DIR"

    if command -v unzip &> /dev/null; then
        unzip -q "$ZIP_FILE" -d "$EXTRACT_DIR"
    elif python3 -c "import zipfile" 2>/dev/null; then
        python3 -c "import zipfile; zipfile.ZipFile('$ZIP_FILE').extractall('$EXTRACT_DIR')"
    else
        log_error "Need unzip or python3 to extract the download."
        rm -rf "$TMP_DIR"
        exit 1
    fi

    SRC_DIR=$(find "$EXTRACT_DIR" -maxdepth 1 -type d -name 'NucleusCMS-*' | head -1)
    if [ -z "$SRC_DIR" ] || [ ! -d "$SRC_DIR" ]; then
        log_error "Unexpected archive layout."
        rm -rf "$TMP_DIR"
        exit 1
    fi

    rm -rf "$DEPLOY_DIR"
    mkdir -p "$DEPLOY_DIR"
    shopt -s dotglob nullglob
    cp -a "$SRC_DIR"/* "$DEPLOY_DIR/"
    shopt -u dotglob nullglob

    rm -rf "$TMP_DIR"
    log_info "NucleusCMS deployed to htdocs/$SUBFOLDER/"
}

#-------------------------------------------------------------------------------
# Post-deploy patches and config
#
# All MINISTACK-specific NucleusCMS changes live here — do not patch htdocs by hand.
#   1. patch_php_version           — allow PHP 8.4 (FrankenPHP)
#   2. patch_php84_error_reporting — fix E_STRICT deprecation on PHP 8.4
#   3. generate_install_config    — wizard defaults + FrankenPHP auth bypass
#   5. patch_hardcoded_japanese    — English strings left hardcoded in v3.8dev
#   6. extract_skin_bundle        — unzip skins-bundle.zip to htdocs/nucleus/skins/
#   7. import_extra_skins         — import skinbackup.xml into database
#   8. disable_debug_mode         — turn off debug flag after wizard
#-------------------------------------------------------------------------------

deploy_dir() {
    echo "$WEBSERVER_DIR/htdocs/$SUBFOLDER"
}

has_nucleus_deploy() {
    [ -d "$(deploy_dir)/nucleus/libs" ]
}

apply_ministack_patches() {
    if ! has_nucleus_deploy; then
        log_warn "No deploy at htdocs/$SUBFOLDER/ — skipping patches"
        return 1
    fi
    patch_php_version
    patch_php84_error_reporting
    patch_hardcoded_japanese
    clear_blade_cache
}

apply_post_install_settings() {
    disable_debug_mode
}

install_extra_skins() {
    extract_skin_bundle
}

extract_skin_bundle() {
    [ "$SKIN_BUNDLE" = true ] || return 0

    local bundle="$INCLUDED_DIR/skins-bundle.zip"
    if [ ! -f "$bundle" ]; then
        log_warn "skins-bundle.zip not found — skipping skin bundle"
        return 0
    fi

    log_step "Extracting skin bundle..."

    DEPLOY_DIR="$WEBSERVER_DIR/htdocs/$SUBFOLDER"
    mkdir -p "$DEPLOY_DIR/skins"

    if ! unzip -oq "$bundle" -d "$DEPLOY_DIR/skins/"; then
        log_error "Failed to extract skins-bundle.zip"
        exit 1
    fi

    local count
    count=$(find "$DEPLOY_DIR/skins" -mindepth 1 -maxdepth 1 -type d \
        \( -name 'skinbackup.xml' -prune -o -true \) 2>/dev/null | wc -l)
    count=$(find "$DEPLOY_DIR/skins" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    log_info "Extracted skin bundle ($count skin folders)"
}

import_extra_skins() {
    [ "$SKIN_BUNDLE" = true ] || return 0
    is_nucleus_installed || return 0

    log_step "Importing bundled skins into database..."

    DEPLOY_DIR="$WEBSERVER_DIR/htdocs/$SUBFOLDER"

    if ! "$FRANKENPHP" php-cli "$INCLUDED_DIR/import-skins.php" "$DEPLOY_DIR" \
        --all --exclude="$SKIP_FEED_SKIN_IMPORT"; then
        log_warn "Some skin imports failed — check admin (Skin Import/Export)"
        return 0
    fi
}

set_default_skin() {
    [ -n "$DEFAULT_SKIN" ] || return 0
    is_nucleus_installed || return 0
    [ -d "$WEBSERVER_DIR/mariadb/bin" ] || return 0

    "$WEBSERVER_DIR/mariadb/bin/mariadb" \
        --socket="$WEBSERVER_DIR/mariadb/run/mariadb.sock" \
        -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
        -e "UPDATE nucleus_blog SET bdefskin = (SELECT sdnumber FROM nucleus_skin_desc WHERE sdname='${DEFAULT_SKIN}' LIMIT 1) WHERE EXISTS (SELECT 1 FROM nucleus_skin_desc WHERE sdname='${DEFAULT_SKIN}');" \
        2>/dev/null || true

    log_info "Default blog skin: $DEFAULT_SKIN"
}

finish_nucleus_setup() {
    apply_post_install_settings
    import_extra_skins
    set_default_skin
}

patch_php_version() {
    log_step "Patching PHP version check for FrankenPHP 8.4..."

    DEPLOY_DIR="$WEBSERVER_DIR/htdocs/$SUBFOLDER"
    VERSION_CHECK="$DEPLOY_DIR/nucleus/libs/php_version_check.php"

    if [ ! -f "$VERSION_CHECK" ]; then
        log_error "php_version_check.php not found — wrong branch?"
        exit 1
    fi

    sed -i 's/(80400 <= PHP_VERSION_ID)/(80500 <= PHP_VERSION_ID)/' "$VERSION_CHECK"
    log_info "PHP 8.4 allowed"
}

patch_php84_error_reporting() {
    log_step "Patching error reporting for PHP 8.4..."

    DEPLOY_DIR="$WEBSERVER_DIR/htdocs/$SUBFOLDER"
    GLOBALFUNCS="$DEPLOY_DIR/nucleus/libs/globalfunctions.inc.php"

    if [ ! -f "$GLOBALFUNCS" ]; then
        log_error "globalfunctions.inc.php not found"
        exit 1
    fi

    python3 - "$GLOBALFUNCS" << 'PY'
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    text = f.read()

old = """    if ( ! isset($CONF['UsingAdminArea'])
         || empty($CONF['UsingAdminArea'])) {
        ini_set('display_errors', '0');
    }
    error_reporting(E_ALL & ~E_NOTICE & ~E_STRICT & ~E_DEPRECATED);"""

new = """    ini_set('display_errors', '0');
    error_reporting(E_ALL & ~E_NOTICE & ~E_DEPRECATED);"""

if new in text:
    print("Already patched")
elif old not in text:
    sys.exit("Expected _setErrorReporting() block not found")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(text.replace(old, new, 1))
    print("Patched _setErrorReporting() for PHP 8.4")
PY

    log_info "PHP 8.4 error reporting fixed"
}

patch_hardcoded_japanese() {
    log_step "Patching hardcoded Japanese strings..."

    DEPLOY_DIR="$WEBSERVER_DIR/htdocs/$SUBFOLDER"
    ADMIN_PHP="$DEPLOY_DIR/nucleus/libs/ADMIN.php"
    LOGIN_BLADE="$DEPLOY_DIR/nucleus/views/admin/login.blade.php"

    if [ -f "$ADMIN_PHP" ]; then
        sed -i "s/古い暗号化でパスワードが保存されています。安全のためパスワードを変更してください。/Your password uses legacy encryption. Please change your password for security./" \
            "$ADMIN_PHP"
    fi

    if [ -f "$LOGIN_BLADE" ]; then
        sed -i \
            -e 's/パスワードを表示/Show password/g' \
            -e 's/パスワードを非表示/Hide password/g' \
            "$LOGIN_BLADE"
    fi

    log_info "Japanese UI strings replaced with English"
}

clear_blade_cache() {
    DEPLOY_DIR="$WEBSERVER_DIR/htdocs/$SUBFOLDER"
    BLADE_CACHE="$DEPLOY_DIR/nucleus/cache/blade.cache"
    rm -rf "$BLADE_CACHE" 2>/dev/null || true
    mkdir -p "$BLADE_CACHE"
    chmod 775 "$BLADE_CACHE" 2>/dev/null || true
}

disable_debug_mode() {
    if [ ! -d "$WEBSERVER_DIR/mariadb/bin" ]; then
        return
    fi
    "$WEBSERVER_DIR/mariadb/bin/mysql" \
        --socket="$WEBSERVER_DIR/mariadb/run/mariadb.sock" \
        -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
        -e "UPDATE nucleus_config SET value='0' WHERE name='debug';" \
        2>/dev/null || true
}

generate_install_config() {
    log_step "Creating install-config.php..."

    DEPLOY_DIR="$WEBSERVER_DIR/htdocs/$SUBFOLDER"
    BASE_URL="http://localhost:8080/$SUBFOLDER"

    cat > "$DEPLOY_DIR/install/install-config.php" << EOF
<?php
// MINISTACK NucleusCMS install config — generated $(date)

\$INSTALL_MODE = 'BASIC';
\$INSTALL_AUTH_USER = 'mini';
\$INSTALL_AUTH_PW = 'stack';
\$INSTALL_ALLOW_IP = '';

\$INSTALL_DEFAULTS = [
    'db_host'         => '${DB_HOST}:${DB_PORT}',
    'db_user'         => '$DB_USER',
    'db_password'     => '$DB_PASS',
    'db_database'     => '$DB_NAME',
    'db_create'       => false,
    'db_use_prefix'   => false,
    'db_table_prefix' => '',

    'index_url'  => '${BASE_URL}/',
    'admin_url'  => '${BASE_URL}/nucleus/',
    'admin_path' => '$DEPLOY_DIR/nucleus/',
    'media_url'  => '${BASE_URL}/media/',
    'media_path' => '$DEPLOY_DIR/media/',
    'skins_url'  => '${BASE_URL}/skins/',
    'skins_path' => '$DEPLOY_DIR/skins/',
    'plugin_url' => '${BASE_URL}/nucleus/plugins/',
    'action_url' => '${BASE_URL}/action.php',

    'user_name'     => '$ADMIN_USER',
    'user_realname' => 'Admin',
    'user_password' => '$ADMIN_PASS',
    'user_email'    => '$ADMIN_EMAIL',

    'blog_name'      => '$BLOG_NAME',
    'blog_shortname' => '$BLOG_SHORTNAME',
];

\$CONF['PHP_BIN'] = '$INCLUDED_DIR/php-wrapper';

// MINISTACK: FrankenPHP does not always populate PHP_AUTH_* from browser requests
if ( ! isset(\$_SERVER['PHP_AUTH_USER']) && ! empty(\$_SERVER['HTTP_AUTHORIZATION'])) {
    if (preg_match('/Basic\\s+(.*)\$/i', \$_SERVER['HTTP_AUTHORIZATION'], \$m)) {
        \$pair = base64_decode(\$m[1], true);
        if (\$pair !== false && str_contains(\$pair, ':')) {
            [\$_SERVER['PHP_AUTH_USER'], \$_SERVER['PHP_AUTH_PW']] = explode(':', \$pair, 2);
        }
    }
}

// MINISTACK: skip browser auth prompt for local installs
\$remote = \$_SERVER['REMOTE_ADDR'] ?? '';
if ( ! isset(\$_SERVER['PHP_AUTH_USER']) && in_array(\$remote, ['127.0.0.1', '::1'], true)) {
    \$_SERVER['PHP_AUTH_USER'] = \$INSTALL_AUTH_USER;
    \$_SERVER['PHP_AUTH_PW'] = \$INSTALL_AUTH_PW;
}
EOF

    chmod 600 "$DEPLOY_DIR/install/install-config.php"
    log_info "install-config.php created (BASIC auth: mini/stack, DB pre-filled)"
}

run_composer() {
    log_step "Installing Composer dependencies..."

    DEPLOY_DIR="$WEBSERVER_DIR/htdocs/$SUBFOLDER"
    LIBS_DIR="$DEPLOY_DIR/nucleus/libs"
    PHP_WRAPPER="$INCLUDED_DIR/php-wrapper"

    setup_php_wrapper

    if [ ! -f "$LIBS_DIR/composer.json" ]; then
        log_warn "composer.json not found, skipping"
        return
    fi

    if [ -f "$LIBS_DIR/vendor/autoload.php" ]; then
        log_info "Composer vendor/ already present"
        return
    fi

    cd "$LIBS_DIR"

    if [ ! -f composer.phar ]; then
        if command -v curl &> /dev/null; then
            curl -sL -o composer.phar https://getcomposer.org/download/latest-2.x/composer.phar
        else
            wget -q -O composer.phar https://getcomposer.org/download/latest-2.x/composer.phar
        fi
    fi

    export PHP_BINARY="$PHP_WRAPPER"
    export COMPOSER_ALLOW_SUPERUSER=1

    if ! "$PHP_WRAPPER" composer.phar install --no-interaction --no-dev 2>&1 | tail -5; then
        log_warn "Composer install failed — will retry on first browser visit to /install/"
    else
        log_info "Composer dependencies installed"
    fi

    cd "$SCRIPT_DIR"
}

#-------------------------------------------------------------------------------
# Database setup
#-------------------------------------------------------------------------------

setup_database() {
    log_step "Creating database '$DB_NAME'..."

    if [ "$FRESH_INSTALL" = true ]; then
        log_info "Dropping existing database '$DB_NAME'..."
        "$WEBSERVER_DIR/mariadb/bin/mysql" \
            --socket="$WEBSERVER_DIR/mariadb/run/mariadb.sock" \
            -u "$DB_USER" -p"$DB_PASS" \
            -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;"
        rm -f "$WEBSERVER_DIR/htdocs/$SUBFOLDER/config.php"
    fi

    "$WEBSERVER_DIR/mariadb/bin/mysql" \
        --socket="$WEBSERVER_DIR/mariadb/run/mariadb.sock" \
        -u "$DB_USER" -p"$DB_PASS" << EOF
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
EOF

    log_info "Database '$DB_NAME' ready"
}

#-------------------------------------------------------------------------------
# File permissions
#-------------------------------------------------------------------------------

set_permissions() {
    log_step "Setting file permissions..."

    DEPLOY_DIR="$WEBSERVER_DIR/htdocs/$SUBFOLDER"

    mkdir -p "$DEPLOY_DIR/media" "$DEPLOY_DIR/skins" "$DEPLOY_DIR/nucleus/cache/blade.cache"
    chmod -R 775 "$DEPLOY_DIR/media" "$DEPLOY_DIR/skins" "$DEPLOY_DIR/nucleus/cache" 2>/dev/null || true

    log_info "Permissions set (media/, skins/, cache/blade.cache/)"
}

#-------------------------------------------------------------------------------
# Save install metadata
#-------------------------------------------------------------------------------

save_config() {
    log_step "Saving configuration..."

    mkdir -p data

    cat > config << EOF
# MINISTACK NucleusCMS Configuration
# Generated: $(date)

SUBFOLDER="$SUBFOLDER"
DEPLOY_PATH="$WEBSERVER_DIR/htdocs/$SUBFOLDER"
DB_HOST="$DB_HOST"
DB_PORT="$DB_PORT"
DB_USER="$DB_USER"
DB_PASS="$DB_PASS"
DB_NAME="$DB_NAME"
NUCLEUS_VERSION="$NUCLEUS_VERSION"
INSTALL_URL="http://localhost:8080/$SUBFOLDER/install/"
BLOG_URL="http://localhost:8080/$SUBFOLDER/"
EOF

    chmod 600 config
    date -Iseconds > data/.installed

    log_info "Configuration saved"
}

#-------------------------------------------------------------------------------
# Ensure webserver is running
#-------------------------------------------------------------------------------

ensure_webserver() {
    if curl -sf "http://localhost:8080/" >/dev/null 2>&1; then
        return
    fi
    log_info "Starting webserver..."
    (cd "$WEBSERVER_DIR" && ./start.sh) >/dev/null 2>&1
    sleep 2
    if ! curl -sf "http://localhost:8080/" >/dev/null 2>&1; then
        log_error "Webserver not responding on :8080. Run webserver/start.sh"
        exit 1
    fi
}

#-------------------------------------------------------------------------------
# Run install wizard via POST (no browser needed)
#-------------------------------------------------------------------------------

is_nucleus_installed() {
    local cfg="$WEBSERVER_DIR/htdocs/$SUBFOLDER/config.php"
    [ -f "$cfg" ] && ! grep -qE "hostname|databasename" "$cfg" 2>/dev/null
}

run_install_wizard() {
    log_step "Running install wizard automatically..."

    DEPLOY_DIR="$WEBSERVER_DIR/htdocs/$SUBFOLDER"
    BASE_URL="http://localhost:8080/$SUBFOLDER"
    INSTALL_URL="${BASE_URL}/install/?lang=en"

    if [ ! -f "$DEPLOY_DIR/install/index.php" ]; then
        log_error "Install wizard not found at htdocs/$SUBFOLDER/install/"
        exit 1
    fi

    if is_nucleus_installed; then
        log_info "NucleusCMS already installed — skipping wizard"
        apply_ministack_patches || true
        finish_nucleus_setup
        return
    fi

    ensure_webserver

    local response
    response=$(curl -s -X POST "$INSTALL_URL" \
        --data-urlencode "action=go" \
        --data-urlencode "install_db_type=mysql" \
        --data-urlencode "install_db_host=${DB_HOST}:${DB_PORT}" \
        --data-urlencode "install_db_user=${DB_USER}" \
        --data-urlencode "install_db_password=${DB_PASS}" \
        --data-urlencode "install_db_database=${DB_NAME}" \
        --data-urlencode "IndexURL=${BASE_URL}/" \
        --data-urlencode "AdminURL=${BASE_URL}/nucleus/" \
        --data-urlencode "AdminPath=${DEPLOY_DIR}/nucleus/" \
        --data-urlencode "MediaURL=${BASE_URL}/media/" \
        --data-urlencode "MediaPath=${DEPLOY_DIR}/media/" \
        --data-urlencode "SkinsURL=${BASE_URL}/skins/" \
        --data-urlencode "SkinsPath=${DEPLOY_DIR}/skins/" \
        --data-urlencode "PluginURL=${BASE_URL}/nucleus/plugins/" \
        --data-urlencode "ActionURL=${BASE_URL}/action.php" \
        --data-urlencode "User_name=${ADMIN_USER}" \
        --data-urlencode "User_realname=Admin" \
        --data-urlencode "User_password=${ADMIN_PASS}" \
        --data-urlencode "User_password2=${ADMIN_PASS}" \
        --data-urlencode "User_email=${ADMIN_EMAIL}" \
        --data-urlencode "Blog_name=${BLOG_NAME}" \
        --data-urlencode "Blog_shortname=${BLOG_SHORTNAME}")

    if echo "$response" | grep -q "Installation complete"; then
        log_info "NucleusCMS configured successfully"
        rm -rf "$DEPLOY_DIR/install"
        log_info "Removed install/ directory (required for admin access)"
        finish_nucleus_setup
    elif echo "$response" | grep -qi "error"; then
        log_error "Install wizard failed:"
        echo "$response" | grep -oP '(?<=border-style:dotted ">)[^<]+' | head -5
        echo ""
        echo "  Try manually: ${BASE_URL}/install/"
        exit 1
    else
        log_warn "Unexpected wizard response — check ${BASE_URL}/install/"
    fi
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
    parse_args "$@"

    if [ "$REPATCH_ONLY" = true ]; then
        load_saved_config
        ensure_mariadb
        trap stop_mariadb_if_started EXIT
        apply_ministack_patches || exit 1
        install_extra_skins
        finish_nucleus_setup
        log_info "MINISTACK patches applied to htdocs/$SUBFOLDER/"
        return
    fi

    if [ "$WIZARD_ONLY" = true ]; then
        load_saved_config
        ensure_mariadb
        trap stop_mariadb_if_started EXIT
        apply_ministack_patches || true
        install_extra_skins
        run_install_wizard
        echo ""
        log_info "Blog URL: http://localhost:8080/$SUBFOLDER/"
        echo ""
        return
    fi

    check_prerequisites
    ask_config
    ensure_mariadb

    trap stop_mariadb_if_started EXIT

    download_nucleus
    apply_ministack_patches
    install_extra_skins
    generate_install_config
    setup_php_wrapper
    run_composer
    setup_database
    set_permissions
    save_config

    if [ "$SKIP_WIZARD" != true ]; then
        run_install_wizard
    fi

    echo ""
    echo "=========================================="
    log_info "Installation complete!"
    echo "=========================================="
    echo ""
    echo "  Blog:     http://localhost:8080/$SUBFOLDER/"
    echo "  Admin:    http://localhost:8080/$SUBFOLDER/nucleus/"
    echo "  Login:    $ADMIN_USER / $ADMIN_PASS"
    echo "  Database: $DB_NAME @ ${DB_HOST}:${DB_PORT}"
    echo ""
}

main "$@"
