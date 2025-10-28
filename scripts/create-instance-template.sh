#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$(dirname "$SCRIPT_DIR")/.env"

[ ! -f "$ENV_FILE" ] && echo "Error: .env file not found" && exit 1
source "$ENV_FILE"

for var in PROJECT_ID ZONE VM_SERVICE_ACCOUNT; do
    [ -z "${!var}" ] && echo "Error: $var is not set" && exit 1
done

TEMPLATE_NAME="${1:-${TEMPLATE_NAME:-vpn-template}}"
MACHINE_TYPE="${MACHINE_TYPE:-e2-medium}"
BOOT_DISK_SIZE="${BOOT_DISK_SIZE:-10}"
REGION="${ZONE%-*}"

# STARTUP_SCRIPT='#!/bin/bash
# cd /opt && git clone https://github.com/thesouldev/smart-vpn.git 2>/dev/null || true
# cd /opt/smart-vpn/server && bash startup.sh'

STARTUP_SCRIPT='#!/bin/bash
cd /opt && git clone https://github.com/thesouldev/smart-vpn.git 2>/dev/null || true'

gcloud compute instance-templates create "$TEMPLATE_NAME" \
    --project="$PROJECT_ID" \
    --region="$REGION" \
    --machine-type="$MACHINE_TYPE" \
    --network-interface=network-tier=PREMIUM,subnet=default \
    --metadata=startup-script="$STARTUP_SCRIPT" \
    --maintenance-policy=MIGRATE \
    --service-account="$VM_SERVICE_ACCOUNT" \
    --scopes=https://www.googleapis.com/auth/cloud-platform \
    --create-disk=auto-delete=yes,boot=yes,device-name="$TEMPLATE_NAME",image=projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts,mode=rw,size="$BOOT_DISK_SIZE",type=pd-balanced \
    --tags=vpn-server,wireguard,http-server \
    --labels=purpose=vpn,protocol=wireguard \
    --reservation-affinity=any \
    --quiet

echo "Template: $TEMPLATE_NAME"