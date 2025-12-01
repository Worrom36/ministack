#!/bin/bash
#===============================================================================
#  MINISTACK CHAT SERVER INSTALLER
#  Downloads and sets up ngIRCd portable IRC server
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

# ngIRCd version
NGIRCD_VERSION="27"

# Default configuration values
SERVER_NAME="irc.ministack.local"
SERVER_INFO="Ministack IRC Server"
ADMIN_NAME="Admin"
ADMIN_EMAIL="admin@ministack.local"
IRC_PORT="6667"
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
    echo "  ngIRCd - Lightweight IRC Server"
    echo "=========================================="
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
    log_info "Configuration:"
    log_info "  Server: $SERVER_NAME:$IRC_PORT"
    log_info "  Operator: $OPER_NAME"
    log_info "  Max users: $MAX_USERS"
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
# Phase 2: Install ngIRCd
#-------------------------------------------------------------------------------

phase_install() {
    log_step "Installing ngIRCd..."
    
    if [ -f "bin/ngircd" ]; then
        log_warn "ngircd already exists, skipping"
        return
    fi
    
    # Check if ngircd is available via package manager or needs compilation
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

#-------------------------------------------------------------------------------
# Phase 3: Create configuration
#-------------------------------------------------------------------------------

phase_config() {
    log_step "Creating configuration..."
    
    # Main config file
    cat > etc/ngircd.conf << EOF
#===============================================================================
# ngIRCd Configuration - Ministack Chat Server
#===============================================================================

[Global]
    Name = $SERVER_NAME
    Info = $SERVER_INFO
    
    # Password to connect to server (blank = no password)
    Password = $SERVER_PASS
    
    # Admin info
    AdminInfo1 = $ADMIN_NAME
    AdminInfo2 = $ADMIN_EMAIL
    AdminEMail = $ADMIN_EMAIL
    
    # Ports
    Ports = $IRC_PORT
    
    # Limits
    MaxConnections = $MAX_USERS
    MaxConnectionsIP = 5
    MaxJoins = $MAX_CHANNELS
    MaxNickLength = 15
    
    # Ping settings
    PingTimeout = $PING_TIMEOUT
    PongTimeout = 20
    
    # Paths (relative - ngircd runs from SCRIPT_DIR)
    MotdFile = ./etc/motd.txt
    PidFile = ./run/ngircd.pid

[Limits]
    MaxConnections = $MAX_USERS
    MaxConnectionsIP = 5
    MaxJoins = $MAX_CHANNELS

[Options]
    # Allow IRC Operators to use MODE
    OperCanUseMode = yes
    
    # Require password for OPER command
    OperServerMode = no
    
    # Allow remote users (not just localhost)
    AllowRemoteOper = yes
    
    # DNS lookups (disable for speed)
    DNS = no
    
    # Ident lookups (disable for speed)
    Ident = no
    
    # PAM authentication
    PAM = no
    
    # Cloaking (hide user hostnames)
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

    # MOTD file
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

#-------------------------------------------------------------------------------
# Phase 4: Create start/stop scripts
#-------------------------------------------------------------------------------

phase_scripts() {
    log_step "Creating start/stop scripts..."
    
    # Start script
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
    
    # Stop script
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
    
    log_info "Scripts created"
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
    
    echo ""
    echo "=========================================="
    log_info "Installation complete!"
    echo "=========================================="
    echo ""
    echo "  To start:  ./start.sh"
    echo "  To stop:   ./stop.sh"
    echo ""
    echo "  Connect with any IRC client:"
    echo "  Server: localhost"
    echo "  Port:   $IRC_PORT"
    echo ""
    echo "  Operator login: /oper $OPER_NAME $OPER_PASS"
    echo ""
}

main "$@"

