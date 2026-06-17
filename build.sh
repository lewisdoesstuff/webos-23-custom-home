#!/bin/bash
set -e; cd "$(dirname "$0")"
[ -f .env ] && set -a && source .env && set +a
rm -rf deploy
mkdir -p deploy/patches deploy/UserInterfaceLayer/Containers deploy/assets/fonts deploy/assets/icons

# Substitute HA placeholders in the MainView_M patch
if [ -n "$HA_URL" ] && [ -f patches/MainView_M.patch ]; then
    envsubst < patches/MainView_M.patch > deploy/patches/MainView_M.patch
else
    cp patches/*.patch deploy/patches/ 2>/dev/null || true
fi

cp patches/SystemProperties.patch deploy/patches/ 2>/dev/null || true
cp -R UserInterfaceLayer/* deploy/UserInterfaceLayer/ 2>/dev/null || true
cp -R assets/* deploy/assets/ 2>/dev/null || true
cp apply.sh deploy/ && chmod +x deploy/apply.sh
echo "deploy/ ready — scp it to your TV"
