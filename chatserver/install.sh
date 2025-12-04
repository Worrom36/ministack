#!/bin/bash
#===============================================================================
#  MINISTACK CHAT SERVER INSTALLER
#  Choose between ngIRCd (lightweight) or Ergo (WebSocket support)
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
NGIRCD_VERSION="27"
ERGO_VERSION="2.14.0"

# Server choice: ngircd or ergo
IRC_SERVER=""

# Default configuration values
SERVER_NAME="irc.ministack.local"
SERVER_INFO="Ministack IRC Server"
ADMIN_NAME="Admin"
ADMIN_EMAIL="admin@ministack.local"
IRC_PORT="6667"
WS_PORT="6668"
MAX_USERS="50"
MAX_CHANNELS="20"
OPER_NAME="mini"
OPER_PASS="stack"
SERVER_PASS=""
PING_TIMEOUT="300"
MOTD_TEXT="Welcome to MINISTACK Chat"

# Detect architecture
ARCH=$(uname -m)

#-------------------------------------------------------------------------------
# Ask user for configuration
#-------------------------------------------------------------------------------

ask_config() {
    echo ""
    echo "=========================================="
    echo "  MINISTACK Chat Server Installer"
    echo "=========================================="
    echo ""
    echo "Choose IRC server:"
    echo ""
    echo "  1) Ergo    - Modern (~15MB), has WebSocket for web chat [default]"
    echo "  2) ngIRCd  - Lightweight (~1MB), no WebSocket"
    echo ""
    
    while true; do
        read -p "Select [1/2]: " choice
        case $choice in
            1|"") IRC_SERVER="ergo"; break;;
            2) IRC_SERVER="ngircd"; break;;
            *) echo "Please enter 1 or 2";;
        esac
    done
    
    echo ""
    echo "--- Server Configuration ---"
    echo ""
    
    read -p "Server name [$SERVER_NAME]: " input
    SERVER_NAME="${input:-$SERVER_NAME}"
    
    read -p "Server description [$SERVER_INFO]: " input
    SERVER_INFO="${input:-$SERVER_INFO}"
    
    read -p "Admin name [$ADMIN_NAME]: " input
    ADMIN_NAME="${input:-$ADMIN_NAME}"
    
    read -p "Admin email [$ADMIN_EMAIL]: " input
    ADMIN_EMAIL="${input:-$ADMIN_EMAIL}"
    
    read -p "IRC port [$IRC_PORT]: " input
    IRC_PORT="${input:-$IRC_PORT}"
    
    # WebSocket port only for Ergo
    if [ "$IRC_SERVER" = "ergo" ]; then
        read -p "WebSocket port [$WS_PORT]: " input
        WS_PORT="${input:-$WS_PORT}"
    fi
    
    read -p "Max users [$MAX_USERS]: " input
    MAX_USERS="${input:-$MAX_USERS}"
    
    read -p "Max channels [$MAX_CHANNELS]: " input
    MAX_CHANNELS="${input:-$MAX_CHANNELS}"
    
    read -p "Operator username [$OPER_NAME]: " input
    OPER_NAME="${input:-$OPER_NAME}"
    
    read -p "Operator password [$OPER_PASS]: " input
    OPER_PASS="${input:-$OPER_PASS}"
    
    read -p "Server password (blank for none) [$SERVER_PASS]: " input
    SERVER_PASS="${input:-$SERVER_PASS}"
    
    read -p "Ping timeout in seconds [$PING_TIMEOUT]: " input
    PING_TIMEOUT="${input:-$PING_TIMEOUT}"
    
    read -p "MOTD message [$MOTD_TEXT]: " input
    MOTD_TEXT="${input:-$MOTD_TEXT}"
    
    echo ""
    log_info "Server: $IRC_SERVER"
    log_info "  Name: $SERVER_NAME:$IRC_PORT"
    if [ "$IRC_SERVER" = "ergo" ]; then
        log_info "  WebSocket: port $WS_PORT"
    fi
    log_info "  Operator: $OPER_NAME"
    echo ""
}

#-------------------------------------------------------------------------------
# Phase 1: Create directory structure
#-------------------------------------------------------------------------------

phase_directories() {
    log_step "Creating directory structure..."
    
    mkdir -p bin
    mkdir -p etc
    mkdir -p logs
    mkdir -p run
    
    log_info "Directories created"
}

#-------------------------------------------------------------------------------
# Phase 2: Install IRC Server
#-------------------------------------------------------------------------------

phase_install() {
    if [ "$IRC_SERVER" = "ngircd" ]; then
        install_ngircd
    else
        install_ergo
    fi
}

install_ngircd() {
    log_step "Installing ngIRCd..."
    
    if [ -f "bin/ngircd" ]; then
        log_warn "ngircd already exists, skipping"
        return
    fi
    
    # Check if ngircd is available via package manager
    if command -v apt-get &> /dev/null; then
        log_info "Installing ngircd via apt..."
        sudo apt-get update
        sudo apt-get install -y ngircd
        
        # Copy binary to local bin
        cp /usr/sbin/ngircd bin/
        
        log_info "ngIRCd installed"
    else
        log_error "Please install ngircd manually or use a Debian-based system"
        exit 1
    fi
}

install_ergo() {
    log_step "Installing Ergo..."
    
    if [ -f "bin/ergo" ]; then
        log_warn "ergo already exists, skipping"
        return
    fi
    
    # Determine download URL based on architecture
    case "$ARCH" in
        x86_64|amd64)
            ERGO_ARCH="linux-x86_64"
            ;;
        aarch64|arm64)
            ERGO_ARCH="linux-arm64"
            ;;
        armv7l|armhf)
            ERGO_ARCH="linux-armv7"
            ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    ERGO_URL="https://github.com/ergochat/ergo/releases/download/v${ERGO_VERSION}/ergo-${ERGO_VERSION}-${ERGO_ARCH}.tar.gz"
    
    log_info "Downloading Ergo v${ERGO_VERSION}..."
    curl -L "$ERGO_URL" -o ergo.tar.gz
    
    log_info "Extracting..."
    tar -xzf ergo.tar.gz
    
    # Move binary to bin/
    mv ergo-${ERGO_VERSION}-${ERGO_ARCH}/ergo bin/
    
    # Copy default language files
    mkdir -p data/languages
    if [ -d "ergo-${ERGO_VERSION}-${ERGO_ARCH}/languages" ]; then
        cp -r ergo-${ERGO_VERSION}-${ERGO_ARCH}/languages/* data/languages/ 2>/dev/null || true
    fi
    
    # Cleanup
    rm -rf ergo.tar.gz ergo-${ERGO_VERSION}-${ERGO_ARCH}
    
    log_info "Ergo installed"
}

#-------------------------------------------------------------------------------
# Phase 3: Create configuration
#-------------------------------------------------------------------------------

phase_config() {
    if [ "$IRC_SERVER" = "ngircd" ]; then
        config_ngircd
    else
        config_ergo
    fi
    
    # Create MOTD file (used by both)
    cat > etc/motd.txt << EOF

  ⚡ MINISTACK Chat Server ⚡

  $MOTD_TEXT

  Server: $SERVER_NAME
  Port:   $IRC_PORT

  Channels: #general, #help
  Operator: /oper $OPER_NAME <password>

EOF

    log_info "Configuration created"
}

config_ngircd() {
    log_step "Creating ngIRCd configuration..."
    
    cat > etc/ngircd.conf << EOF
#===============================================================================
# ngIRCd Configuration - Ministack Chat Server
#===============================================================================

[Global]
    Name = $SERVER_NAME
    Info = $SERVER_INFO
    
    Password = $SERVER_PASS
    
    AdminInfo1 = $ADMIN_NAME
    AdminInfo2 = $ADMIN_EMAIL
    AdminEMail = $ADMIN_EMAIL
    
    Ports = $IRC_PORT
    
    MaxConnections = $MAX_USERS
    MaxConnectionsIP = 5
    MaxJoins = $MAX_CHANNELS
    MaxNickLength = 15
    
    PingTimeout = $PING_TIMEOUT
    PongTimeout = 20
    
    MotdFile = ./etc/motd.txt
    PidFile = ./run/ngircd.pid

[Limits]
    MaxConnections = $MAX_USERS
    MaxConnectionsIP = 5
    MaxJoins = $MAX_CHANNELS

[Options]
    OperCanUseMode = yes
    OperServerMode = no
    AllowRemoteOper = yes
    DNS = no
    Ident = no
    PAM = no
    CloakHost = ministack.user
    CloakHostModeX = ministack.user
    CloakUserToNick = no

[Operator]
    Name = $OPER_NAME
    Password = $OPER_PASS

[Channel]
    Name = #general
    Topic = General chat
    Modes = tn

[Channel]
    Name = #help
    Topic = Help and support
    Modes = tn
EOF
}

config_ergo() {
    log_step "Creating Ergo configuration..."
    
    mkdir -p data
    
    # Generate password hash
    OPER_HASH=$(echo "$OPER_PASS" | ./bin/ergo genpasswd)
    
    cat > etc/ircd.yaml << EOF
# Ergo IRC Server Configuration - Ministack Chat Server

network:
    name: "$SERVER_NAME"

server:
    name: "$SERVER_NAME"
    listeners:
        ":$IRC_PORT":
            # Standard IRC port
        ":$WS_PORT":
            websocket: true
            # WebSocket for web clients
    
    enforce-utf8: true
    max-sendq: 96k
    
    connection-limits:
        cidr-len-ipv4: 32
        cidr-len-ipv6: 64
        connections-per-subnet: 5
        exempted: []
    
    connection-throttling:
        enabled: true
        cidr-len-ipv4: 32
        cidr-len-ipv6: 64
        connections-per-period: 6
        duration: 1m
        ban-duration: 10m
        ban-message: "Too many connections"
        exempted: []

accounts:
    authentication-enabled: true
    registration:
        enabled: true
        allow-before-connect: true
        throttling:
            enabled: true
            duration: 10m
            max-attempts: 3
        bcrypt-cost: 4
        email-verification:
            enabled: false
    login-throttling:
        enabled: true
        duration: 1m
        max-attempts: 3
    skip-server-password: false
    nick-reservation:
        enabled: true
        additional-nick-limit: 2
        method: strict

channels:
    default-modes: +nt
    max-channels-per-client: $MAX_CHANNELS
    registration:
        enabled: true

opers:
    $OPER_NAME:
        password: "$OPER_HASH"
        whois-line: "is a server operator"
        class: "server-admin"

oper-classes:
    server-admin:
        title: "Server Admin"
        capabilities:
            - "local_kill"
            - "local_ban"
            - "local_unban"
            - "rehash"
            - "die"
            - "samode"
            - "kick"

limits:
    nicklen: 32
    identlen: 20
    channellen: 64
    topiclen: 390
    awaylen: 390
    kicklen: 390
    linelen:
        rest: 2048
    multiline:
        max-bytes: 4096
        max-lines: 100

history:
    enabled: true
    channel-length: 1024
    client-length: 256
    autoresize-window: 3d
    autoreplay-on-join: 100
    chathistory-maxmessages: 1000
    znc-maxmessages: 2048
    restrictions:
        expire-time: 1w
        query-cutoff: "none"
        grace-period: 1h

logging:
    - method: stderr
      level: info
      type: "*"

datastore:
    path: ./data/ircd.db
    autoupgrade: true

languages:
    enabled: false
    path: ./data/languages
    default: en

motd-formatting: true
motd: ./etc/motd.txt

roleplay:
    enabled: false

fakelag:
    enabled: false
EOF
}


#-------------------------------------------------------------------------------
# Phase 4: Create start/stop scripts
#-------------------------------------------------------------------------------

phase_scripts() {
    if [ "$IRC_SERVER" = "ngircd" ]; then
        scripts_ngircd
    else
        scripts_ergo
    fi
    
    log_info "Scripts created"
}

scripts_ngircd() {
    log_step "Creating ngIRCd start/stop scripts..."
    
    cat > start.sh << EOF
#!/bin/bash
SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
cd "\$SCRIPT_DIR"

echo "Starting ngIRCd..."
./bin/ngircd -f ./etc/ngircd.conf -n &

echo ""
echo "=========================================="
echo "  IRC Server is running!"
echo "=========================================="
echo "  Server: $SERVER_NAME"
echo "  Port:   $IRC_PORT"
echo "  Connect: /server localhost $IRC_PORT"
echo "=========================================="
EOF
    chmod +x start.sh
    
    cat > stop.sh << EOF
#!/bin/bash
SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
cd "\$SCRIPT_DIR"

echo "Stopping ngIRCd..."
if [ -f "./run/ngircd.pid" ]; then
    kill \$(cat ./run/ngircd.pid) 2>/dev/null || true
    rm -f ./run/ngircd.pid
fi
pkill -f "ngircd.*ministack" 2>/dev/null || true

echo "IRC Server stopped."
EOF
    chmod +x stop.sh
}

scripts_ergo() {
    log_step "Creating Ergo start/stop scripts..."
    
    cat > start.sh << EOF
#!/bin/bash
SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
cd "\$SCRIPT_DIR"

echo "Starting Ergo..."
./bin/ergo run --conf ./etc/ircd.yaml &
echo \$! > ./run/ergo.pid

sleep 1
echo ""
echo "=========================================="
echo "  IRC Server is running!"
echo "=========================================="
echo "  Server:    $SERVER_NAME"
echo "  IRC Port:  $IRC_PORT"
echo "  WebSocket: $WS_PORT (ws://host:$WS_PORT)"
echo ""
echo "  IRC client: /server localhost $IRC_PORT"
echo "  Web chat:   Connect via WebSocket"
echo "=========================================="
EOF
    chmod +x start.sh
    
    cat > stop.sh << EOF
#!/bin/bash
SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
cd "\$SCRIPT_DIR"

echo "Stopping Ergo..."
if [ -f "./run/ergo.pid" ]; then
    kill \$(cat ./run/ergo.pid) 2>/dev/null || true
    rm -f ./run/ergo.pid
fi
pkill -f "ergo.*ministack" 2>/dev/null || true

echo "IRC Server stopped."
EOF
    chmod +x stop.sh
}

#-------------------------------------------------------------------------------
# Phase 5: Save server type for reference
#-------------------------------------------------------------------------------

phase_save_type() {
    echo "$IRC_SERVER" > .server_type
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

main() {
    ask_config
    
    phase_directories
    phase_install
    phase_config
    phase_scripts
    phase_save_type
    
    echo ""
    echo "=========================================="
    log_info "Installation complete! ($IRC_SERVER)"
    echo "=========================================="
    echo ""
    echo "  To start:  ./start.sh"
    echo "  To stop:   ./stop.sh"
    echo ""
    echo "  Connect with any IRC client:"
    echo "  Server: localhost"
    echo "  Port:   $IRC_PORT"
    
    if [ "$IRC_SERVER" = "ergo" ]; then
        echo ""
        echo "  WebSocket for web chat:"
        echo "  ws://localhost:$WS_PORT"
    fi
    
    echo ""
    echo "  Operator login: /oper $OPER_NAME $OPER_PASS"
    echo ""
}

main "$@"

