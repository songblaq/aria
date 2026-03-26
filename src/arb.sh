#!/usr/bin/env bash
# Legacy CLI entrypoint: delegates to aria (same as ~/.aria/bin/arb → aria symlink)
set -euo pipefail

ARIA_SRC="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"; pwd)"
exec "$ARIA_SRC/aria.sh" "$@"
