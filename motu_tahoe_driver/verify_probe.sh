#!/usr/bin/env bash
set -u

printf '%s\n' '=== macOS ==='
sw_vers
printf '\n%s\n' '=== System Integrity Protection ==='
csrutil status 2>&1
printf '\n%s\n' '=== ASFireWire system extension ==='
systemextensionsctl list 2>&1 | grep -Ei 'ASFW|mrmidi' || printf '%s\n' 'ASFW extension not listed.'
printf '\n%s\n' '=== Thunderbolt FireWire adapter ==='
system_profiler SPThunderboltDataType 2>/dev/null | \
    grep -A18 -B2 'Thunderbolt to FireWire Adapter' || \
    printf '%s\n' 'Thunderbolt to FireWire Adapter not found.'
printf '\n%s\n' '=== Recent UltraLite/ASFW driver messages ==='
log show --last 15m --style compact \
    --predicate 'process == "net.mrmidi.ASFW.ASFWDriver" OR eventMessage CONTAINS[c] "MotuV2Protocol" OR eventMessage CONTAINS[c] "Device Discovered"' \
    2>/dev/null | tail -200

printf '\n%s\n' '=== ASFW internal discovery and MOTU log ==='
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
probe_tool="$(mktemp /tmp/asfw-probe-dump.XXXXXX)"
if xcrun swiftc "${script_dir}/asfw_probe_dump.swift" \
    -framework IOKit -o "${probe_tool}"; then
    if codesign --force --sign - --timestamp=none \
        --entitlements "${script_dir}/ASFWProbe.entitlements" \
        "${probe_tool}" >/dev/null; then
        "${probe_tool}"
    fi
fi
rm -f "${probe_tool}"
