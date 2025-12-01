#!/bin/bash
# MINIDYN - Minimal Dynamic DNS Updater
# No external dependencies, just curl

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo "=========================================="
echo "  MINIDYN - Dynamic DNS Updater"
echo "=========================================="
echo ""

# Provider selection
echo "Supported providers:"
echo "  1) No-IP       (ddns.net, no-ip.org, etc.)"
echo "  2) DuckDNS     (duckdns.org)"
echo "  3) Dynu        (dynu.com)"
echo "  4) FreeDNS     (afraid.org)"
echo ""
read -p "Select provider [1-4]: " provider_choice

case "$provider_choice" in
    1)
        PROVIDER="noip"
        echo ""
        echo "No-IP Setup"
        echo "-----------"
        read -p "Username (email): " NOIP_USER
        echo "(Password will be prompted at start - not stored)"
        read -p "Hostname (e.g., myhost.ddns.net): " DDNS_HOST
        ;;
    2)
        PROVIDER="duckdns"
        echo ""
        echo "DuckDNS Setup"
        echo "-------------"
        read -p "Subdomain (without .duckdns.org): " DUCK_DOMAIN
        read -p "Token: " DUCK_TOKEN
        DDNS_HOST="${DUCK_DOMAIN}.duckdns.org"
        ;;
    3)
        PROVIDER="dynu"
        echo ""
        echo "Dynu Setup"
        echo "----------"
        read -p "Username: " DYNU_USER
        echo "(Password will be prompted at start - not stored)"
        read -p "Hostname: " DDNS_HOST
        ;;
    4)
        PROVIDER="freedns"
        echo ""
        echo "FreeDNS Setup"
        echo "-------------"
        echo "Get your update URL from: https://freedns.afraid.org/dynamic/"
        read -p "Update token (from URL): " FREEDNS_TOKEN
        read -p "Hostname: " DDNS_HOST
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

# Update interval
echo ""
read -p "Check interval in minutes [5]: " interval
INTERVAL="${interval:-5}"

# Create config
echo ""
echo -e "${CYAN}Creating configuration...${NC}"

cat > config << EOF
# MINIDYN Configuration
# Generated: $(date)

PROVIDER="$PROVIDER"
DDNS_HOST="$DDNS_HOST"
INTERVAL="$INTERVAL"
EOF

# Add provider-specific credentials
case "$PROVIDER" in
    noip)
        cat >> config << EOF
NOIP_USER="$NOIP_USER"
EOF
        ;;
    duckdns)
        cat >> config << EOF
DUCK_DOMAIN="$DUCK_DOMAIN"
DUCK_TOKEN="$DUCK_TOKEN"
EOF
        ;;
    dynu)
        cat >> config << EOF
DYNU_USER="$DYNU_USER"
EOF
        ;;
    freedns)
        cat >> config << EOF
FREEDNS_TOKEN="$FREEDNS_TOKEN"
EOF
        ;;
esac

chmod 600 config

# Create data directory
mkdir -p data

echo -e "${GREEN}[OK]${NC} Configuration saved"

# Update ngIRCd config if it exists
NGIRCD_CONF="../chatserver/etc/ngircd.conf"
if [ -f "$NGIRCD_CONF" ]; then
    echo ""
    read -p "Update ngIRCd server name to $DDNS_HOST? [Y/n]: " update_irc
    if [ "${update_irc,,}" != "n" ]; then
        sed -i "s/^[[:space:]]*Name = .*/    Name = $DDNS_HOST/" "$NGIRCD_CONF"
        echo -e "${GREEN}[OK]${NC} Updated ngIRCd config"
    fi
fi
echo ""
echo "=========================================="
echo -e "${GREEN}  Setup complete!${NC}"
echo "=========================================="
echo ""
echo "  Hostname: $DDNS_HOST"
echo "  Interval: Every $INTERVAL minutes"
echo ""
echo "  To start:  ./start.sh"
echo "  To stop:   ./stop.sh"
echo "  Manual:    ./update.sh"
echo ""

