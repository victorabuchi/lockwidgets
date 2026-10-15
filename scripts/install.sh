#!/bin/zsh
# Builds LockWidgets the way releases are signed (Developer ID) and installs it into /Applications,
# so permissions granted while testing carry over to downloaded releases.
set -euo pipefail

cd "$(dirname "$0")/.."
BUILD=build/install

command -v xcodegen >/dev/null && xcodegen generate -q
rm -rf "$BUILD"

echo "› Building"
xcodebuild -project LockWidgets.xcodeproj -scheme LockWidgets -configuration Release -destination "generic/platform=macOS" \
    -archivePath "$BUILD/LockWidgets.xcarchive" -quiet archive
xcodebuild -exportArchive -archivePath "$BUILD/LockWidgets.xcarchive" \
    -exportOptionsPlist scripts/ExportOptions.plist -exportPath "$BUILD/export" -quiet

echo "› Installing to /Applications"
pkill -x LockWidgets || true
sleep 1
rm -rf /Applications/LockWidgets.app
cp -R "$BUILD/export/LockWidgets.app" /Applications/
open /Applications/LockWidgets.app
echo "✓ Installed and opened /Applications/LockWidgets.app"
