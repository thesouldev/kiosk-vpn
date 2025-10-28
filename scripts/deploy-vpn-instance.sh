#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$(dirname "$SCRIPT_DIR")/.env"

[ ! -f "$ENV_FILE" ] && echo "Error: .env file not found" && exit 1
source "$ENV_FILE"

INSTANCE_NAME="${1}"
STATIC_IP_NAME="${2:-vpn-static-ip}"
TEMPLATE_NAME="${3:-vpn-template}"

if [ -z "$INSTANCE_NAME" ]; then
    echo "Usage: $0 <instance-name> [static-ip-name] [template-name]"
    exit 1
fi

REGION="${ZONE%-*}"

if ! gcloud compute addresses describe "$STATIC_IP_NAME" --region="$REGION" --project="$PROJECT_ID" &>/dev/null; then
    gcloud compute addresses create "$STATIC_IP_NAME" \
        --region="$REGION" \
        --project="$PROJECT_ID" \
        --network-tier=PREMIUM \
        --quiet
fi

STATIC_IP=$(gcloud compute addresses describe "$STATIC_IP_NAME" \
    --region="$REGION" \
    --project="$PROJECT_ID" \
    --format="value(address)")

gcloud compute instances create "$INSTANCE_NAME" \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --source-instance-template="$TEMPLATE_NAME" \
    --address="$STATIC_IP" \
    --quiet

gcloud compute firewall-rules create allow-wireguard \
    --project="$PROJECT_ID" \
    --allow=udp:51820 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=wireguard \
    --quiet 2>/dev/null || true

gcloud compute firewall-rules create allow-health-checks \
    --project="$PROJECT_ID" \
    --allow=tcp:8080 \
    --source-ranges=35.191.0.0/16,130.211.0.0/22 \
    --target-tags=http-server \
    --quiet 2>/dev/null || true

echo "Instance: $INSTANCE_NAME"
echo "IP: $STATIC_IP"
echo "VPN_ENDPOINT=$STATIC_IP"