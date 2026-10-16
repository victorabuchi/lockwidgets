#!/bin/zsh
# Draws every widget, in each style and size, with sample data to PNG files for the website. It builds a
# test copy of Notchlight and runs it in a mode that writes the pictures and quits, without opening a window
# or reading your data. Cards are drawn in the style you name (Glass unless you say otherwise) with any blur
# left out, for the page to add. It also draws the settings and widget icons and a few island symbols.
#
#   scripts/widget-gallery.sh <output folder> [glass | frosted | solid | minimal]
set -euo pipefail

cd "$(dirname "$0")/.."
OUT="${1:?usage: scripts/widget-gallery.sh <output folder> [glass | frosted | solid | minimal]}"
STYLE="${2:-glass}"
mkdir -p "$OUT"
OUT="$(cd "$OUT" && pwd)"
BUILD=build/gallery
APP="$BUILD/Build/Products/Debug/Notchlight.app"

command -v xcodegen >/dev/null && xcodegen generate -q

echo "› Building a test copy"
xcodebuild -project LockWidgets.xcodeproj -scheme LockWidgets -configuration Debug -destination "platform=macOS,arch=$(uname -m)" \
    -derivedDataPath "$BUILD" -quiet build CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= ENABLE_HARDENED_RUNTIME=NO

# Remove the test copy afterwards, so macOS never opens it in place of the installed app.
cleanup() {
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$APP" 2>/dev/null || true
    rm -rf "$BUILD/Build/Products"
}
trap cleanup EXIT

echo "› Drawing widgets"
# Clocks read 9:41, as in Apple's own pictures: the test copy runs in a time zone where it is 9:41 right now.
# Starting early in a minute keeps every picture inside that minute.
(( $(date -u +%S) > 40 )) && sleep $(( 61 - 10#$(date -u +%S) ))
offset=$(( 9 * 60 + 41 - (10#$(date -u +%H) * 60 + 10#$(date -u +%M)) ))
(( offset > 14 * 60 )) && offset=$(( offset - 1440 ))
(( offset < -12 * 60 )) && offset=$(( offset + 1440 ))
sign=+
(( offset < 0 )) && { sign=-; offset=$(( -offset )); }
zone=$(printf "GMT%s%02d%02d" $sign $(( offset / 60 )) $(( offset % 60 )))

# Launch arguments apply to this run only and are never saved, so your own card style is untouched.
# British English gives the site one consistent format for times, dates and prices.
TZ="$zone" "$APP/Contents/MacOS/Notchlight" -renderWidgets "$OUT" -gallerySamples "$PWD/scripts/gallery-samples" -cardStyle "$STYLE" \
    -AppleLocale en_GB -AppleLanguages "(en-GB)"
