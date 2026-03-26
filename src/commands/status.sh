#!/usr/bin/env bash
# aria status — health check

cmd_status() {
  local json_mode=0
  if [[ "${1:-}" == "--json" ]]; then
    json_mode=1
  fi

  local config_status="MISSING"
  [[ -f "$ARIA_CONFIG" ]] && config_status="OK"

  local knowledge_chunks=0
  if [[ -f "$ARIA_KNOWLEDGE_DB" ]]; then
    local kc
    kc=$(sqlite3 "$ARIA_KNOWLEDGE_DB" "SELECT count(*) FROM chunks" 2>/dev/null || true)
    [[ "$kc" =~ ^[0-9]+$ ]] && knowledge_chunks=$kc
  fi

  local ch_count=0 msg_count=0
  if [[ -d "$ARIA_KHALA_DIR" ]]; then
    for f in "$ARIA_KHALA_DIR"/**/*.jsonl; do
      [[ -f "$f" ]] || continue
      ch_count=$((ch_count + 1))
      msg_count=$((msg_count + $(wc -l < "$f" | tr -d ' ')))
    done
  fi

  local rt_count=0 nd_count=0
  [[ -d "$ARIA_REGISTRY/runtimes" ]] && rt_count=$(find "$ARIA_REGISTRY/runtimes" -maxdepth 1 -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
  [[ -d "$ARIA_REGISTRY/nodes" ]] && nd_count=$(find "$ARIA_REGISTRY/nodes" -maxdepth 1 -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')

  local agent_count=0
  if [[ -d "$ARIA_AGENTS" ]]; then
    for d in "$ARIA_AGENTS"/*/; do
      [[ -f "$d/AGENT.md" ]] && agent_count=$((agent_count + 1))
    done
  fi

  if [[ "$json_mode" -eq 1 ]]; then
    ARIA_JSON_VERSION="$ARIA_VERSION" \
    ARIA_JSON_CONFIG="$config_status" \
    ARIA_JSON_KC="$knowledge_chunks" \
    ARIA_JSON_CH="$ch_count" \
    ARIA_JSON_MSG="$msg_count" \
    ARIA_JSON_RT="$rt_count" \
    ARIA_JSON_ND="$nd_count" \
    ARIA_JSON_AG="$agent_count" \
    python3 <<'PY'
import json, os
print(json.dumps({
    "version": os.environ["ARIA_JSON_VERSION"],
    "config": os.environ["ARIA_JSON_CONFIG"],
    "knowledge_chunks": int(os.environ["ARIA_JSON_KC"]),
    "khala_channels": int(os.environ["ARIA_JSON_CH"]),
    "khala_messages": int(os.environ["ARIA_JSON_MSG"]),
    "runtimes": int(os.environ["ARIA_JSON_RT"]),
    "nodes": int(os.environ["ARIA_JSON_ND"]),
    "agents": int(os.environ["ARIA_JSON_AG"]),
}))
PY
    return 0
  fi

  echo "=== ARIA (Agent-Runtime Integration Architecture) v${ARIA_VERSION} ==="
  echo ""

  [[ -f "$ARIA_CONFIG" ]] && echo "  Config:     OK" || echo "  Config:     MISSING"

  if [[ -f "$ARIA_KNOWLEDGE_DB" ]]; then
    local chunks
    chunks=$(sqlite3 "$ARIA_KNOWLEDGE_DB" "SELECT count(*) FROM chunks" 2>/dev/null || echo "?")
    echo "  Knowledge:  $chunks chunks"
  else
    echo "  Knowledge:  NOT LINKED"
  fi

  if [[ -d "$ARIA_KHALA_DIR" ]]; then
    echo "  Khala:      $ch_count channels, $msg_count messages"
  else
    echo "  Khala:      NOT LINKED"
  fi

  echo "  Runtimes:   $rt_count"
  echo "  Nodes:      $nd_count"

  echo "  Nyx Agents: $agent_count"

  # Inference
  local ollama_url
  ollama_url=$(python3 -c "
import json
c = json.load(open('$ARIA_CONFIG'))
print(c.get('inference',{}).get('primary',{}).get('base_url',''))
" 2>/dev/null)
  if [[ -n "$ollama_url" ]]; then
    echo ""
    echo "--- Inference ---"
    if curl -s --connect-timeout 2 "$ollama_url/" >/dev/null 2>&1; then
      echo "  Ollama:     ONLINE ($ollama_url)"
    else
      echo "  Ollama:     OFFLINE ($ollama_url)"
    fi
  fi
}
