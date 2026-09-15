#!/bin/bash
# Install a user-built DriverKit driver for the original FireWire MOTU UltraLite.
# Compatible with the Bash 3.2 shipped with macOS.
set -euo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="ASFW.app"
APP_DEST="/Applications/$APP_NAME"
DEFAULT_APP="$SCRIPT_DIR/build/ASFireWire/build/DerivedData/Build/Products/Release/$APP_NAME"
EXTENSION_ID="net.mrmidi.ASFW.ASFWDriver"
EXPECTED_BUILD="12"
EXPECTED_VERSION="0.3.0"
PAYLOAD_APP=""

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

usage() {
  cat <<'HELP'
Usage:
  install_motu_ultralite_tahoe.sh --check [path/to/ASFW.app]
  install_motu_ultralite_tahoe.sh --install [path/to/ASFW.app]
  install_motu_ultralite_tahoe.sh --verify

  --check    Validate a locally built app without changing system files.
  --install  Validate and install a locally built app, then open ASFW.
  --verify   Verify the active extension and Core Audio device after restart.
  --help     Show this help.

When no app path is supplied, the script uses the Release output produced by
motu_tahoe_driver/build_driver.sh. No prebuilt or author-signed driver is
distributed by this repository.
HELP
}

read_plist() {
  /usr/bin/plutil -extract "$1" raw "$2"
}

check_platform() {
  [[ "$(uname -s)" == "Darwin" ]] || fail "This installer requires macOS."
  local version major
  version="$(sw_vers -productVersion)"
  major="${version%%.*}"
  [[ "$major" =~ ^[0-9]+$ ]] || fail "Cannot parse macOS version: $version"
  (( major >= 26 )) || fail "This DriverKit build targets macOS Tahoe 26 or later."
  echo "macOS $version ($(sw_vers -buildVersion)); Mac model: $(sysctl -n hw.model)"

  if /usr/bin/csrutil status 2>/dev/null | /usr/bin/grep -q 'disabled'; then
    echo "SIP: disabled"
  else
    fail "SIP must be disabled from macOS Recovery for this locally signed DriverKit build."
  fi
}

resolve_payload() {
  local requested="${1:-}"
  if [[ -z "$requested" ]]; then
    if [[ -d "$SCRIPT_DIR/$APP_NAME" ]]; then
      requested="$SCRIPT_DIR/$APP_NAME"
    else
      requested="$DEFAULT_APP"
    fi
  fi
  if [[ "$requested" != /* ]]; then
    requested="$(cd "$(dirname "$requested")" 2>/dev/null && pwd)/$(basename "$requested")"
  fi
  [[ -d "$requested" ]] || fail "Local build not found: $requested"
  PAYLOAD_APP="$requested"
}

verify_payload() {
  local app_info="$PAYLOAD_APP/Contents/Info.plist"
  local dext="$PAYLOAD_APP/Contents/Library/SystemExtensions/$EXTENSION_ID.dext"
  local dext_info="$dext/Info.plist"
  local dext_binary="$dext/$EXTENSION_ID"

  [[ -f "$app_info" && -f "$dext_info" && -f "$dext_binary" ]] ||
    fail "Incomplete ASFW application bundle."
  [[ "$(read_plist CFBundleIdentifier "$app_info")" == "net.mrmidi.ASFW" ]] ||
    fail "Unexpected ASFW application identifier."
  [[ "$(read_plist CFBundleVersion "$app_info")" == "$EXPECTED_BUILD" ]] ||
    fail "ASFW.app is not build $EXPECTED_BUILD."
  [[ "$(read_plist CFBundleVersion "$dext_info")" == "$EXPECTED_BUILD" ]] ||
    fail "The embedded driver is not build $EXPECTED_BUILD."
  [[ "$(read_plist CFBundleShortVersionString "$dext_info")" == "$EXPECTED_VERSION" ]] ||
    fail "Unexpected embedded driver version."
  [[ "$(read_plist CFBundleIdentifier "$dext_info")" == "$EXTENSION_ID" ]] ||
    fail "Unexpected embedded driver identifier."

  /usr/bin/codesign --verify --deep --strict "$PAYLOAD_APP" ||
    fail "ASFW code-signature verification failed. Run build_driver.sh to sign your build."
  /usr/bin/codesign -d --entitlements - --xml "$PAYLOAD_APP" 2>/dev/null |
    /usr/bin/grep -q 'system-extension.install' ||
    fail "The application signature lacks its system-extension entitlement."
  /usr/bin/codesign -d --entitlements - --xml "$dext" 2>/dev/null |
    /usr/bin/grep -q 'driverkit' ||
    fail "The driver signature lacks DriverKit entitlements."

  if [[ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" == "1" ]]; then
    /usr/bin/lipo "$dext_binary" -verify_arch arm64e ||
      fail "The driver has no arm64e slice for this Mac."
  else
    /usr/bin/lipo "$dext_binary" -verify_arch x86_64 ||
      fail "The driver has no x86_64 slice for this Mac."
  fi
  echo "Local payload verified: ASFW $EXPECTED_VERSION build $EXPECTED_BUILD"
}

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    exec /usr/bin/sudo /bin/bash "$SCRIPT_DIR/$(basename "$0")" --install "$PAYLOAD_APP"
  fi
}

enable_developer_mode() {
  if /usr/bin/systemextensionsctl developer 2>&1 | /usr/bin/grep -q 'on'; then
    echo "Driver Extension developer mode: on"
    return
  fi
  /usr/bin/systemextensionsctl developer on
  /usr/bin/systemextensionsctl developer 2>&1 | /usr/bin/grep -q 'on' ||
    fail "Could not enable Driver Extension developer mode."
  echo "Driver Extension developer mode: enabled"
}

install_app() {
  local backup_root backup stage
  backup_root="/Library/Application Support/ASFW UltraLite/Backups"
  backup="$backup_root/$(date +%Y%m%d-%H%M%S)"
  stage="$(mktemp -d /Applications/.asfw-ultralite-stage.XXXXXX)"

  /usr/bin/ditto "$PAYLOAD_APP" "$stage/$APP_NAME"
  /usr/sbin/chown -R root:wheel "$stage/$APP_NAME"
  /bin/chmod -R u+rwX,go+rX,go-w "$stage/$APP_NAME"
  /usr/bin/xattr -dr com.apple.quarantine "$stage/$APP_NAME" 2>/dev/null || true
  /usr/bin/codesign --verify --deep --strict "$stage/$APP_NAME" ||
    fail "The staged application failed signature verification."

  if [[ -e "$APP_DEST" ]]; then
    /bin/mkdir -p "$backup"
    /bin/mv "$APP_DEST" "$backup/$APP_NAME"
    echo "Existing ASFW.app backed up to: $backup/$APP_NAME"
  fi
  if ! /bin/mv "$stage/$APP_NAME" "$APP_DEST"; then
    if [[ -e "$backup/$APP_NAME" ]]; then
      /bin/mv "$backup/$APP_NAME" "$APP_DEST"
    fi
    fail "Could not install $APP_DEST"
  fi
  /bin/rmdir "$stage"
  echo "Installed your local build: $APP_DEST"
}

open_installer_app() {
  local console_user console_uid
  console_user="$(stat -f %Su /dev/console)"
  console_uid="$(id -u "$console_user")"
  if [[ "$EUID" -eq 0 && "$console_user" != "root" ]]; then
    /bin/launchctl asuser "$console_uid" /usr/bin/sudo -u "$console_user" \
      /usr/bin/open "$APP_DEST"
  else
    /usr/bin/open "$APP_DEST"
  fi
  cat <<'NEXT'

ASFW is open. Press Install in its Overview screen.
If macOS asks for approval, enable ASFW under:
  System Settings > General > Login Items & Extensions > Driver Extensions

Restart when macOS requests it. After restarting, turn on the UltraLite and run:
  ./motu_tahoe_driver/install_motu_ultralite_tahoe.sh --verify
NEXT
}

verify_installation() {
  check_platform
  local listing
  listing="$(/usr/bin/systemextensionsctl list 2>&1)"
  if ! printf '%s\n' "$listing" | /usr/bin/awk -v id="$EXTENSION_ID" -v version="$EXPECTED_VERSION/$EXPECTED_BUILD" '
      index($0, id) && index($0, "(" version ")") && $1 == "*" && $2 == "*" { found=1 }
      END { exit(found ? 0 : 1) }
    '; then
    printf '%s\n' "$listing"
    fail "ASFW build $EXPECTED_BUILD is not both active and enabled. Install/approve it and restart."
  fi
  echo "Driver extension: active and enabled ($EXPECTED_VERSION/$EXPECTED_BUILD)"

  local audio
  audio="$(/usr/sbin/system_profiler SPAudioDataType 2>/dev/null || true)"
  if printf '%s\n' "$audio" | /usr/bin/grep -q 'MOTU UltraLite:'; then
    echo "Core Audio device: MOTU UltraLite detected"
    printf '%s\n' "$audio" | /usr/bin/awk '
      /MOTU UltraLite:/ {show=1; next}
      show && /^[[:space:]]{8}[^[:space:]].*:$/ {exit}
      show && /(Default Output|Input Channels|Output Channels|Current SampleRate|Transport)/ {print}
    '
    echo "Installation verified."
  else
    echo "Driver extension is ready, but Core Audio does not currently see the UltraLite."
    echo "Turn on the interface and check the FireWire/Thunderbolt adapter chain."
    return 2
  fi
}

main() {
  local action="${1:---install}"
  case "$action" in
    --check|--install) shift || true ;;
    --verify)
      [[ "$#" -eq 1 ]] || { usage >&2; return 2; }
      verify_installation
      return
      ;;
    --help|-h)
      usage
      return
      ;;
    *)
      usage >&2
      return 2
      ;;
  esac
  [[ "$#" -le 1 ]] || { usage >&2; return 2; }

  check_platform
  resolve_payload "${1:-}"
  verify_payload
  if [[ "$action" == "--check" ]]; then
    echo "Preflight passed; no files were changed."
    return
  fi

  require_root
  enable_developer_mode
  install_app
  open_installer_app
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
