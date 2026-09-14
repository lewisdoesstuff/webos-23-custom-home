#!/bin/bash
set -euo pipefail; cd "$(dirname "$0")"

if [ ! -f .env ]; then
    echo "ERROR: .env not found. Copy .env.example to .env and fill in HA_URL/HA_TOKEN/HA_ENTITY." >&2
    exit 1
fi
set -a; source .env; set +a

: "${HA_URL:?HA_URL must be set in .env}"
: "${HA_TOKEN:?HA_TOKEN must be set in .env}"
: "${HA_ENTITY:?HA_ENTITY must be set in .env}"

if ! command -v envsubst >/dev/null 2>&1; then
    echo "ERROR: envsubst not found (install gettext)." >&2
    exit 1
fi

rm -rf deploy
mkdir -p deploy/patches deploy/UserInterfaceLayer/Containers deploy/assets/fonts deploy/assets/icons

# Substitute HA credentials into the patch
envsubst < patches/MainView_M.patch > deploy/patches/MainView_M.patch
cp patches/SystemProperties.patch deploy/patches/
cp -R UserInterfaceLayer/* deploy/UserInterfaceLayer/
cp -R assets/* deploy/assets/
cp apply.sh deploy/ && chmod +x deploy/apply.sh

# Guard: never ship a patch with unsubstituted placeholders
if grep -qF '${HA_' deploy/patches/MainView_M.patch; then
    echo "ERROR: unsubstituted \${HA_*} placeholders remain in deploy/patches/MainView_M.patch" >&2
    exit 1
fi

echo "deploy/ ready — scp it to your TV"
