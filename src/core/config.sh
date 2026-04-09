#!/usr/bin/env bash
# Khala Core — substrate paths, constants, helpers
#
# As of v3.2.0, this CLI is named "khala". The project was renamed from Aria
# to Agent Khala because khala (messaging) is the only core capability that
# remained after agents/skills/owl moved out into their own homes.
#
# Substrate layout (~/.agents/):
# - Substrate root:    $AGENTS_HOME (default: ~/.agents)
# - Installed agents:  $AGENTS_HOME/agents/     (persistent + phantoms + blaq identity)
# - Khala messaging:   $AGENTS_HOME/khala/      (shared, khala-provided)
# - Shared skills:     $AGENTS_HOME/skills/     (shared)
# - Config:            $AGENTS_HOME/config.json
# - Charter:           $AGENTS_HOME/AGENTS.md
#
# External (no longer in substrate):
# - owl (formerly agent-brain): ~/.owl/ + ~/owl-vault/  (Karpathy LLM Wiki)

# Substrate root resolution (in priority order):
#   1. $AGENTS_HOME explicit
#   2. $ARIA_HOME explicit (legacy env input, still honored)
#   3. ~/.agents if it has the post-migration layout (~/.agents/config.json exists)
#   4. ~/.aria if legacy layout still in place (pre-v3 installs)
#   5. default to ~/.agents
khala_resolve_home() {
  if [[ -n "${AGENTS_HOME:-}" ]]; then
    printf '%s\n' "$AGENTS_HOME"; return
  fi
  if [[ -n "${ARIA_HOME:-}" ]]; then
    printf '%s\n' "$ARIA_HOME"; return
  fi
  if [[ -f "$HOME/.agents/config.json" ]]; then
    printf '%s\n' "$HOME/.agents"; return
  fi
  if [[ -d "$HOME/.agents/aria" ]]; then
    # Pre-v3.1 transitional layout
    printf '%s\n' "$HOME/.agents"; return
  fi
  if [[ -d "$HOME/.aria" && ! -L "$HOME/.aria" ]]; then
    printf '%s\n' "$HOME/.aria"; return
  fi
  printf '%s\n' "$HOME/.agents"
}

AGENTS_HOME="$(khala_resolve_home)"

# Substrate layout detection:
# - Flat layout (v3.1+):   config.json at root
# - Nested layout (v3.0):  aria/config.json
# - Legacy layout (<v3):   config.json at root (but ~/.aria base)
if [[ -f "$AGENTS_HOME/config.json" ]]; then
  KHALA_CONFIG="$AGENTS_HOME/config.json"
  KHALA_AGENTS_DIR="$AGENTS_HOME/agents"
elif [[ -d "$AGENTS_HOME/aria" ]]; then
  # Transitional nested layout
  KHALA_CONFIG="$AGENTS_HOME/aria/config.json"
  KHALA_AGENTS_DIR="$AGENTS_HOME/aria/agents"
else
  KHALA_CONFIG="$AGENTS_HOME/config.json"
  KHALA_AGENTS_DIR="$AGENTS_HOME/agents"
fi

# Blaq (user identity) is a regular agent under agents/blaq/
KHALA_BLAQ_DIR="$KHALA_AGENTS_DIR/blaq"
KHALA_BLAQ_SOUL="$KHALA_AGENTS_DIR/blaq/profile/SOUL.md"
KHALA_BLAQ_USER="$KHALA_AGENTS_DIR/blaq/profile/USER.md"

KHALA_PHANTOMS_DIR="$KHALA_AGENTS_DIR/phantoms"
KHALA_TEAMS_DIR="$KHALA_AGENTS_DIR/teams"
KHALA_PROMPTS_DIR="$KHALA_AGENTS_DIR/prompts"

# Shared substrate primitives (top-level, always same path)
KHALA_CHANNELS_DIR="$AGENTS_HOME/khala/channels"
KHALA_LIB_DIR="$AGENTS_HOME/khala/lib"
KHALA_SKILLS_DIR="$AGENTS_HOME/skills"

# Substrate metadata
KHALA_CHARTER="$AGENTS_HOME/AGENTS.md"

khala_detect_runtime() {
  if [[ -n "${KHALA_RUNTIME:-}" ]]; then
    printf '%s\n' "$KHALA_RUNTIME"
    return
  fi
  if [[ -n "${ARIA_RUNTIME:-}" ]]; then
    # Legacy env input
    printf '%s\n' "$ARIA_RUNTIME"
    return
  fi

  case "${__CFBundleIdentifier:-}" in
    com.openai.codex)
      printf '%s\n' "codex"
      return
      ;;
    com.anthropic.claudefordesktop)
      printf '%s\n' "claude-app"
      return
      ;;
  esac

  if [[ -n "${CODEX_THREAD_ID:-}" || -n "${CODEX_SHELL:-}" || -n "${CODEX_INTERNAL_ORIGINATOR_OVERRIDE:-}" ]]; then
    printf '%s\n' "codex"
    return
  fi

  printf '%s\n' "claude-code"
}

KHALA_RUNTIME="$(khala_detect_runtime)"
KHALA_VERSION="3.2.0"

die() { echo "ERROR: $*" >&2; exit 1; }

# Idempotent skeleton creation. Never touches reserved paths (brain, first-principles).
khala_ensure_home() {
  mkdir -p "$AGENTS_HOME"/{bin,agents/{prompts,phantoms,teams,templates},khala/{channels/global,lib},skills}
}

khala_json_field() {
  local file="$1" field="$2"
  python3 -c "import json; print(json.load(open('$file')).get('$field',''))" 2>/dev/null
}
