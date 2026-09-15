#!/bin/bash
# Standalone, read-only report: may be copied to another Mac without the bundle.
set -uo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

command_report() {
  local output status=0
  output="$("$@" 2>&1)" || status=$?
  printf '%s\n' "$output"
  if (( status != 0 )); then
    printf 'Query exited with status %s.\n' "$status"
  fi
}

section() { printf '\n--- %s ---\n' "$1"; }

# Preserve errors separately from a successful query with no matching drivers.
filtered_report() {
  local output status=0
  output="$("$@" 2>&1)" || status=$?
  if (( status != 0 )); then
    printf 'Query failed (exit %s):\n%s\n' "$status" "$output"
  elif ! printf '%s\n' "$output" | grep -Ei 'motu|firewire|IOAudioFamily|asfw|asohci'; then
    echo 'Query succeeded; no matching entries.'
  fi
}

report_kext() {
  local bundle="$1" info executable
  info="$bundle/Contents/Info.plist"
  printf '\n%s\n' "$bundle"
  if [[ ! -r "$info" ]]; then
    echo 'Cannot read bundle metadata; this does not establish that it is absent.'
    echo 'If running without sudo, rerun this read-only report with sudo.'
    return 0
  fi
  for key in CFBundleIdentifier CFBundleVersion; do
    printf '%s: ' "$key"
    plutil -extract "$key" raw -o - "$info" 2>&1 || true
  done
  if executable="$(plutil -extract CFBundleExecutable raw -o - "$info" 2>/dev/null)"; then
    if [[ -f "$bundle/Contents/MacOS/$executable" ]]; then
      file "$bundle/Contents/MacOS/$executable"
      shasum -a 256 "$bundle/Contents/MacOS/$executable"
    else
      echo 'No loose executable here; check kernel-collection entries above.'
    fi
  fi
  if [[ "$bundle" == *MOTU* ]]; then
    plutil -extract OSBundleLibraries xml1 -o - "$info" 2>&1 || true
    codesign --verify --deep --strict "$bundle" 2>&1 && echo 'Code signature verifies.'
  fi
}

main() {
  [[ "$(uname -s)" == Darwin ]] || { echo 'This report requires macOS.' >&2; return 1; }
  echo 'MOTU / FireWire read-only diagnostic report'
  echo 'No driver is loaded, installed or changed by this script.
Some installed bundles require sudo for inspection; access failures are inconclusive.'
  section 'System (no hardware serial numbers)'
  sw_vers
  sysctl -n hw.model
  uname -m
  csrutil status

  section 'Currently loaded kernel extensions'
  filtered_report kmutil showloaded
  section 'Boot-registered kernel extensions, including unloaded entries'
  filtered_report kmutil showloaded --show all
  section 'Collections selected by kmutil'
  command_report kmutil inspect --show-collection-metadata
  section 'Kernel-collection contents (also includes unloaded extensions)'
  filtered_report kmutil inspect --no-header
  section 'Registered system extensions'
  filtered_report systemextensionsctl list

  section 'Installed MOTU, FireWire and legacy audio kernel bundles'
  local bundle
  while IFS= read -r -d '' bundle; do
    report_kext "$bundle"
  done < <(find /Library/Extensions /System/Library/Extensions -type d \
    \( -iname '*motu*.kext' -o -iname '*firewire*.kext' -o -name IOAudioFamily.kext \) -print0)

  section 'MOTU dependency/loadability diagnostics (no staging)'
  command_report kmutil print-diagnostics --bundle-path /Library/Extensions/MOTUFireWireAudio.kext

  section 'End of report'
  echo 'Empty loaded-driver results alone do not establish incompatibility.'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
