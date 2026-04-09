#!/usr/bin/env bash
# khala doctor — substrate health and contract validation

cmd_doctor() {
  local quiet="0"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --quiet|-q) quiet="1"; shift ;;
      --help|-h) echo "Usage: khala doctor [--quiet]"; return 0 ;;
      *) die "Unknown doctor arg: $1" ;;
    esac
  done

  local errors=0
  local warnings=0

  _check() {
    local label="$1" status="$2" detail="${3:-}"
    case "$status" in
      ok)   [[ "$quiet" == "0" ]] && echo "  ✓ $label" ;;
      warn) [[ "$quiet" == "0" ]] && echo "  ⚠ $label  $detail"; warnings=$((warnings+1)) ;;
      err)  echo "  ✗ $label  $detail"; errors=$((errors+1)) ;;
    esac
    return 0  # ensure set -e doesn't trip on short-circuit && when quiet=1
  }

  [[ "$quiet" == "0" ]] && echo "=== Khala Doctor ($AGENTS_HOME) ==="

  # 1. Substrate root
  if [[ -d "$AGENTS_HOME" ]]; then
    _check "substrate root exists" ok
  else
    _check "substrate root" err "$AGENTS_HOME does not exist (run 'khala init')"
  fi

  # 2. Agents dir
  if [[ -d "$KHALA_AGENTS_DIR" ]]; then
    _check "agents dir" ok
  else
    _check "agents dir" err "$KHALA_AGENTS_DIR missing"
  fi

  # 3. Config
  if [[ -f "$KHALA_CONFIG" ]]; then
    _check "config.json present" ok
    if ! python3 -c "import json; json.load(open('$KHALA_CONFIG'))" 2>/dev/null; then
      _check "config.json valid JSON" err
    fi
  else
    _check "config.json" err "$KHALA_CONFIG missing"
  fi

  # 4. Khala
  if [[ -d "$KHALA_CHANNELS_DIR" ]]; then
    _check "khala channels dir" ok
  else
    _check "khala channels dir" warn "$KHALA_CHANNELS_DIR missing"
  fi

  # 5. owl (formerly agent-brain) — external at ~/.owl/
  if [[ -d "$HOME/.owl" ]]; then
    _check "owl detected (~/.owl/, external)" ok
  fi

  # 6. Charter
  if [[ -f "$KHALA_CHARTER" ]]; then
    _check "AGENTS.md charter" ok
  else
    _check "AGENTS.md charter" warn "missing (run 'khala init')"
  fi

  # 7. Legacy detection
  if [[ -d "$HOME/.aria" && ! -L "$HOME/.aria" && "$AGENTS_HOME" == "$HOME/.agents" && -d "$HOME/.agents/aria" ]]; then
    _check "legacy ~/.aria handling" warn "real directory still present alongside ~/.agents/ — run 'khala migrate'"
  fi

  [[ "$quiet" == "0" ]] && echo ""
  if [[ $errors -gt 0 ]]; then
    [[ "$quiet" == "0" ]] && echo "FAIL: $errors errors, $warnings warnings"
    return 1
  fi
  if [[ $warnings -gt 0 ]]; then
    [[ "$quiet" == "0" ]] && echo "OK with $warnings warnings"
  else
    [[ "$quiet" == "0" ]] && echo "OK"
  fi
  return 0
}
