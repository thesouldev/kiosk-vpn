#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

generate_server_keys() {
    echo "Generating WireGuard server keys..."
    TEMP_DIR=$(mktemp -d)
    cd "${TEMP_DIR}"

    wg genkey | tee server_private.key | wg pubkey > server_public.key
    SERVER_PRIVATE_KEY=$(cat server_private.key)
    SERVER_PUBLIC_KEY=$(cat server_public.key)

    echo "Keys generated"
    echo ""
    echo "Server Private Key:"
    echo "${SERVER_PRIVATE_KEY}"
    echo ""
    echo "Server Public Key:"
    echo "${SERVER_PUBLIC_KEY}"

    shred -vfz -n 3 server_private.key 2>/dev/null || rm -f server_private.key
    rm -f server_public.key
    cd - > /dev/null
    rmdir "${TEMP_DIR}"

    export SERVER_PRIVATE_KEY
    export SERVER_PUBLIC_KEY
}

update_wg0_conf() {
    WG_CONFIG_FILE="${PROJECT_ROOT}/server/config/wg0.conf"

    if [ ! -f "${WG_CONFIG_FILE}" ]; then
        echo "Error: WireGuard config file not found at ${WG_CONFIG_FILE}"
        return 1
    fi

    if grep -q "GENERATE_NEW_KEY_ON_SETUP" "${WG_CONFIG_FILE}"; then
        echo ""
        echo "Updating wg0.conf with generated private key..."
        sed -i.bak "s|PrivateKey = GENERATE_NEW_KEY_ON_SETUP|PrivateKey = ${SERVER_PRIVATE_KEY}|g" "${WG_CONFIG_FILE}"
        rm -f "${WG_CONFIG_FILE}.bak"
        echo "✓ Updated server/config/wg0.conf"
    else
        echo ""
        echo "Note: wg0.conf already has a private key set"
    fi
}

usage() {
    echo "VPN - Generate Server Keys"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --generate           Generate new server keys"
    echo "  --update-config      Generate keys and update wg0.conf"
    echo "  --help               Display this help message"
}

main() {
    case "${1:---help}" in
        --generate)
            generate_server_keys
            ;;
        --update-config)
            generate_server_keys
            update_wg0_conf
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

if ! command -v wg &> /dev/null; then
    echo "Error: WireGuard is not installed"
    echo "Please install WireGuard before running this script:"
    echo "  brew install wireguard-tools  # macOS"
    echo "  apt-get install wireguard-tools  # Debian/Ubuntu"
    exit 1
fi

main "$@"
