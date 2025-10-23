#!/bin/bash
#############################################################
# VPN Health Check Setup
# Sets up health check HTTP server for load balancer
#############################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Copy health server script
echo "Installing health check server..."
cp "${SCRIPT_DIR}/health-server.py" /usr/local/bin/health-server.py
chmod +x /usr/local/bin/health-server.py

echo "✓ Health server installed"

# Install systemd service
echo "Installing systemd service..."
cp "${SCRIPT_DIR}/systemd/vpn-health.service" /etc/systemd/system/vpn-health.service

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable vpn-health
systemctl start vpn-health

# Verify health service is running
if systemctl is-active --quiet vpn-health; then
    echo "✓ Health check server started on port 8080"
else
    echo "✗ Health check server failed to start"
    exit 1
fi
