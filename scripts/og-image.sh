#!/bin/zsh
# Draws the website's link preview, docs/assets/og.jpg (1200 by 630): the app icon and name above the MacBook lock
# screen from the page's hero. Messages, Slack and social sites show it when someone shares notchlight.com.
#
#   scripts/og-image.sh      needs Google Chrome or Chrome Canary to photograph the page
set -euo pipefail

cd "$(dirname "$0")/.."
CHROME=""
for app in "Google Chrome" "Google Chrome Canary"; do
    [[ -x "/Applications/$app.app/Contents/MacOS/$app" ]] && { CHROME="/Applications/$app.app/Contents/MacOS/$app"; break; }
done
[[ -n $CHROME ]] || { echo "! Needs Google Chrome or Chrome Canary to photograph the page."; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
"$CHROME" --headless=new --disable-gpu --hide-scrollbars --user-data-dir="$TMP/profile" --blink-settings=preferredColorScheme=1 \
    --force-device-scale-factor=2 --window-size=1280,1500 --virtual-time-budget=3000 \
    --screenshot="$TMP/page.png" "file://$PWD/docs/index.html" >/dev/null 2>&1
swift scripts/og-image.swift "$TMP/page.png" docs/assets/icon.png docs/assets/og.jpg
echo "✓ docs/assets/og.jpg"
