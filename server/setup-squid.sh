#!/bin/bash
#############################################################
# VPN Server - Squid Proxy Setup
# Gets config from Secret Manager and starts Squid
#############################################################

set -e

source /var/lib/vpn/.env

# Download Squid config from Secret Manager
echo "Downloading Squid configuration from Secret Manager..."
gcloud secrets versions access latest --secret="vpn-squid-config" --project="${PROJECT_ID}" > /etc/squid/squid.conf

echo "✓ Squid config downloaded"

# Download whitelist from Secret Manager
echo "Downloading whitelist from Secret Manager..."
gcloud secrets versions access latest --secret="vpn-whitelist" --project="${PROJECT_ID}" > /etc/squid/whitelist.txt

echo "✓ Whitelist downloaded"

# Test Squid configuration
echo "Testing Squid configuration..."
if squid -k parse 2>/dev/null; then
    echo "✓ Squid configuration valid"
else
    echo "✗ Invalid Squid configuration"
    exit 1
fi

# Enable and start Squid
echo "Starting Squid service..."
systemctl enable squid
systemctl restart squid

# Verify Squid is running
if systemctl is-active --quiet squid; then
    echo "✓ Squid proxy started"
else
    echo "✗ Squid failed to start"
    exit 1
fi

echo "=== Squid Setup Complete ==="
