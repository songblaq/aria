#!/usr/bin/env bash
# Khala Plugin: Claude Code
#
# Registers Claude Code as a runtime in the Khala substrate.
# Optionally installs a skill into ~/.claude/skills/ (Claude Code's native location).
# Does NOT touch ~/.openclaw or any other resident's space.
set -euo pipefail

AGENTS_HOME="${1:-${AGENTS_HOME:-$HOME/.agents}}"
PLUGIN_DIR="$(cd "$(dirname "$0")"; pwd)"
RUNTIME_DIR="$AGENTS_HOME/runtimes/claude-code"

echo "    [claude-code] Registering with Khala substrate..."
mkdir -p "$RUNTIME_DIR"

cat > "$RUNTIME_DIR/runtime.json" <<JSON
{
  "id": "claude-code",
  "type": "cli",
  "name": "Claude Code",
  "enabled": true,
  "host": "$(hostname -s)",
  "capabilities": [
    "code-generation",
    "code-review",
    "orchestration",
    "khala-publish"
  ],
  "inference": { "primary": "anthropic/claude-opus", "local": "ollama/qwen3.5:35b-a3b" },
  "registered_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
JSON

# Register in config.json via khala CLI (idempotent merge)
if [[ -x "$AGENTS_HOME/bin/khala" ]]; then
  "$AGENTS_HOME/bin/khala" runtime register claude-code --from "$RUNTIME_DIR/runtime.json"
elif command -v khala >/dev/null 2>&1; then
  khala runtime register claude-code --from "$RUNTIME_DIR/runtime.json"
else
  echo "    [claude-code] WARNING: khala CLI not found; runtime.json written but not registered"
fi

# Optionally install skill into Claude Code's native skills location
if [[ -d "$HOME/.claude" && -d "$PLUGIN_DIR/skill" ]]; then
  skill_target="$HOME/.claude/skills/khala"
  mkdir -p "$skill_target"
  if ls "$PLUGIN_DIR/skill/"* >/dev/null 2>&1; then
    cp -r "$PLUGIN_DIR/skill/"* "$skill_target/"
    echo "    [claude-code] Skill installed at $skill_target"
  fi
fi

echo "    [claude-code] Registered as runtime in $RUNTIME_DIR"
