#!/bin/bash
#===============================================================================
#  MINISTACK SETUP PICKER
#  Choose which components to install or remove
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

ROOT="$(cd "$(dirname "$0")" && pwd)"
REMOVE_SKIP_CONFIRM=false

webserver_installed() { [ -x "$ROOT/webserver/frankenphp" ]; }
mariadb_installed()   { [ -x "$ROOT/webserver/mariadb/bin/mariadbd" ]; }
nucleus_installed()   { [ -f "$ROOT/webserver/htdocs/nucleus/config.php" ] && \
    ! grep -qE "hostname|databasename" "$ROOT/webserver/htdocs/nucleus/config.php" 2>/dev/null; }
chatserver_installed() { [ -x "$ROOT/chatserver/bin/ngircd" ] || [ -x "$ROOT/chatserver/bin/ergo" ]; }
minidyn_installed()   { [ -f "$ROOT/minidyn/config" ]; }

status_mark() {
    if "$1"; then
        printf "${GREEN}[installed]${NC}"
    else
        printf "${YELLOW}[not installed]${NC}"
    fi
}

nucleus_subfolder() {
    local subfolder="nucleus"
    if [ -f "$ROOT/nucleuscms/config" ]; then
        # shellcheck disable=SC1091
        source "$ROOT/nucleuscms/config"
        subfolder="${SUBFOLDER:-nucleus}"
    fi
    echo "$subfolder"
}

nucleus_db_name() {
    local db_name="nucleus"
    if [ -f "$ROOT/nucleuscms/config" ]; then
        # shellcheck disable=SC1091
        source "$ROOT/nucleuscms/config"
        db_name="${DB_NAME:-nucleus}"
    fi
    echo "$db_name"
}

nucleus_deployed() {
    [ -d "$ROOT/webserver/htdocs/$(nucleus_subfolder)" ]
}

confirm_action() {
    local prompt="$1"
    local answer
    read -p "$prompt [y/N]: " answer
    case "$answer" in
        [Yy]*) return 0 ;;
        *) return 1 ;;
    esac
}

stop_webserver() {
    if [ -x "$ROOT/webserver/stop.sh" ]; then
        log_step "Stopping web server..."
        (cd "$ROOT/webserver" && ./stop.sh) || true
    fi
}

stop_chatserver() {
    if [ -x "$ROOT/chatserver/stop.sh" ]; then
        log_step "Stopping chat server..."
        (cd "$ROOT/chatserver" && ./stop.sh) || true
    fi
}

stop_minidyn() {
    if [ -x "$ROOT/minidyn/stop.sh" ]; then
        log_step "Stopping MiniDyn..."
        (cd "$ROOT/minidyn" && ./stop.sh) || true
    fi
}

remove_path() {
    local path="$1"
    if [ -e "$path" ] || [ -L "$path" ]; then
        rm -rf "$path"
        log_info "Removed $(basename "$path")"
    fi
}

show_menu() {
    echo ""
    echo "=========================================="
    echo "  MINISTACK Setup"
    echo "=========================================="
    echo ""
    printf "  1) Web server      FrankenPHP + optional MariaDB  %b\n" "$(status_mark webserver_installed)"
    if mariadb_installed; then
        printf "                     MariaDB: installed\n"
    elif webserver_installed; then
        printf "                     MariaDB: ${YELLOW}not installed${NC}\n"
    fi
    printf "  2) NucleusCMS      Blog CMS (needs MariaDB)       %b\n" "$(status_mark nucleus_installed)"
    printf "  3) Chat server      ngIRCd or Ergo                  %b\n" "$(status_mark chatserver_installed)"
    printf "  4) MiniDyn          Dynamic DNS updater              %b\n" "$(status_mark minidyn_installed)"
    echo ""
    echo "  5) All of the above"
    echo ""
    echo "  6) Remove installed files"
    echo "  q) Quit"
    echo ""
}

show_remove_menu() {
    echo ""
    echo "=========================================="
    echo "  MINISTACK Remove"
    echo "=========================================="
    echo ""
    printf "  1) Web server      FrankenPHP, MariaDB, htdocs deploys  %b\n" "$(status_mark webserver_installed)"
    if mariadb_installed; then
        printf "                     MariaDB: installed\n"
    elif webserver_installed; then
        printf "                     MariaDB: ${YELLOW}not installed${NC}\n"
    fi
    printf "  2) NucleusCMS      Blog deploy + database               %b\n" "$(status_mark nucleus_installed)"
    if nucleus_deployed && ! nucleus_installed; then
        printf "                     Deploy dir present (partial install)\n"
    fi
    printf "  3) Chat server      ngIRCd or Ergo binaries + config     %b\n" "$(status_mark chatserver_installed)"
    printf "  4) MiniDyn          config + runtime data                %b\n" "$(status_mark minidyn_installed)"
    echo ""
    echo "  5) All of the above"
    echo "  b) Back"
    echo ""
}

run_webserver() {
    local maria_hint="${1:-}"
    log_step "Web server installer"
    if [ "$maria_hint" = "mariadb" ]; then
        log_info "NucleusCMS selected — answering Yes to MariaDB"
        printf 'y\nn\n' | "$ROOT/webserver/install.sh"
    else
        "$ROOT/webserver/install.sh"
    fi
}

run_nucleus() {
    if ! webserver_installed; then
        log_error "Web server is not installed. Run option 1 first."
        return 1
    fi
    if ! mariadb_installed; then
        log_error "MariaDB is not installed. Re-run web server setup and choose Yes for MariaDB."
        return 1
    fi
    log_step "NucleusCMS installer"
    "$ROOT/nucleuscms/install.sh"
}

run_chatserver() {
    log_step "Chat server installer"
    "$ROOT/chatserver/install.sh"
}

run_minidyn() {
    log_step "MiniDyn installer"
    "$ROOT/minidyn/install.sh"
}

drop_nucleus_database() {
    local ws="$ROOT/webserver"
    local db_name socket

    db_name="$(nucleus_db_name)"
    [ -x "$ws/mariadb/bin/mariadb" ] || return 0

    socket="$ws/mariadb/run/mariadb.sock"
    if ! "$ws/mariadb/bin/mariadb" --socket="$socket" -u mini -pstack -e "SELECT 1" &>/dev/null 2>&1; then
        log_warn "MariaDB not running — skipping DROP DATABASE (remove web server to wipe data files)"
        return 0
    fi

    log_step "Dropping database '$db_name'..."
    if "$ws/mariadb/bin/mariadb" --socket="$socket" -u mini -pstack \
        -e "DROP DATABASE IF EXISTS \`$db_name\`;" 2>/dev/null; then
        log_info "Database '$db_name' dropped"
    else
        log_warn "Could not drop database '$db_name'"
    fi
}

clean_webserver_htdocs() {
    local htdocs="$ROOT/webserver/htdocs"
    local item base

    [ -d "$htdocs" ] || return 0

    shopt -s nullglob
    for item in "$htdocs"/*; do
        base="$(basename "$item")"
        [ "$base" = "index.php" ] && continue
        rm -rf "$item"
        log_info "Removed htdocs/$base"
    done
    shopt -u nullglob
}

remove_nucleus() {
    local subfolder deploy_dir

    if ! nucleus_deployed && ! nucleus_installed && [ ! -f "$ROOT/nucleuscms/config" ]; then
        log_warn "NucleusCMS does not appear to be installed."
        return 0
    fi

    if ! $REMOVE_SKIP_CONFIRM; then
        confirm_action "Remove NucleusCMS (deploy, config, database)" || return 0
    fi

    subfolder="$(nucleus_subfolder)"
    deploy_dir="$ROOT/webserver/htdocs/$subfolder"

    drop_nucleus_database
    remove_path "$deploy_dir"
    remove_path "$ROOT/nucleuscms/config"
    remove_path "$ROOT/nucleuscms/data"
    remove_path "$ROOT/nucleuscms/included/php-wrapper"
    log_info "NucleusCMS removed"
}

remove_webserver() {
    if ! webserver_installed && ! mariadb_installed && ! nucleus_deployed; then
        log_warn "Web server does not appear to be installed."
        return 0
    fi

    if ! $REMOVE_SKIP_CONFIRM; then
        confirm_action "Remove web server (FrankenPHP, MariaDB, logs, htdocs except index.php)" || return 0
    fi

    stop_webserver
    if nucleus_deployed; then
        drop_nucleus_database || true
    fi

    remove_path "$ROOT/webserver/frankenphp"
    remove_path "$ROOT/webserver/mariadb"
    remove_path "$ROOT/webserver/logs"
    remove_path "$ROOT/webserver/config/my.cnf"
    clean_webserver_htdocs
    remove_path "$ROOT/nucleuscms/config"
    remove_path "$ROOT/nucleuscms/data"
    remove_path "$ROOT/nucleuscms/included/php-wrapper"
    log_info "Web server removed"
}

remove_chatserver() {
    if ! chatserver_installed && [ ! -f "$ROOT/chatserver/.server_type" ]; then
        log_warn "Chat server does not appear to be installed."
        return 0
    fi

    if ! $REMOVE_SKIP_CONFIRM; then
        confirm_action "Remove chat server (binaries, config, runtime files)" || return 0
    fi

    stop_chatserver
    remove_path "$ROOT/chatserver/bin"
    remove_path "$ROOT/chatserver/etc"
    remove_path "$ROOT/chatserver/logs"
    remove_path "$ROOT/chatserver/run"
    remove_path "$ROOT/chatserver/data"
    remove_path "$ROOT/chatserver/start.sh"
    remove_path "$ROOT/chatserver/stop.sh"
    remove_path "$ROOT/chatserver/.server_type"
    log_info "Chat server removed"
}

remove_minidyn() {
    if ! minidyn_installed && [ ! -d "$ROOT/minidyn/data" ]; then
        log_warn "MiniDyn does not appear to be installed."
        return 0
    fi

    if ! $REMOVE_SKIP_CONFIRM; then
        confirm_action "Remove MiniDyn (config and runtime data)" || return 0
    fi

    stop_minidyn
    remove_path "$ROOT/minidyn/config"
    remove_path "$ROOT/minidyn/data"
    log_info "MiniDyn removed"
}

remove_selection() {
    local choice="$1"

    if [ "$choice" = "5" ]; then
        if ! confirm_action "Remove ALL installed MINISTACK components"; then
            return 0
        fi
        REMOVE_SKIP_CONFIRM=true
        remove_nucleus || true
        remove_webserver || true
        remove_chatserver || true
        remove_minidyn || true
        REMOVE_SKIP_CONFIRM=false
        return 0
    fi

    case "$choice" in
        1) remove_webserver ;;
        2) remove_nucleus ;;
        3) remove_chatserver ;;
        4) remove_minidyn ;;
        *)
            log_error "Unknown choice: $choice"
            return 1
            ;;
    esac
}

parse_remove_choices() {
    local input="$1"
    local -a picks=()
    local c

    if [ "$input" = "5" ]; then
        remove_selection 5
        return
    fi

    input="${input//,/ }"
    for c in $input; do
        case "$c" in
            1|2|3|4) picks+=("$c") ;;
            "") ;;
            *) log_warn "Ignoring invalid choice: $c" ;;
        esac
    done

    if [ ${#picks[@]} -eq 0 ]; then
        return 1
    fi

    IFS=$'\n' picks=( $(printf '%s\n' "${picks[@]}" | sort -rn) )

    for c in "${picks[@]}"; do
        remove_selection "$c" || true
    done
}

remove_menu_loop() {
    while true; do
        show_remove_menu
        read -p "Remove [1-5, comma-separated, or b]: " choice

        case "$choice" in
            b|B|back) return ;;
            5) remove_selection 5 ;;
            *)
                if ! parse_remove_choices "$choice"; then
                    log_warn "Nothing to remove."
                    continue
                fi
                ;;
        esac

        echo ""
        log_info "Remove step finished."
        echo ""
        read -p "Remove another component? [y/N]: " again
        case "$again" in
            [Yy]*) ;;
            *) return ;;
        esac
    done
}

run_selection() {
    local choice="$1"

    case "$choice" in
        1) run_webserver ;;
        2)
            if ! webserver_installed || ! mariadb_installed; then
                run_webserver mariadb || return 1
            fi
            run_nucleus
            ;;
        3) run_chatserver ;;
        4) run_minidyn ;;
        5)
            run_webserver mariadb
            run_nucleus
            run_chatserver
            run_minidyn
            ;;
        *)
            log_error "Unknown choice: $choice"
            return 1
            ;;
    esac
}

parse_choices() {
    local input="$1"
    local -a picks=()
    local c

    if [ "$input" = "5" ]; then
        picks=(5)
    else
        input="${input//,/ }"
        for c in $input; do
            case "$c" in
                1|2|3|4) picks+=("$c") ;;
                "") ;;
                *) log_warn "Ignoring invalid choice: $c" ;;
            esac
        done
    fi

    if [ ${#picks[@]} -eq 0 ]; then
        return 1
    fi

    local force_maria=false
    for c in "${picks[@]}"; do
        [ "$c" = "2" ] && force_maria=true
    done

    IFS=$'\n' picks=( $(printf '%s\n' "${picks[@]}" | sort -n) )

    for c in "${picks[@]}"; do
        case "$c" in
            1)
                if $force_maria && ! mariadb_installed; then
                    run_webserver mariadb
                else
                    run_webserver
                fi
                ;;
            2)
                if ! webserver_installed || ! mariadb_installed; then
                    run_webserver mariadb || return 1
                fi
                run_nucleus
                ;;
            3) run_chatserver ;;
            4) run_minidyn ;;
            5) run_selection 5 ;;
        esac
    done
}

main() {
    while true; do
        show_menu
        read -p "Select [1-6, comma-separated, or q]: " choice

        case "$choice" in
            q|Q|quit|exit) echo ""; exit 0 ;;
            6)
                remove_menu_loop
                continue
                ;;
            5) run_selection 5 ;;
            *)
                if ! parse_choices "$choice"; then
                    log_warn "Nothing to install."
                    continue
                fi
                ;;
        esac

        echo ""
        echo "=========================================="
        log_info "Setup step finished."
        echo "=========================================="
        echo ""
        echo "  Web:      cd webserver && ./start.sh"
        echo "  Chat:     cd chatserver && ./start.sh"
        echo "  MiniDyn:  cd minidyn && ./start.sh"
        echo "  Blog:     http://localhost:8080/nucleus/"
        echo ""
        read -p "Install another component? [y/N]: " again
        case "$again" in
            [Yy]*) ;;
            *) exit 0 ;;
        esac
    done
}

main "$@"
