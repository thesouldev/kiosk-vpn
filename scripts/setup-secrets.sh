#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

if [ -f "${PROJECT_ROOT}/.env" ]; then
    source "${PROJECT_ROOT}/.env"
    echo "Loaded configuration from .env file"
else
    echo "Error: .env file not found at ${PROJECT_ROOT}/.env"
    echo "Please create .env file with required configuration as per .env.example"
    exit 1
fi

REGION="${ZONE%-*}"
if [ -z "${REGION}" ]; then
    REGION="asia-south1"
fi

if [ -z "${VM_SERVICE_ACCOUNT}" ]; then
    echo "Error: VM_SERVICE_ACCOUNT not set in .env file"
    exit 1
fi

enable_apis() {
    echo "Enabling required APIs..."
    gcloud services enable secretmanager.googleapis.com \
        --project="${PROJECT_ID}" --quiet
    gcloud services enable compute.googleapis.com \
        --project="${PROJECT_ID}" --quiet
    echo "APIs enabled"
}

create_service_account() {
    echo "Creating service account..."
    if gcloud iam service-accounts describe "${VM_SERVICE_ACCOUNT}" \
        --project="${PROJECT_ID}" &>/dev/null; then
        echo "✓ Service account already exists"
    else
        gcloud iam service-accounts create vpn-vm \
            --display-name="VPN VM Service Account" \
            --project="${PROJECT_ID}"
        echo "Service account created"
    fi
}

store_env_secret() {
    echo "Storing .env configuration in Secret Manager..."

    if gcloud secrets describe vpn-env \
        --project="${PROJECT_ID}" &>/dev/null; then
        gcloud secrets versions add vpn-env \
            --data-file="${PROJECT_ROOT}/.env" \
            --project="${PROJECT_ID}" --quiet
        echo "✓ Updated vpn-env secret"
    else
        gcloud secrets create vpn-env \
            --data-file="${PROJECT_ROOT}/.env" \
            --replication-policy="user-managed" \
            --locations="${REGION}" \
            --labels="purpose=vpn,type=environment" \
            --project="${PROJECT_ID}"
        echo "✓ Created vpn-env secret"
    fi
}

store_wireguard_config() {
    echo "Storing WireGuard configuration in Secret Manager..."

    WG_CONFIG_FILE="${PROJECT_ROOT}/server/config/wg0.conf"

    if [ ! -f "${WG_CONFIG_FILE}" ]; then
        echo "Error: WireGuard config file not found at ${WG_CONFIG_FILE}"
        exit 1
    fi

    if gcloud secrets describe vpn-wireguard-config \
        --project="${PROJECT_ID}" &>/dev/null; then
        gcloud secrets versions add vpn-wireguard-config \
            --data-file="${WG_CONFIG_FILE}" \
            --project="${PROJECT_ID}" --quiet
        echo "✓ Updated vpn-wireguard-config secret"
    else
        gcloud secrets create vpn-wireguard-config \
            --data-file="${WG_CONFIG_FILE}" \
            --replication-policy="user-managed" \
            --locations="${REGION}" \
            --labels="purpose=vpn,type=wireguard-config" \
            --project="${PROJECT_ID}"
        echo "✓ Created vpn-wireguard-config secret"
    fi
}

store_squid_config() {
    echo "Creating Squid proxy configuration..."

    SQUID_CONFIG_FILE="${PROJECT_ROOT}/server/config/squid.conf"

    if [ ! -f "${SQUID_CONFIG_FILE}" ]; then
        echo "Error: Squid config file not found at ${SQUID_CONFIG_FILE}"
        exit 1
    fi

    if gcloud secrets describe vpn-squid-config \
        --project="${PROJECT_ID}" &>/dev/null; then
        gcloud secrets versions add vpn-squid-config \
            --data-file="${SQUID_CONFIG_FILE}" \
            --project="${PROJECT_ID}" --quiet
        echo "✓ Updated vpn-squid-config secret"
    else
        gcloud secrets create vpn-squid-config \
            --data-file="${SQUID_CONFIG_FILE}" \
            --replication-policy="user-managed" \
            --locations="${REGION}" \
            --labels="purpose=vpn,type=squid-config" \
            --project="${PROJECT_ID}"
        echo "Created vpn-squid-config secret"
    fi
}

grant_secret_access() {
    echo "Granting VM service account access to secrets..."

    for SECRET in vpn-env vpn-wireguard-config vpn-squid-config vpn-whitelist; do
        gcloud secrets add-iam-policy-binding ${SECRET} \
            --member="serviceAccount:${VM_SERVICE_ACCOUNT}" \
            --role="roles/secretmanager.secretAccessor" \
            --project="${PROJECT_ID}" \
            --condition=None --quiet
    done

    echo "Access granted to VM service account"
}

verify_setup() {
    echo "Verifying Secret Manager setup..."

    for SECRET in vpn-env vpn-wireguard-config vpn-squid-config vpn-whitelist; do
        if gcloud secrets describe ${SECRET} --project="${PROJECT_ID}" &>/dev/null; then
            echo "${SECRET} exists"
        else
            echo "${SECRET} not found"
        fi
    done

    ENV_IAM=$(gcloud secrets get-iam-policy vpn-env \
        --project="${PROJECT_ID}" --format=json 2>/dev/null)

    if echo "${ENV_IAM}" | grep -q "${VM_SERVICE_ACCOUNT}"; then
        echo "VM service account has access"
    else
        echo "VM service account missing access"
    fi
}

update_wireguard_config() {
    store_wireguard_config
    echo ""
    echo "WireGuard config updated in Secret Manager"
    echo ""
    echo "VPN servers will auto-sync within 5 minutes, or restart them immediately"
}

update_squid_config() {
    store_squid_config
    echo ""
    echo "Squid config updated in Secret Manager"
    echo ""
    echo "VPN servers will auto-sync within 5 minutes, or restart them immediately"
}

store_whitelist_config() {
    echo "Storing whitelist configuration in Secret Manager..."

    WHITELIST_FILE="${PROJECT_ROOT}/server/config/whitelist.txt"

    if [ ! -f "${WHITELIST_FILE}" ]; then
        echo "Error: Whitelist file not found at ${WHITELIST_FILE}"
        echo "Run: ./scripts/generate-whitelist.sh"
        exit 1
    fi

    if gcloud secrets describe vpn-whitelist \
        --project="${PROJECT_ID}" &>/dev/null; then
        gcloud secrets versions add vpn-whitelist \
            --data-file="${WHITELIST_FILE}" \
            --project="${PROJECT_ID}" --quiet
        echo "Updated vpn-whitelist secret"
    else
        gcloud secrets create vpn-whitelist \
            --data-file="${WHITELIST_FILE}" \
            --replication-policy="user-managed" \
            --locations="${REGION}" \
            --labels="purpose=vpn,type=whitelist" \
            --project="${PROJECT_ID}"
        echo "Created vpn-whitelist secret"
    fi
}

usage() {
    echo "VPN - Secret Manager Setup"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --setup              Initial setup of all secrets"
    echo "  --update-env         Update .env secret"
    echo "  --update-wireguard   Update WireGuard config secret"
    echo "  --update-squid       Update Squid config secret"
    echo "  --update-whitelist   Update whitelist secret"
    echo "  --verify             Verify Secret Manager configuration"
    echo "  --help               Display this help message"
    echo ""
    echo "Current Configuration:"
    echo "  Project: ${PROJECT_ID}"
    echo "  Region: ${REGION}"
    echo "  VM Service Account: ${VM_SERVICE_ACCOUNT}"
}

main() {
    case "${1:---help}" in
        --setup)
            echo "Running initial Secret Manager setup..."
            echo ""
            enable_apis
            create_service_account
            store_env_secret
            store_wireguard_config
            store_squid_config
            store_whitelist_config
            grant_secret_access
            verify_setup
            echo ""
            echo "✓ Secret Manager setup complete!"
            echo ""
            ;;
        --update-env)
            store_env_secret
            echo "✓ Environment secret updated"
            ;;
        --update-wireguard)
            update_wireguard_config
            ;;
        --update-squid)
            update_squid_config
            ;;
        --update-whitelist)
            store_whitelist_config
            ;;
        --verify)
            verify_setup
            ;;
        --help)
            usage
            ;;
        *)
            echo "Invalid option: ${1}"
            echo ""
            usage
            exit 1
            ;;
    esac
}

if ! command -v gcloud &> /dev/null; then
    echo "Error: gcloud CLI is not installed"
    echo "Please install Google Cloud SDK before running this script."
    exit 1
fi

if ! command -v wg &> /dev/null; then
    echo "Error: WireGuard is not installed"
    echo "Please install WireGuard before running this script:"
    echo "  brew install wireguard-tools  # macOS"
    echo "  apt-get install wireguard-tools  # Debian/Ubuntu"
    exit 1
fi

gcloud config set project "${PROJECT_ID}" --quiet

main "$@"
