#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

if [ -f "${PROJECT_ROOT}/.env" ]; then
    source "${PROJECT_ROOT}/.env"
fi

WG_CONFIG_FILE="${PROJECT_ROOT}/server/config/wg0.conf"
CLIENT_CONFIGS_DIR="${PROJECT_ROOT}/client-configs"

get_server_public_key() {
    if [ ! -f "${WG_CONFIG_FILE}" ]; then
        echo "Error: Server config not found at ${WG_CONFIG_FILE}"
        exit 1
    fi

    SERVER_PRIVATE_KEY=$(grep "PrivateKey" "${WG_CONFIG_FILE}" | awk '{print $3}')

    if [ "${SERVER_PRIVATE_KEY}" = "GENERATE_NEW_KEY_ON_SETUP" ]; then
        echo "Error: Server keys not yet generated. Run: ./scripts/generate-server-keys.sh --update-config"
        exit 1
    fi

    SERVER_PUBLIC_KEY=$(echo "${SERVER_PRIVATE_KEY}" | wg pubkey)
    echo "${SERVER_PUBLIC_KEY}"
}

get_next_ip() {
    if [ ! -f "${WG_CONFIG_FILE}" ]; then
        echo "10.8.0.100"
        return
    fi

    LAST_OCTET=$(grep "AllowedIPs" "${WG_CONFIG_FILE}" | \
                 sed 's/.*10\.8\.0\.\([0-9]*\).*/\1/' | \
                 sort -n | tail -1)

    if [ -z "${LAST_OCTET}" ]; then
        echo "10.8.0.100"
    else
        NEXT_OCTET=$((LAST_OCTET + 1))
        echo "10.8.0.${NEXT_OCTET}"
    fi
}

generate_client_config() {
    CLIENT_NAME=$1
    CLIENT_IP=$2
    SERVER_ENDPOINT=$3

    CLIENT_PRIVATE_KEY=$(wg genkey)
    CLIENT_PUBLIC_KEY=$(echo "${CLIENT_PRIVATE_KEY}" | wg pubkey)

    SERVER_PUBLIC_KEY=$(get_server_public_key)

    mkdir -p "${CLIENT_CONFIGS_DIR}"

    CLIENT_CONFIG_FILE="${CLIENT_CONFIGS_DIR}/${CLIENT_NAME}.conf"

    cat > "${CLIENT_CONFIG_FILE}" << EOF
[Interface]
# VPN Client Configuration
# Generated: $(date)
PrivateKey = ${CLIENT_PRIVATE_KEY}
Address = ${CLIENT_IP}/24
DNS = 8.8.8.8, 8.8.4.4

[Peer]
PublicKey = ${SERVER_PUBLIC_KEY}
Endpoint = ${SERVER_ENDPOINT}:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

    echo "Client config created: ${CLIENT_CONFIG_FILE}"

    export CLIENT_PUBLIC_KEY
    export CLIENT_IP
    export CLIENT_NAME
}

add_peer_to_server() {
    if [ ! -f "${WG_CONFIG_FILE}" ]; then
        echo "Error: Server config not found"
        exit 1
    fi

    if grep -q "${CLIENT_PUBLIC_KEY}" "${WG_CONFIG_FILE}"; then
        echo "Peer already exists in server config"
        return
    fi

    cat >> "${WG_CONFIG_FILE}" << EOF

# Client: ${CLIENT_NAME}
[Peer]
PublicKey = ${CLIENT_PUBLIC_KEY}
AllowedIPs = ${CLIENT_IP}/32
EOF

    echo "Peer added to: server/config/wg0.conf"
}

show_client_config() {
    CLIENT_CONFIG_FILE="${CLIENT_CONFIGS_DIR}/${CLIENT_NAME}.conf"

    echo ""
    echo "Client configuration saved to: ${CLIENT_CONFIG_FILE}"
}

list_clients() {
    echo "Clients in server config:"

    if [ ! -f "${WG_CONFIG_FILE}" ]; then
        echo "No server config found"
        return
    fi

    awk '
    /^# Client:/ {
        client = $3
    }
    /^AllowedIPs =/ && client != "" {
        ip = $3
        print "  " client " - " ip
        client = ""
    }
    ' "${WG_CONFIG_FILE}"
}

usage() {
    echo "VPN - Generate Client Configuration"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --name <name>              Client name (required)"
    echo "  --ip <ip>                  Client IP (auto-assigned if not provided)"
    echo "  --list                     List all existing clients"
    echo "  --help                     Display this help message"
    echo ""
    echo "Examples:"
    echo "  Generate client with auto IP:"
    echo "    $0 --name laptop"
    echo ""
    echo "  Specify custom IP:"
    echo "    $0 --name desktop --ip 10.8.0.150"
    echo ""
    echo "  List existing clients:"
    echo "    $0 --list"
    echo ""
    echo "Note: VPN_ENDPOINT must be set in .env file"
}

main() {
    CLIENT_NAME=""
    CLIENT_IP=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --name)
                CLIENT_NAME="$2"
                shift 2
                ;;
            --ip)
                CLIENT_IP="$2"
                shift 2
                ;;
            --list)
                list_clients
                exit 0
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    if [ -z "${CLIENT_NAME}" ]; then
        echo "Error: Client name is required"
        usage
        exit 1
    fi

    if [ -z "${VPN_ENDPOINT}" ]; then
        echo "Error: VPN_ENDPOINT not set in .env file"
        exit 1
    fi

    if [ -z "${CLIENT_IP}" ]; then
        CLIENT_IP=$(get_next_ip)
        echo "Auto-assigned IP: ${CLIENT_IP}"
    fi

    echo "Using VPN endpoint: ${VPN_ENDPOINT}"
    generate_client_config "${CLIENT_NAME}" "${CLIENT_IP}" "${VPN_ENDPOINT}"

    add_peer_to_server

    show_client_config

    echo ""
    echo "Client generation complete"
    echo ""
}

if ! command -v wg &> /dev/null; then
    echo "Error: WireGuard is not installed"
    echo "Please install WireGuard before running this script:"
    echo "  brew install wireguard-tools  # macOS"
    echo "  apt-get install wireguard-tools  # Debian/Ubuntu"
    exit 1
fi

main "$@"
