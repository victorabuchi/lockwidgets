#!/bin/zsh
# Draws every widget, in each style and size, with sample data to PNG files for the website. It builds a
# test copy of Notchlight and runs it in a mode that writes the pictures and quits, without opening a window
# or reading your data. Cards are drawn in the Glass style with the blur left out, for the page to add.
#
#   scripts/widget-gallery.sh <output folder>
set -euo pipefail

cd "$(dirname "$0")/.."
OUT="${1:?usage: scripts/widget-gallery.sh <output folder>}"
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
# Launch arguments apply to this run only and are never saved, so your own card style is untouched.
# British English gives the site one consistent format for times, dates and prices.
"$APP/Contents/MacOS/Notchlight" -renderWidgets "$OUT" -gallerySamples "$PWD/scripts/gallery-samples" -cardStyle glass \
    -AppleLocale en_GB -AppleLanguages "(en-GB)"
