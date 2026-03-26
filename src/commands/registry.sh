#!/usr/bin/env bash
# aria registry — runtimes, nodes, agents

cmd_registry() {
  local sub="${1:-help}"; shift || true
  case "$sub" in
    runtimes) _reg_runtimes ;;
    nodes)    _reg_nodes ;;
    agents)   _reg_agents ;;
    info)     _reg_info "$@" ;;
    *)        echo "Usage: aria registry {runtimes|nodes|agents|info <id>}" ;;
  esac
}

_reg_runtimes() {
  echo "=== Runtimes ==="
  for f in "$ARIA_REGISTRY/runtimes/"*.json; do
    [[ -f "$f" ]] || continue
    python3 -c "
import json
d = json.load(open('$f'))
print(f\"  {d.get('id','?'):20s} {d.get('name','?'):35s} {d.get('status','?')}\")" 2>/dev/null
  done
}

_reg_nodes() {
  echo "=== Nodes ==="
  for f in "$ARIA_REGISTRY/nodes/"*.json; do
    [[ -f "$f" ]] || continue
    local name; name=$(basename "$f" .json)
    local label; label=$(python3 -c "import json; print(json.load(open('$f')).get('name','?'))" 2>/dev/null || echo "?")
    printf "  %-20s %s\n" "$name" "$label"
  done
}

_reg_agents() {
  echo "=== Agents ==="
  for dir in "$ARIA_REGISTRY/agents/"*/; do
    [[ -d "$dir" ]] || continue
    local id; id=$(basename "$dir")
    local mem="N"; [[ -f "$dir/memory/context.md" ]] && mem="Y"
    printf "  %-24s memory: %s\n" "$id" "$mem"
  done
}

_reg_info() {
  local id="${1:?Usage: aria registry info <id>}"
  for path in "$ARIA_REGISTRY/runtimes/$id.json" "$ARIA_REGISTRY/nodes/$id.json"; do
    if [[ -f "$path" ]]; then
      python3 -c "import json; print(json.dumps(json.load(open('$path')), indent=2, ensure_ascii=False))"
      return
    fi
  done
  if [[ -d "$ARIA_REGISTRY/agents/$id" ]]; then
    [[ -f "$ARIA_REGISTRY/agents/$id/AGENT.md" ]] && head -20 "$ARIA_REGISTRY/agents/$id/AGENT.md"
    [[ -f "$ARIA_REGISTRY/agents/$id/memory/context.md" ]] && echo "" && cat "$ARIA_REGISTRY/agents/$id/memory/context.md"
    return
  fi
  die "'$id' not found in runtimes, nodes, or agents"
}
