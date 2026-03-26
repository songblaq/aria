#!/usr/bin/env bash
# aria — Agent-Runtime Integration Architecture CLI
# https://github.com/songblaq/aria
set -euo pipefail

# Resolve project root (works from symlink too)
ARIA_SRC="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"; pwd)"

# Source core + commands
source "$ARIA_SRC/core/config.sh"
source "$ARIA_SRC/commands/status.sh"
source "$ARIA_SRC/commands/khala.sh"
source "$ARIA_SRC/commands/knowledge.sh"
source "$ARIA_SRC/commands/registry.sh"
source "$ARIA_SRC/commands/nyx.sh"

cmd="${1:-help}"; shift || true

case "$cmd" in
  status)     cmd_status "$@" ;;
  khala)      cmd_khala "$@" ;;
  bus)        cmd_khala "$@" ;;   # legacy alias
  nyx)        cmd_nyx "$@" ;;
  knowledge)  cmd_knowledge "$@" ;;
  registry)   cmd_registry "$@" ;;
  tui)        python3 "$ARIA_HOME/web/tui.py" "$@" ;;
  web)        bash "$ARIA_HOME/web/start.sh" "$@" ;;
  version)    echo "aria v${ARIA_VERSION}" ;;
  help|--help|-h)
    cat <<'HELP'
aria — Agent-Runtime Integration Architecture CLI

  aria status [--json]                Health check (JSON with --json)
  aria khala publish <ch> <msg>       Publish to Khala channel
  aria khala list                     List channels
  aria khala tail <ch> [n]            Recent messages
  aria khala plaza-log ...            Structured Plaza work log
  aria khala plaza-check ...          Check recent Plaza records
  aria nyx list                       List Nyx agents
  aria nyx info <id>                  Agent details
  aria nyx archetypes [category]      List review archetypes
  aria nyx teams                      List team presets
  aria knowledge search <q> [limit]   FTS5 search
  aria knowledge store <text>         Store knowledge
  aria knowledge stats                Stats
  aria registry runtimes              List runtimes
  aria registry nodes                 List nodes
  aria tui                             Terminal UI (curses, 3-panel)
  aria web [port]                     Start ARIA Dashboard (default: 7700)
  aria version                        Version
HELP
    ;;
  *) die "Unknown: $cmd (try: aria help)" ;;
esac
