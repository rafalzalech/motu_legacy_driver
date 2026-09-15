#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/Install My MOTU UltraLite Build.command" ]]; then
  exec /bin/bash "$SCRIPT_DIR/Install My MOTU UltraLite Build.command" --verify
fi
exec /bin/bash "$SCRIPT_DIR/install_motu_ultralite_tahoe.sh" --verify
