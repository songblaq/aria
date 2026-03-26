#!/usr/bin/env bash
# ARIA Plugin: OpenClaw
# Links OpenClaw's existing infrastructure into ARIA app data
set -euo pipefail

ARIA_HOME="${1:-$HOME/.aria}"
OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"

echo "    [openclaw] Setting up ARIA integration..."

# 1. Register as runtime
cat > "$ARIA_HOME/registry/runtimes/openclaw.json" <<JSON
{
  "id": "openclaw",
  "type": "runtime",
  "name": "OpenClaw",
  "host": "$(hostname -s)",
  "capabilities": ["gateway", "agent-orchestration", "nyx-spawn", "cron-scheduling", "knowledge-store", "khala-publish"],
  "inference": { "primary": "ollama/qwen3.5:35b-a3b" },
  "endpoints": { "gateway": "http://localhost:3377" },
  "status": "active",
  "registered_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
JSON

# 2. Symlink Khala channels
if [[ -d "$OPENCLAW_HOME/clawbus/channels" ]]; then
  ln -sfn "$OPENCLAW_HOME/clawbus/channels" "$ARIA_HOME/khala/channels"
  echo "    [openclaw] Khala channels linked"
fi

# 3. Symlink knowledge DB
if [[ -f "$OPENCLAW_HOME/memory/main.sqlite" ]]; then
  ln -sfn "$OPENCLAW_HOME/memory/main.sqlite" "$ARIA_HOME/knowledge/main.sqlite"
  echo "    [openclaw] Knowledge DB linked"
fi

# 4. Symlink knowledge CLI
if [[ -f "$OPENCLAW_HOME/skills/blaq-knowledge/scripts/oc-knowledge.sh" ]]; then
  ln -sfn "$OPENCLAW_HOME/skills/blaq-knowledge/scripts/oc-knowledge.sh" "$ARIA_HOME/knowledge/lib/oc-knowledge.sh"
  echo "    [openclaw] Knowledge CLI linked"
fi

# 5. Symlink agent cards → nodes
if [[ -d "$OPENCLAW_HOME/clawbus/agent-cards" ]]; then
  for card in "$OPENCLAW_HOME/clawbus/agent-cards/"*.json; do
    [[ -f "$card" ]] || continue
    ln -sfn "$card" "$ARIA_HOME/registry/nodes/$(basename "$card")"
  done
  echo "    [openclaw] Node cards linked"
fi

# 6. Symlink agents
if [[ -d "$OPENCLAW_HOME/kiras/agents" ]]; then
  for agent_dir in "$OPENCLAW_HOME/kiras/agents/"*/; do
    [[ -d "$agent_dir" ]] || continue
    ln -sfn "$agent_dir" "$ARIA_HOME/registry/agents/$(basename "$agent_dir")"
  done
  echo "    [openclaw] Agents linked"
fi

echo "    [openclaw] Integration complete"
