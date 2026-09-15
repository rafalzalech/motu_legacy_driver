#!/bin/bash
# Compatible with the Bash 3.2 shipped with macOS.
set -euo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEXT_REL="Library/Extensions/MOTUFireWireAudio.kext"
KEXT_ID="com.motu.driver.FireWireAudio"
MOTU_REQUIREMENT='anchor apple generic and certificate leaf[subject.OU] = "KRCLLMGZ2D"'
# Install the legacy interface controls only. ProAudio discovery, HTTP and DEXT
# services are a different stack; none of the login jobs is needed to load a kext.
ITEMS=(
  "Applications/MOTU Audio Setup.app"
  "Applications/MOTU SMPTE Setup.app"
  "Library/Audio/MIDI Devices/MOTU/Mackie.middev"
  "$KEXT_REL"
)
STARTUP_ITEMS=(
  "Library/LaunchAgents/com.motu.MOTULauncher.plist"
  "Library/LaunchAgents/com.motu.proaudio.HTTPServer.launchd.plist"
  "Library/LaunchAgents/com.motu.proaudio.discovery.plist"
  "Library/LaunchDaemons/com.motu.driver.proaudio.dextmidiproxy.plist"
)

fail() { echo "ERROR: $*" >&2; exit 1; }

usage() {
  cat <<'HELP'
Usage: bash install_motu_ultralite_firewire.sh [--check | --diagnose | --disable-autostart]
  (no option)          Check, install the legacy driver/controls, request loading.
  --check              Read-only compatibility and signature checks; no sudo.
  --diagnose           Report installed/loaded drivers, even without a device.
  --disable-autostart  Back up and remove matching startup jobs from the old
                       installer, stopping them for the current console user.
  --help               Show this help.

Stock macOS Tahoe 26 and later lack the FireWire stack this bundle requires.
HELP
}

check_platform() {
  [[ "$(uname -s)" == Darwin ]] || fail "This installer requires macOS."
  local version major
  version="$(sw_vers -productVersion)"
  major="${version%%.*}"
  echo "macOS $version ($(sw_vers -buildVersion)); process architecture: $(uname -m)"
  [[ "$major" =~ ^[0-9]+$ ]] || fail "Cannot parse macOS version: $version"
  if (( major >= 26 )); then
    # An upgraded/patched Mac may differ from a stock installation. Inspect
    # actual kernel contents; surviving Info.plist-only directories prove nothing.
    if firewire_stack_present; then
      echo "Existing FireWire kernel support detected on macOS $version."
      echo "This is a nonstandard configuration; device operation is unverified."
      return 0
    fi
    cat >&2 <<'BLOCKED'
ERROR: No FireWire kernel stack detected on this macOS Tahoe (or later) Mac.
Apple no longer supplies supported FireWire functionality on these releases.
This bundled driver requires com.apple.iokit.IOFireWireFamily. Recopying it,
removing quarantine, installing a KDK, or rebuilding caches does not supply
that missing stack. No installation was attempted.

For a FireWire-only UltraLite, use a Mac/OS with working FireWire support.
If your interface is a USB/FireWire Hybrid, use USB with MOTU's current driver
for that exact model, not this archived FireWire bundle.
Apple: https://support.apple.com/en-ie/guide/final-cut-pro/verd0e789a4/mac
BLOCKED
    return 1
  fi
  (( major >= 11 )) || fail "This bundled driver specifies macOS 11.0 or later."
}

firewire_stack_present() {
  local listing
  if listing="$(kmutil showloaded 2>/dev/null)" &&
      [[ "$listing" == *com.apple.iokit.IOFireWireFamily* ]]; then
    return 0
  fi
  if listing="$(kmutil inspect --no-header 2>/dev/null)" &&
      [[ "$listing" == *com.apple.iokit.IOFireWireFamily* ]]; then
    return 0
  fi
  return 1
}

verify_code() {
  local path="$1"
  codesign --verify --deep --strict -R="$MOTU_REQUIREMENT" "$path" ||
    fail "Invalid MOTU signature: $path. Obtain an intact installer from MOTU."
  if [[ "$path" == *.app ]]; then
    spctl --assess --type execute --verbose=2 "$path" ||
      fail "Gatekeeper rejected $path. Do not bypass the warning; obtain an updated MOTU installer."
  fi
}

check_payload() {
  local rel executable architecture
  for rel in "${ITEMS[@]}"; do
    [[ -e "$SCRIPT_DIR/$rel" ]] || fail "Missing bundled item: $rel"
    case "$rel" in
      *.app|*.kext) verify_code "$SCRIPT_DIR/$rel" ;;
    esac
  done
  executable="$SCRIPT_DIR/$KEXT_REL/Contents/MacOS/MOTUFireWireAudio"
  # uname may report x86_64 when invoked under Rosetta; detect the actual CPU.
  if [[ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" == 1 ]]; then
    architecture=arm64e
  else
    architecture=x86_64
  fi
  lipo "$executable" -verify_arch "$architecture" ||
    fail "The kernel driver has no $architecture slice. Rosetta cannot translate kexts."
  echo "Payload signatures and kernel architecture verified."
}

require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    exec sudo /bin/bash "$SCRIPT_DIR/install_motu_ultralite_firewire.sh" "$@"
  fi
}

approval_help() {
  cat <<'HELP'
On Apple silicon, third-party kexts require Reduced Security with "Allow user
management of kernel extensions from identified developers" in Recovery's
Startup Security Utility. SIP and Gatekeeper do not need to be disabled.
Approve MOTU in System Settings (Login Items & Extensions on macOS 15, or
Privacy & Security on earlier releases), and use the requested restart.
After restarting, verify with:
  /usr/bin/kmutil showloaded | /usr/bin/grep -F com.motu.driver.FireWireAudio
  /usr/sbin/system_profiler SPAudioDataType
HELP
}

install_item() {
  local rel="$1" dst="/$1" stage
  mkdir -p "$(dirname "$dst")"
  stage="$(mktemp -d "$(dirname "$dst")/.motu-stage.XXXXXX")"
  # Preserve vendor signatures and metadata. Never merge two signed bundles.
  if ! ditto "$SCRIPT_DIR/$rel" "$stage/payload"; then
    rm -rf "$stage"
    fail "Copy failed before replacing $dst."
  fi
  chown -R root:wheel "$stage/payload"
  chmod -R u+rwX,go+rX,go-w "$stage/payload"
  if [[ -e "$dst" || -L "$dst" ]]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    mv "$dst" "$BACKUP_DIR/$rel"
  fi
  if ! mv "$stage/payload" "$dst"; then
    if [[ -e "$BACKUP_DIR/$rel" || -L "$BACKUP_DIR/$rel" ]]; then
      mv "$BACKUP_DIR/$rel" "$dst"
    fi
    rm -rf "$stage"
    fail "Could not install $dst. Earlier items may already have been installed; see $BACKUP_DIR."
  fi
  rmdir "$stage"
  echo "Installed: $dst"
}

request_driver_load() {
  # Request this one kext through kernelmanagerd. --update-all rebuilds system
  # collections and can demand a KDK; it is not the normal third-party flow.
  if ! kmutil load --bundle-path "/$KEXT_REL"; then
    echo "Driver activation failed or needs user approval; installation is NOT complete." >&2
    approval_help >&2
    return 1
  fi
  echo "Driver load request accepted. Approval/restart may still be required."
  approval_help
}

new_backup() {
  mkdir -p /Library/MOTU-Legacy-Backups
  chmod 700 /Library/MOTU-Legacy-Backups
  BACKUP_DIR="$(mktemp -d /Library/MOTU-Legacy-Backups/repair.XXXXXX)"
  echo "Backup directory: $BACKUP_DIR"
}

disable_autostart() {
  local rel dst label domain console_uid
  console_uid="$(stat -f %u /dev/console)"
  new_backup
  for rel in "${STARTUP_ITEMS[@]}"; do
    dst="/$rel"
    [[ -e "$dst" ]] || continue
    if ! cmp -s "$SCRIPT_DIR/$rel" "$dst"; then
      echo "Skipped changed startup job: $dst (does not match this bundle)."
      continue
    fi
    label="$(/usr/libexec/PlistBuddy -c 'Print :Label' "$dst")"
    case "$rel" in
      Library/LaunchDaemons/*) domain=system ;;
      *) domain="gui/$console_uid" ;;
    esac
    if launchctl print "$domain/$label" >/dev/null 2>&1; then
      launchctl bootout "$domain/$label" || fail "Could not stop $label; its plist was kept."
    fi
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    mv "$dst" "$BACKUP_DIR/$rel"
    echo "Disabled automatic startup: $label"
  done
  echo "Matching startup jobs removed. Other logged-in sessions may need to log out."
  echo "To restore, copy the saved Library/LaunchAgents and LaunchDaemons plists"
  echo "back to their original locations and restart. Apps and drivers were kept."
}

main() {
  [[ "$#" -le 1 ]] || { usage >&2; return 2; }
  case "${1:-}" in
    --help|-h) usage; return ;;
    --diagnose) /bin/bash "$SCRIPT_DIR/diagnose_motu.sh"; return ;;
    --disable-autostart)
      [[ "$(uname -s)" == Darwin ]] || fail "This requires macOS."
      require_root "$@"
      disable_autostart
      return ;;
    --check|"") ;;
    *) usage >&2; return 2 ;;
  esac
  # All preflight checks occur before sudo and before any system writes.
  check_platform
  check_payload
  if [[ "${1:-}" == --check ]]; then
    echo "Preflight passed. This does not establish device compatibility or driver approval."
    return
  fi
  require_root "$@"
  new_backup
  echo "Installing legacy MOTU components from: $SCRIPT_DIR"
  local item
  for item in "${ITEMS[@]}"; do
    install_item "$item"
  done
  request_driver_load
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
