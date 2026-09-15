#!/bin/bash
# Regression tests execute functions in isolated shells and mock system writes.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="$REPO/motu_ultralite_firewire_bundle/install_motu_ultralite_firewire.sh"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
export INSTALLER

run_case() {
  local name="$1" expected="$2" status=0
  { printf 'source "$INSTALLER"\n'; cat; } > "$TEST_DIR/case.sh"
  /bin/bash "$TEST_DIR/case.sh" > "$TEST_DIR/output" 2>&1 || status=$?
  if [[ "$status" -ne "$expected" ]]; then
    cat "$TEST_DIR/output"
    echo "FAIL: $name (expected $expected, got $status)" >&2
    exit 1
  fi
  echo "PASS: $name"
}

run_case 'Tahoe stops before payload, sudo or copying' 1 <<'CASE'
uname() { echo Darwin; }
sw_vers() { echo 26.6.2; }
kmutil() { echo "Extension Information:"; }
check_payload() { exit 91; }
require_root() { exit 92; }
install_item() { exit 93; }
main
CASE

run_case 'Unsupported older macOS stops before writes' 1 <<'CASE'
uname() { echo Darwin; }
sw_vers() { echo 10.15.7; }
check_payload() { exit 91; }
require_root() { exit 92; }
main
CASE

run_case 'Read-only mode never escalates' 0 <<'CASE'
uname() { echo Darwin; }
sw_vers() { echo 15.7; }
check_payload() { :; }
require_root() { exit 92; }
new_backup() { exit 93; }
main --check
CASE

run_case 'Invalid signature blocks installation' 1 <<'CASE'
check_platform() { :; }
codesign() { return 1; }
require_root() { exit 92; }
main
CASE

run_case 'Gatekeeper rejection blocks installation' 1 <<'CASE'
check_platform() { :; }
codesign() { return 0; }
spctl() { return 1; }
require_root() { exit 92; }
main
CASE

run_case 'Missing payload blocks installation' 1 <<'CASE'
check_platform() { :; }
SCRIPT_DIR=/nonexistent-motu-test-payload
require_root() { exit 92; }
main
CASE

run_case 'Rosetta still requires arm64e kext' 0 <<'CASE'
verify_code() { :; }
sysctl() { echo 1; }
lipo() { [[ "$2" == -verify_arch && "$3" == arm64e ]]; }
check_payload
CASE

run_case 'Kernel activation failure propagates through main' 1 <<'CASE'
check_platform() { :; }
check_payload() { :; }
require_root() { :; }
new_backup() { :; }
install_item() { :; }
kmutil() { echo 'Simulated kernelmanagerd rejection' >&2; return 27; }
main
CASE
if /usr/bin/grep -q 'Install complete' "$TEST_DIR/output"; then
  echo 'FAIL: false success after activation failure' >&2
  exit 1
fi

run_case 'Only the selected kext is requested' 0 <<'CASE'
kmutil() {
  [[ "$#" == 3 && "$1" == load && "$2" == --bundle-path &&
     "$3" == /Library/Extensions/MOTUFireWireAudio.kext ]]
}
request_driver_load
CASE

run_case 'Unknown argument never installs' 2 <<'CASE'
require_root() { exit 92; }
main --force
CASE

run_case 'Tahoe with an existing FireWire stack is not rejected by version alone' 0 <<'CASE'
uname() { echo Darwin; }
sw_vers() { echo 26.6.2; }
kmutil() { echo 'com.apple.iokit.IOFireWireFamily (4.8.3)'; }
check_payload() { :; }
require_root() { exit 92; }
main --check
CASE

run_case 'Failed inspection cannot establish FireWire support' 1 <<'CASE'
kmutil() { echo 'Failed to inspect com.apple.iokit.IOFireWireFamily'; return 1; }
firewire_stack_present
CASE

run_case 'Failed staging copy never replaces the installed item' 1 <<'CASE'
mkdir() { :; }
mktemp() { echo /unused-motu-test-stage; }
ditto() { return 1; }
rm() { :; }
mv() { exit 94; }
install_item dev/null
CASE

run_case 'Changed startup jobs are left alone' 0 <<'CASE'
STARTUP_ITEMS=(dev/null)
new_backup() { :; }
stat() { echo 501; }
cmp() { return 1; }
mv() { exit 94; }
launchctl() { exit 95; }
disable_autostart
CASE


run_case 'Stored FireWire support is found even if no device is connected' 0 <<'CASE'
kmutil() {
  if [[ "$1" == showloaded ]]; then
    echo 'No matching loaded drivers'
  elif [[ "$#" == 2 && "$1" == inspect && "$2" == --no-header ]]; then
    echo 'com.apple.iokit.IOFireWireFamily 4.8.3'
  else
    return 1
  fi
}
firewire_stack_present
CASE

run_case 'Diagnostics distinguish query failure from no matches' 0 <<'CASE'
source "$SCRIPT_DIR/diagnose_motu.sh"
empty_query() { echo 'Unrelated driver'; }
failed_query() { echo 'Inspection unavailable' >&2; return 7; }
[[ "$(filtered_report empty_query)" == 'Query succeeded; no matching entries.' ]]
[[ "$(filtered_report failed_query)" == *'Query failed (exit 7)'* ]]
CASE
