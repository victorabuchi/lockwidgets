#!/bin/zsh
# Builds a Developer ID signed LockWidgets.dmg, notarizes it when credentials are stored,
# and optionally publishes it as a GitHub release.
#
#   scripts/release.sh            build dist/LockWidgets-<version>.dmg
#   scripts/release.sh --publish  also create or update the GitHub release v<version>
#
# Notarization uses a keychain profile named "lockwidgets-notary". Create it once with:
#   xcrun notarytool store-credentials lockwidgets-notary --apple-id <you@example.com> --team-id 4T4AXT6P7X
set -euo pipefail

cd "$(dirname "$0")/.."
PROFILE=lockwidgets-notary
IDENTITY="Developer ID Application: Victor Abuchi (4T4AXT6P7X)"
BUILD=build/release
DIST=dist

command -v xcodegen >/dev/null && xcodegen generate -q

rm -rf "$BUILD"
mkdir -p "$BUILD" "$DIST"

echo "› Archiving"
xcodebuild -project LockWidgets.xcodeproj -scheme LockWidgets -configuration Release -destination "generic/platform=macOS" \
    -archivePath "$BUILD/LockWidgets.xcarchive" -quiet archive

echo "› Exporting with Developer ID"
xcodebuild -exportArchive -archivePath "$BUILD/LockWidgets.xcarchive" \
    -exportOptionsPlist scripts/ExportOptions.plist -exportPath "$BUILD/export" -quiet

APP="$BUILD/export/LockWidgets.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="$DIST/LockWidgets-$VERSION.dmg"
codesign --verify --deep --strict "$APP"

echo "› Building $DMG"
STAGE="$BUILD/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "LockWidgets" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
codesign --sign "$IDENTITY" --timestamp "$DMG"

NOTARIZED=no
if xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
    echo "› Notarizing (takes a few minutes)"
    xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait
    xcrun stapler staple "$DMG"
    NOTARIZED=yes
else
    echo "! Skipping notarization: no keychain profile \"$PROFILE\" (see the top of this script)."
fi

if [[ "${1:-}" == "--publish" ]]; then
    TAG="v$VERSION"
    NOTES="Download LockWidgets-$VERSION.dmg, open it and drag LockWidgets into Applications."
    [[ $NOTARIZED == no ]] && NOTES+=$'\n\nThis build is signed but not notarized yet. On first launch, right-click LockWidgets and choose Open, or allow it under System Settings → Privacy & Security.'
    if gh release view "$TAG" >/dev/null 2>&1; then
        echo "› Replacing the DMG on release $TAG"
        gh release upload "$TAG" "$DMG" --clobber
        gh release edit "$TAG" --notes "$NOTES"
    else
        echo "› Creating release $TAG"
        gh release create "$TAG" "$DMG" --title "LockWidgets $VERSION" --notes "$NOTES"
    fi
fi

echo "✓ $DMG (notarized: $NOTARIZED)"
