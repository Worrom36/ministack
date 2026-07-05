#!/bin/bash
# Run the NucleusCMS install wizard only (reads nucleuscms/config)
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT_DIR/install.sh" --wizard-only "$@"
