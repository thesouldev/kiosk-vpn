#!/bin/bash
#############################################################
# VPN Server - WireGuard Setup
# Gets config from Secret Manager and starts WireGuard
#############################################################

set -e

# Load environment
source /var/lib/vpn/.env

echo "=== Setting up WireGuard ==="

# Download WireGuard config from Secret Manager
echo "Downloading WireGuard configuration from Secret Manager..."
gcloud secrets versions access latest --secret="vpn-wireguard-config" --project="${PROJECT_ID}" > /etc/wireguard/wg0.conf
chmod 600 /etc/wireguard/wg0.conf

echo "✓ WireGuard config downloaded"

# Enable and start WireGuard
echo "Starting WireGuard service..."
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# Verify WireGuard is running
if systemctl is-active --quiet wg-quick@wg0; then
    PEER_COUNT=$(wg show wg0 | grep -c "peer:" || echo "0")
    echo "✓ WireGuard started with ${PEER_COUNT} peers"
else
    echo "✗ WireGuard failed to start"
    exit 1
fi

echo "=== WireGuard Setup Complete ==="
