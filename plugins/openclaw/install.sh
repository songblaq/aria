#!/usr/bin/env bash
# Khala Plugin: OpenClaw
#
# Registers OpenClaw as a runtime in the Khala substrate.
# Does NOT write to ~/.openclaw or any other resident's space.
#
# OpenClaw publishes directly to ~/.agents/khala/channels/ via its own clawbus
# code; no symlink bridge needed.
set -euo pipefail

AGENTS_HOME="${1:-${AGENTS_HOME:-$HOME/.agents}}"
OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
RUNTIME_DIR="$AGENTS_HOME/runtimes/openclaw"

echo "    [openclaw] Registering with Khala substrate..."
mkdir -p "$RUNTIME_DIR"

cat > "$RUNTIME_DIR/runtime.json" <<JSON
{
  "id": "openclaw",
  "type": "gateway",
  "name": "OpenClaw",
  "enabled": true,
  "host": "$(hostname -s)",
  "capabilities": [
    "gateway",
    "agent-orchestration",
    "cron-scheduling",
    "knowledge-store",
    "khala-publish"
  ],
  "inference": { "primary": "ollama/qwen3.5:35b-a3b" },
  "endpoints": { "gateway": "http://localhost:3377" },
  "workspace": "$OPENCLAW_HOME/workspace",
  "registered_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
JSON

# Register in config.json via khala CLI (idempotent merge)
if [[ -x "$AGENTS_HOME/bin/khala" ]]; then
  "$AGENTS_HOME/bin/khala" runtime register openclaw --from "$RUNTIME_DIR/runtime.json"
elif command -v khala >/dev/null 2>&1; then
  khala runtime register openclaw --from "$RUNTIME_DIR/runtime.json"
else
  echo "    [openclaw] WARNING: khala CLI not found; runtime.json written but not registered in config.json"
fi

echo "    [openclaw] Registered as runtime in $RUNTIME_DIR"
