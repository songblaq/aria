#!/usr/bin/env bash
# khala — Agent Khala CLI (formerly Aria)
# https://github.com/songblaq/khala
#
# Khala is the messaging substrate + thin tooling for the ~/.agents/ namespace.
# It provides:
#   - JSONL append-only messaging (publish, list, tail, get, search, watch, plaza-*)
#   - Substrate bootstrap (init, doctor, migrate)
#   - Read-only inspection (agent, runtime, substrate, status)
set -euo pipefail

# Resolve project root (works from symlink too)
KHALA_SRC="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")"; pwd)"

# Source core + commands
source "$KHALA_SRC/core/config.sh"
source "$KHALA_SRC/commands/status.sh"
source "$KHALA_SRC/commands/khala.sh"
source "$KHALA_SRC/commands/init.sh"
source "$KHALA_SRC/commands/doctor.sh"
source "$KHALA_SRC/commands/migrate.sh"
source "$KHALA_SRC/commands/agent.sh"
source "$KHALA_SRC/commands/runtime.sh"
source "$KHALA_SRC/commands/substrate.sh"

cmd="${1:-help}"; shift || true

case "$cmd" in
  # ─── Messaging (flat — no more "khala publish" prefix) ────────────
  publish)     _khala_publish "$@" ;;
  list)        _khala_list "$@" ;;
  tail)        _khala_tail "$@" ;;
  get)         _khala_get "$@" ;;
  search)      _khala_search "$@" ;;
  watch)       _khala_watch "$@" ;;
  plaza-log)   _khala_plaza_log "$@" ;;
  plaza-check) _khala_plaza_check "$@" ;;

  # ─── Substrate management ─────────────────────────────────────────
  status)     cmd_status "$@" ;;
  init)       cmd_init "$@" ;;
  doctor)     cmd_doctor "$@" ;;
  migrate)    cmd_migrate "$@" ;;
  agent)      cmd_agent "$@" ;;
  runtime)    cmd_runtime "$@" ;;
  substrate)  cmd_substrate "$@" ;;

  # ─── UI ──────────────────────────────────────────────────────────
  tui)        python3 "$AGENTS_HOME/scripts/tui.py" "$@" 2>/dev/null || die "tui not available" ;;
  web)        bash "$AGENTS_HOME/scripts/web-start.sh" "$@" 2>/dev/null || die "web not available" ;;

  # ─── Misc ────────────────────────────────────────────────────────
  version)    echo "khala v${KHALA_VERSION}" ;;

  # ─── Backward compat ─────────────────────────────────────────────
  khala)      cmd_khala "$@" ;;     # legacy: `khala khala publish` → `khala publish`
  bus)        cmd_khala "$@" ;;     # very legacy alias from arb era
  aria)       echo "ERROR: 'aria' subcommand removed. Use 'khala' directly." >&2; exit 1 ;;

  help|--help|-h)
    cat <<'HELP'
Khala — Agent Khala CLI

Messaging:
  khala publish <ch> <msg>            Publish message to channel
  khala list [--json]                 List all channels
  khala tail <ch> [-n N] [--json]     Show last N messages
  khala get <ch> <id> [--json]        Fetch message by id
  khala search <pattern> [opts]       Full-text search across channels
  khala watch <ch> [--json]           Live tail (Ctrl+C to stop)
  khala plaza-log [opts]              Structured Plaza work log
  khala plaza-check [opts]            Query Plaza records

Substrate management:
  khala init                          Bootstrap or upgrade ~/.agents/ substrate
  khala status                        Health check
  khala doctor [--quiet]              Validate substrate contract & schema
  khala migrate [--dry-run]           Migrate legacy ~/.aria/ → ~/.agents/
  khala substrate {info|charter}      Show substrate metadata

Read-only inspection:
  khala agent {list|show <id>}        Inspect installed agents
  khala runtime {list|register|enable|disable}   Runtime registry

Misc:
  khala version
  khala help

Run any subcommand with --help for details.
HELP
    ;;
  *) die "Unknown: $cmd (try: khala help)" ;;
esac
