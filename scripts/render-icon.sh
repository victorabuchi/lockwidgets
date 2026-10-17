#!/bin/zsh
# Renders the website's copies of the app icon from LockWidgets/AppIcon.icon, the Icon Composer document the app is
# built with. To change the icon, open that file in Icon Composer (it comes with Xcode).
#
#   scripts/render-icon.sh [folder]   writes icon.png (256 px) and icon-64.png into the folder, docs/assets by default,
#                                     and icon-dark.png for the website's dark theme
set -euo pipefail

cd "$(dirname "$0")/.."
OUT=${1:-docs/assets}
ICTOOL="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
render() { "$ICTOOL" LockWidgets/AppIcon.icon --export-image --output-file "$1" --platform macOS --rendition "$3" --width "$2" --height "$2" --scale 2 >/dev/null; }
render "$OUT/icon.png" 128 Default
render "$OUT/icon-64.png" 32 Default
render "$OUT/icon-dark.png" 128 Dark
echo "✓ icon.png, icon-dark.png and icon-64.png in $OUT"
