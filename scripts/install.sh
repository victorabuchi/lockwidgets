#!/bin/zsh
# Builds Notchlight the way releases are signed (Developer ID) and installs it into /Applications,
# so permissions granted while testing carry over to downloaded releases.
set -euo pipefail

cd "$(dirname "$0")/.."
BUILD=build/install

command -v xcodegen >/dev/null && xcodegen generate -q
rm -rf "$BUILD"

echo "› Building"
xcodebuild -project LockWidgets.xcodeproj -scheme LockWidgets -configuration Release -destination "generic/platform=macOS" \
    -archivePath "$BUILD/Notchlight.xcarchive" -quiet archive
xcodebuild -exportArchive -archivePath "$BUILD/Notchlight.xcarchive" \
    -exportOptionsPlist scripts/ExportOptions.plist -exportPath "$BUILD/export" -quiet

echo "› Installing to /Applications"
# Before 1.3 the app was called LockWidgets; replace that copy as well.
pkill -x Notchlight || true
pkill -x LockWidgets || true
sleep 1
rm -rf /Applications/Notchlight.app /Applications/LockWidgets.app
cp -R "$BUILD/export/Notchlight.app" /Applications/
open /Applications/Notchlight.app
echo "✓ Installed and opened /Applications/Notchlight.app"
