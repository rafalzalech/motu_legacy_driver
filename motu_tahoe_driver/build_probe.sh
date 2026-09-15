#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_dir="${1:-"${script_dir}/build/ASFireWire"}"

for command_name in cmake git xcodebuild xcodegen; do
    command -v "${command_name}" >/dev/null 2>&1 || {
        printf 'Missing required command: %s\n' "${command_name}" >&2
        exit 127
    }
done

if [[ ! -d "${source_dir}/.git" ]]; then
    "${script_dir}/prepare_source.sh" "${source_dir}"
fi

cd "${source_dir}"
./build.sh --test-only
./build.sh --no-bump --config Release --arch arm64 \
    --set CURRENT_PROJECT_VERSION=12
./sign.sh build/DerivedData/Build/Products/Release/ASFW.app
codesign --verify --deep --strict --verbose=2 \
    build/DerivedData/Build/Products/Release/ASFW.app

printf 'Built and signed UltraLite audio app:\n%s\n' \
    "${source_dir}/build/DerivedData/Build/Products/Release/ASFW.app"
