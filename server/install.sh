#!/bin/bash
#############################################################
# VPN Server - Dependencies Installation
# Installs packages and loads environment from Secret Manager
#############################################################

set -e

# Update and install packages
echo "Updating package lists..."
apt-get update -qq

echo "Installing packages..."
apt-get install -y \
    wireguard \
    wireguard-tools \
    squid \
    curl \
    jq \
    iptables-persistent \
    python3 \
    net-tools

echo "✓ Packages installed"

# Enable IP forwarding
echo "Configuring IP forwarding..."
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
echo "✓ IP forwarding enabled"

# Create directories
mkdir -p /etc/wireguard
mkdir -p /var/lib/vpn
echo "✓ Directories created"

# Load environment from Secret Manager
echo "Loading environment from Secret Manager..."
gcloud secrets versions access latest --secret="vpn-env" > /var/lib/vpn/.env
chmod 600 /var/lib/vpn/.env

# Source environment
source /var/lib/vpn/.env

echo "✓ Environment loaded"
echo "  Project: ${PROJECT_ID}"
