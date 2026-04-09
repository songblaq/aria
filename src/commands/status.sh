#!/usr/bin/env bash
# khala status — health check

cmd_status() {
  echo "=== Khala (Agent Khala) v${KHALA_VERSION} ==="
  echo ""

  if [[ ! -f "$KHALA_CONFIG" ]]; then
    echo "  Config:     MISSING"
    return
  fi
  echo "  Config:     OK"

  # Khala stats — use find (the bash glob ** without globstar misses nested channels)
  if [[ -d "$KHALA_CHANNELS_DIR" ]]; then
    local khala_stats
    khala_stats=$(python3 - "$KHALA_CHANNELS_DIR" <<'PY'
import sys
from pathlib import Path
khala_dir = Path(sys.argv[1])
ch_count = 0
msg_count = 0
for f in khala_dir.rglob("*.jsonl"):
    ch_count += 1
    try:
        with open(f, "rb") as fh:
            msg_count += sum(1 for _ in fh)
    except OSError:
        pass
print(f"{ch_count} {msg_count}")
PY
)
    local ch_count msg_count
    read -r ch_count msg_count <<< "$khala_stats"
    echo "  Khala:      $ch_count channels, $msg_count messages"
  else
    echo "  Khala:      NOT LINKED"
  fi

  # Runtimes & Nodes (from config.json)
  local rt_count nd_count
  rt_count=$(python3 -c "import json; c=json.load(open('$KHALA_CONFIG')); print(len(c.get('runtimes',{})))" 2>/dev/null || echo "0")
  nd_count=$(python3 -c "import json; c=json.load(open('$KHALA_CONFIG')); print(len(c.get('nodes',{})))" 2>/dev/null || echo "0")
  echo "  Runtimes:   $rt_count"
  echo "  Nodes:      $nd_count"

  # Agents
  local agent_count=0
  if [[ -d "$KHALA_AGENTS_DIR" ]]; then
    for d in "$KHALA_AGENTS_DIR"/*/; do
      [[ -f "$d/AGENT.md" ]] && agent_count=$((agent_count + 1))
    done
  fi
  echo "  Agents:     $agent_count"

  # Substrate residents
  if [[ -d "$AGENTS_HOME" && "$AGENTS_HOME" == "$HOME/.agents" ]]; then
    echo ""
    echo "--- Substrate Residents ---"
    if [[ -d "$AGENTS_HOME/agents" ]]; then
      local ag_count=0
      for d in "$AGENTS_HOME/agents"/*/; do
        [[ -f "$d/AGENT.md" ]] && ag_count=$((ag_count + 1))
      done
      echo "  agents:      OK     ($ag_count installed)"
    fi
    if [[ -d "$AGENTS_HOME/khala/channels" ]]; then
      echo "  khala:       OK     (messaging)"
    fi
    if [[ -d "$AGENTS_HOME/skills" ]]; then
      local sk_count
      sk_count=$(ls "$AGENTS_HOME/skills" 2>/dev/null | wc -l | tr -d ' ')
      echo "  skills:      OK     ($sk_count shared)"
    fi
  fi

  # External tools (not substrate residents)
  if [[ -d "$HOME/.owl" ]]; then
    echo ""
    echo "--- External ---"
    echo "  owl:         OK     (~/.owl, LLM Wiki)"
  fi

  # Inference
  local ollama_url
  ollama_url=$(python3 -c "
import json
c = json.load(open('$KHALA_CONFIG'))
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
