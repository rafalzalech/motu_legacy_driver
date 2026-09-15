#!/bin/bash
# Package the current user's locally built and signed ASFW.app.
set -euo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_APP="$SCRIPT_DIR/build/ASFireWire/build/DerivedData/Build/Products/Release/ASFW.app"
APP="${1:-$DEFAULT_APP}"
OUTPUT="${2:-$SCRIPT_DIR/artifacts/MOTU-UltraLite-Tahoe-Local-Installer.zip}"
WORK_DIR="$(mktemp -d /tmp/motu-ultralite-package.XXXXXX)"
PACKAGE_DIR="$WORK_DIR/MOTU UltraLite Tahoe Local Installer"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

[[ -d "$APP" ]] || {
  echo "Local ASFW build not found: $APP" >&2
  echo "Run build_driver.sh first, or pass the path to ASFW.app." >&2
  exit 1
}
/usr/bin/codesign --verify --deep --strict "$APP" || {
  echo "The local ASFW build is not correctly signed." >&2
  exit 1
}

mkdir -p "$PACKAGE_DIR" "$(dirname "$OUTPUT")"
/usr/bin/ditto "$APP" "$PACKAGE_DIR/ASFW.app"
cp "$SCRIPT_DIR/install_motu_ultralite_tahoe.sh" \
  "$PACKAGE_DIR/Install My MOTU UltraLite Build.command"
cp "$SCRIPT_DIR/verify_motu_ultralite_tahoe.command" \
  "$PACKAGE_DIR/Verify MOTU UltraLite.command"
cp "$SCRIPT_DIR/installer_readme.txt" "$PACKAGE_DIR/README.txt"
cp "$SCRIPT_DIR/../LICENSE" "$PACKAGE_DIR/ASFireWire-LICENSE.txt"
cp "$SCRIPT_DIR/../NOTICE" "$PACKAGE_DIR/ASFireWire-NOTICE.txt"
chmod +x "$PACKAGE_DIR/Install My MOTU UltraLite Build.command" \
  "$PACKAGE_DIR/Verify MOTU UltraLite.command"

/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$PACKAGE_DIR" "$OUTPUT.new"
mv "$OUTPUT.new" "$OUTPUT"
echo "Created local package: $OUTPUT"
shasum -a 256 "$OUTPUT"
echo "This package contains a build signed locally on this Mac."
