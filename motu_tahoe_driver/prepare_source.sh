#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_dir="${1:-"${script_dir}/build/ASFireWire"}"
base_commit="ac8a124a683d2f8201cd14ee0d2de8265e4834f0"
patch_file="${script_dir}/patches/0001-add-original-motu-ultralite-audio-support.patch"
patch_sha="ab2be05d8d3c5a88d7a5b9906e8e382103e02ea4dc403dc91ff416ca7eeecd9d"

for command_name in git shasum; do
    command -v "${command_name}" >/dev/null 2>&1 || {
        printf 'Missing required command: %s\n' "${command_name}" >&2
        exit 127
    }
done

actual_sha="$(shasum -a 256 "${patch_file}" | awk '{print $1}')"
if [[ "${actual_sha}" != "${patch_sha}" ]]; then
    printf 'Patch checksum mismatch: expected %s, got %s\n' "${patch_sha}" "${actual_sha}" >&2
    exit 1
fi

if [[ -e "${source_dir}" ]]; then
    printf 'Source destination already exists: %s\n' "${source_dir}" >&2
    printf 'Choose an empty destination as the first argument.\n' >&2
    exit 1
fi

mkdir -p "$(dirname "${source_dir}")"
git clone https://github.com/mrmidi/ASFireWire.git "${source_dir}"
git -C "${source_dir}" checkout --detach "${base_commit}"
git -C "${source_dir}" apply --check "${patch_file}"
git -C "${source_dir}" apply "${patch_file}"

printf 'Prepared UltraLite audio driver source at: %s\n' "${source_dir}"
printf 'Base: %s\n' "${base_commit}"
