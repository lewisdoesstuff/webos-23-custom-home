#!/bin/sh

set -e -o pipefail -x

APP_DIR=/usr/palm/applications/com.webos.app.home/qml
OVERRIDE_BASEPATH="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"

# Step 1: Copy the TV's original app
cp -R "$APP_DIR" /tmp/weboshome-merged

# Step 2: Apply patches against the TV's originals
if [ -d "$OVERRIDE_BASEPATH/patches" ]; then
    for patch in "$OVERRIDE_BASEPATH/patches"/*.patch; do
        echo "Applying $patch ..."
        patch -d /tmp/weboshome-merged -p2 < "$patch" || true
    done
fi

# Step 3: Overlay custom files
cp -R "$OVERRIDE_BASEPATH"/UserInterfaceLayer/* /tmp/weboshome-merged/UserInterfaceLayer/ 2>/dev/null || true
cp -R "$OVERRIDE_BASEPATH"/assets/* /tmp/weboshome-merged/assets/ 2>/dev/null || true

# Step 4: Bind-mount and restart
mount --bind /tmp/weboshome-merged "$APP_DIR"
pkill -f com.webos.app.home
