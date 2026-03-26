#!/usr/bin/env bash
# aria knowledge — FTS5 knowledge base

cmd_knowledge() {
  local sub="${1:-help}"; shift || true
  [[ -x "$ARIA_KNOWLEDGE_CLI" ]] || die "Knowledge CLI not linked: $ARIA_KNOWLEDGE_CLI"
  case "$sub" in
    search|store|stats|agents) exec "$ARIA_KNOWLEDGE_CLI" "$sub" "$@" ;;
    *) echo "Usage: aria knowledge {search|store|stats|agents}" ;;
  esac
}
