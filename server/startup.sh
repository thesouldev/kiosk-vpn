#!/bin/bash
#############################################################
# VPN Server - Main Startup Script
# Orchestrates the complete VPN server setup
#############################################################

set -e

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Step 1: Install dependencies
echo "Step 1: Installing dependencies..."
bash "${SCRIPT_DIR}/install.sh"
echo ""

# Step 2: Setup WireGuard
echo "Step 2: Setting up WireGuard..."
bash "${SCRIPT_DIR}/setup-wireguard.sh"
echo ""

# Step 3: Setup Squid
echo "Step 3: Setting up Squid proxy..."
bash "${SCRIPT_DIR}/setup-squid.sh"
echo ""

# Step 4: Setup Health Check
echo "Step 4: Setting up health check..."
bash "${SCRIPT_DIR}/setup-health.sh"
echo ""

echo "Step 5: Setting up config auto-sync..."
cp "${SCRIPT_DIR}/sync-configs.sh" /usr/local/bin/sync-configs.sh
chmod +x /usr/local/bin/sync-configs.sh

# Install cron job for auto-sync (every 5 minutes)
cp "${SCRIPT_DIR}/cron.d/vpn-sync" /etc/cron.d/vpn-sync
chmod 644 /etc/cron.d/vpn-sync

echo "✓ Auto-sync configured (runs every 5 minutes)"
echo ""

echo "✓ Setup Complete!"
