#!/bin/bash
#############################################################
# VPN Configuration Sync
# Syncs configs from Secret Manager when they change
#############################################################

# Load environment
source /var/lib/vpn/.env

LAST_SYNC_FILE="/var/lib/vpn/last-sync"

# Get latest secret versions
WG_VERSION=$(gcloud secrets versions list vpn-wireguard-config --limit=1 --format='value(name)' --project="${PROJECT_ID}" 2>/dev/null || echo "none")
SQUID_VERSION=$(gcloud secrets versions list vpn-squid-config --limit=1 --format='value(name)' --project="${PROJECT_ID}" 2>/dev/null || echo "none")
WHITELIST_VERSION=$(gcloud secrets versions list vpn-whitelist --limit=1 --format='value(name)' --project="${PROJECT_ID}" 2>/dev/null || echo "none")
CURRENT_VERSION="${WG_VERSION}-${SQUID_VERSION}-${WHITELIST_VERSION}"

# Check if we've already synced this version
LOCAL_VERSION=$(cat "${LAST_SYNC_FILE}" 2>/dev/null || echo "none")

if [ "${CURRENT_VERSION}" != "${LOCAL_VERSION}" ]; then
    echo "[$(date)] New config versions detected, syncing..."

    # Download new WireGuard config
    gcloud secrets versions access latest --secret="vpn-wireguard-config" --project="${PROJECT_ID}" > /tmp/wg0.conf.new

    # Download new Squid config
    gcloud secrets versions access latest --secret="vpn-squid-config" --project="${PROJECT_ID}" > /tmp/squid.conf.new

    # Download new whitelist
    gcloud secrets versions access latest --secret="vpn-whitelist" --project="${PROJECT_ID}" > /tmp/whitelist.txt.new

    # Apply WireGuard config
    mv /tmp/wg0.conf.new /etc/wireguard/wg0.conf
    chmod 600 /etc/wireguard/wg0.conf
    systemctl restart wg-quick@wg0

    # Apply Squid config and whitelist
    mv /tmp/squid.conf.new /etc/squid/squid.conf
    mv /tmp/whitelist.txt.new /etc/squid/whitelist.txt
    systemctl reload squid

    # Update sync marker
    echo "${CURRENT_VERSION}" > "${LAST_SYNC_FILE}"
    echo "[$(date)] Config sync complete - WG:${WG_VERSION} Squid:${SQUID_VERSION} Whitelist:${WHITELIST_VERSION}"
fi
