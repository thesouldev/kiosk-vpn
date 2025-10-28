set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

WHITELIST_JSON="${PROJECT_ROOT}/server/config/whitelist.json"
WHITELIST_TXT="${PROJECT_ROOT}/server/config/whitelist.txt"

if [ ! -f "${WHITELIST_JSON}" ]; then
    echo "Error: ${WHITELIST_JSON} not found"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed"
    echo "Please install jq:"
    echo "  brew install jq  # macOS"
    echo "  apt-get install jq  # Debian/Ubuntu"
    exit 1
fi

jq -r '.domains[] | select(.enabled == true) | .domain' "${WHITELIST_JSON}" | sort -u > "${WHITELIST_TXT}"