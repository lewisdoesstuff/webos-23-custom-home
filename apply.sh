#!/bin/sh

set -e -o pipefail -x

APP_DIR=/usr/palm/applications/com.webos.app.home/qml
OVERRIDE_BASEPATH="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

# Remove any old overlay + stale temp copy
umount "$APP_DIR" -l 2>/dev/null || true
sleep 1
rm -rf /tmp/weboshome-merged

# Step 1: Copy the TV's ORIGINAL app (must be unmounted first!)
cp -R "$APP_DIR" /tmp/weboshome-merged

# Step 2: Apply patches
if [ -d "$OVERRIDE_BASEPATH/patches" ]; then
    for patch in "$OVERRIDE_BASEPATH/patches"/*.patch; do
        echo "Applying $patch ..."
        (cd /tmp/weboshome-merged && patch -p2) < "$patch" || {
            echo "WARNING: $patch failed — TV version may differ"
            echo "Your customizations may not work. Check config.js instead."
        }
    done
fi

# Step 3: Overlay custom files (config.js, CustomGrid.qml, assets)
cp -R "$OVERRIDE_BASEPATH"/UserInterfaceLayer/* /tmp/weboshome-merged/UserInterfaceLayer/ 2>/dev/null || true
cp -R "$OVERRIDE_BASEPATH"/AppInitializer/* /tmp/weboshome-merged/AppInitializer/ 2>/dev/null || true
cp -R "$OVERRIDE_BASEPATH"/assets/ /tmp/weboshome-merged/assets/ 2>/dev/null || true

# Step 4: Bind-mount and restart
mount --bind /tmp/weboshome-merged "$APP_DIR"
pkill -f com.webos.app.home
