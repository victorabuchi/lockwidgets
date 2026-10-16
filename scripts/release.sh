#!/bin/zsh
# Builds a Developer ID signed Notchlight DMG, notarizes it when credentials are stored, and
# optionally publishes it: a GitHub release with a signed Sparkle appcast for automatic updates,
# plus the Homebrew cask.
#
#   scripts/release.sh            build dist/Notchlight-<version>.dmg
#   scripts/release.sh --publish  also create or update the GitHub release v<version>, its appcast,
#                                 and the cask in victorabuchi/homebrew-tap
#
# Notarization uses a keychain profile named "lockwidgets-notary". Create it once with:
#   xcrun notarytool store-credentials lockwidgets-notary --apple-id <you@example.com> --team-id 4T4AXT6P7X
#
# Updates are signed with the EdDSA key in ~/.config/notchlight/sparkle-ed25519.key, whose public half
# is SUPublicEDKey in project.yml. Keep a backup of it: without it, installed copies won't accept
# new versions.
set -euo pipefail

cd "$(dirname "$0")/.."
PROFILE=lockwidgets-notary
IDENTITY="Developer ID Application: Victor Abuchi (4T4AXT6P7X)"
REPO=victorabuchi/notchlight
TAP=victorabuchi/homebrew-tap
SIGNING_KEY="$HOME/.config/notchlight/sparkle-ed25519.key"
BUILD=build/release
DIST=dist

command -v xcodegen >/dev/null && xcodegen generate -q

rm -rf "$BUILD"
mkdir -p "$BUILD" "$DIST"

echo "› Archiving"
xcodebuild -project LockWidgets.xcodeproj -scheme LockWidgets -configuration Release -destination "generic/platform=macOS" \
    -archivePath "$BUILD/Notchlight.xcarchive" -clonedSourcePackagesDirPath "$BUILD/spm" -quiet archive

echo "› Exporting with Developer ID"
xcodebuild -exportArchive -archivePath "$BUILD/Notchlight.xcarchive" \
    -exportOptionsPlist scripts/ExportOptions.plist -exportPath "$BUILD/export" -quiet

APP="$BUILD/export/Notchlight.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP/Contents/Info.plist")
DMG="$DIST/Notchlight-$VERSION.dmg"
codesign --verify --deep --strict "$APP"

echo "› Building $DMG"
STAGE="$BUILD/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "Notchlight" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
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
    [[ $NOTARIZED == yes ]] || { echo "! Not publishing a build that isn't notarized."; exit 1; }
    TAG="v$VERSION"

    # Installed copies read this appcast and check the signature against SUPublicEDKey before installing.
    echo "› Signing the update"
    SIGNATURE=$("$BUILD/spm/artifacts/sparkle/Sparkle/bin/sign_update" --ed-key-file "$SIGNING_KEY" "$DMG")
    APPCAST="$BUILD/appcast.xml"
    cat > "$APPCAST" <<XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Notchlight</title>
    <item>
      <title>Notchlight $VERSION</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <sparkle:version>$BUILD_NUMBER</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
      <link>https://github.com/$REPO/releases/tag/$TAG</link>
      <enclosure url="https://github.com/$REPO/releases/download/$TAG/Notchlight-$VERSION.dmg" type="application/octet-stream" $SIGNATURE/>
    </item>
  </channel>
</rss>
XML

    # The same DMG under a fixed name, so the website's download button always gets the newest version.
    cp "$DMG" "$BUILD/Notchlight.dmg"

    NOTES="Download Notchlight-$VERSION.dmg, open it and drag Notchlight into Applications."
    if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
        echo "› Replacing the files on release $TAG"
        gh release upload "$TAG" "$DMG" "$BUILD/Notchlight.dmg" "$APPCAST" --repo "$REPO" --clobber
    else
        echo "› Creating release $TAG"
        gh release create "$TAG" "$DMG" "$BUILD/Notchlight.dmg" "$APPCAST" --repo "$REPO" --title "Notchlight $VERSION" --notes "$NOTES"
    fi

    # brew install --cask victorabuchi/tap/notchlight
    if gh repo view "$TAP" >/dev/null 2>&1; then
        echo "› Updating the Homebrew cask"
        SHA=$(shasum -a 256 "$DMG" | cut -d' ' -f1)
        gh repo clone "$TAP" "$BUILD/tap" -- --quiet
        sed -i '' -e "s/^  version \".*\"/  version \"$VERSION\"/" -e "s/^  sha256 \".*\"/  sha256 \"$SHA\"/" "$BUILD/tap/Casks/notchlight.rb"
        git -C "$BUILD/tap" commit -qam "Notchlight $VERSION"
        git -C "$BUILD/tap" push -q
    fi
fi

echo "✓ $DMG (notarized: $NOTARIZED)"
