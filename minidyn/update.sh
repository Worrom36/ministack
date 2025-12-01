#!/bin/bash
# MINIDYN - IP Update Script

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Load config
if [ ! -f "config" ]; then
    echo "Error: Run ./install.sh first"
    exit 1
fi
source config

# IP detection services (fallback chain)
get_public_ip() {
    curl -s --max-time 10 ifconfig.me 2>/dev/null ||
    curl -s --max-time 10 icanhazip.com 2>/dev/null ||
    curl -s --max-time 10 api.ipify.org 2>/dev/null ||
    curl -s --max-time 10 checkip.amazonaws.com 2>/dev/null
}

# Get current public IP
CURRENT_IP=$(get_public_ip)

if [ -z "$CURRENT_IP" ]; then
    echo "$(date): ERROR - Could not determine public IP" >> data/minidyn.log
    exit 1
fi

# Check last known IP
LAST_IP=""
if [ -f "data/last_ip" ]; then
    LAST_IP=$(cat data/last_ip)
fi

# Exit if IP hasn't changed
if [ "$CURRENT_IP" = "$LAST_IP" ]; then
    exit 0
fi

echo "$(date): IP changed from $LAST_IP to $CURRENT_IP" >> data/minidyn.log

# Update DDNS provider
case "$PROVIDER" in
    noip)
        RESPONSE=$(curl -s -u "$NOIP_USER:$DDNS_PASS" \
            "https://dynupdate.no-ip.com/nic/update?hostname=$DDNS_HOST&myip=$CURRENT_IP")
        ;;
    duckdns)
        RESPONSE=$(curl -s \
            "https://www.duckdns.org/update?domains=$DUCK_DOMAIN&token=$DUCK_TOKEN&ip=$CURRENT_IP")
        ;;
    dynu)
        RESPONSE=$(curl -s \
            "https://api.dynu.com/nic/update?hostname=$DDNS_HOST&myip=$CURRENT_IP&username=$DYNU_USER&password=$DDNS_PASS")
        ;;
    freedns)
        RESPONSE=$(curl -s \
            "https://freedns.afraid.org/dynamic/update.php?$FREEDNS_TOKEN&address=$CURRENT_IP")
        ;;
    *)
        echo "$(date): ERROR - Unknown provider: $PROVIDER" >> data/minidyn.log
        exit 1
        ;;
esac

# Log response
echo "$(date): Update response: $RESPONSE" >> data/minidyn.log

# Save current IP
echo "$CURRENT_IP" > data/last_ip

echo "Updated $DDNS_HOST to $CURRENT_IP"

