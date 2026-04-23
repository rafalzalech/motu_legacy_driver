#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  exec sudo bash "$0" "$@"
fi

ITEMS=(
  "Applications/MOTU Audio Setup.app"
  "Applications/MOTU Audio Tools.app"
  "Applications/MOTU Discovery.app"
  "Applications/MOTU Pro Audio System Extension.app"
  "Applications/MOTU SMPTE Setup.app"
  "Library/Application Support/MOTU"
  "Library/Audio/MIDI Devices/MOTU"
  "Library/Extensions/MOTUFireWireAudio.kext"
  "Library/LaunchAgents/com.motu.MOTULauncher.plist"
  "Library/LaunchAgents/com.motu.proaudio.HTTPServer.launchd.plist"
  "Library/LaunchAgents/com.motu.proaudio.discovery.plist"
  "Library/LaunchDaemons/com.motu.driver.proaudio.dextmidiproxy.plist"
)

copy_item() {
  local rel="$1"
  local src="$SCRIPT_DIR/$rel"
  local dst="/$rel"

  if [[ ! -e "$src" ]]; then
    echo "Missing bundled item: $src" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$dst")"
  ditto "$src" "$dst"
  echo "Installed: $dst"
}

echo "Installing MOTU bundle from: $SCRIPT_DIR"

for item in "${ITEMS[@]}"; do
  copy_item "$item"
done

if [[ -e /Library/Extensions/MOTUFireWireAudio.kext ]]; then
  chown -R root:wheel /Library/Extensions/MOTUFireWireAudio.kext
fi

if [[ -e /Library/LaunchDaemons/com.motu.driver.proaudio.dextmidiproxy.plist ]]; then
  chown root:wheel /Library/LaunchDaemons/com.motu.driver.proaudio.dextmidiproxy.plist
fi

touch /Library/Extensions || true

if command -v kmutil >/dev/null 2>&1; then
  if kmutil install --volume-root / --update-all; then
    echo "Kernel collections updated with kmutil."
  else
    echo "kmutil update failed; reboot may still stage the kext." >&2
  fi
elif command -v kextcache >/dev/null 2>&1; then
  if kextcache -i /; then
    echo "Kext caches updated with kextcache."
  else
    echo "kextcache update failed; reboot may still stage the kext." >&2
  fi
fi

cat <<'EOF'

Install complete.

If the target Mac still does not see the interface:
- make sure Startup Security allows third-party kernel extensions
- approve the MOTU kernel extension if macOS prompts for it
- reboot the Mac
EOF
