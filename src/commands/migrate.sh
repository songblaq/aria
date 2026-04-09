#!/usr/bin/env bash
# khala migrate — legacy ~/.aria/ → ~/.agents/ migration helper
#
# This command exists only to help users coming from ARIA v1.x/v2.x installs.
# Post v3.1+, the substrate is flat under ~/.agents/ and this command is a no-op
# on already-migrated systems.

cmd_migrate() {
  local subcommand="${1:-run}"; shift || true

  case "$subcommand" in
    run|"")    _migrate_run "$@" ;;
    finalize)  _migrate_finalize ;;
    --dry-run) _migrate_run --dry-run ;;
    --help|-h)
      cat <<'HELP'
Usage:
  khala migrate [--dry-run]   One-shot migration of legacy ~/.aria/ into ~/.agents/
                              (no-op on already-migrated systems)
  khala migrate finalize      Remove the ~/.aria → ~/.agents legacy symlink
                              after several days of stable operation

Notes:
  - Modern installs use ~/.agents/ directly (flat layout). Migration is only
    needed when upgrading from ARIA v1.x or v2.x.
  - This command is intentionally conservative — it refuses to overwrite
    existing ~/.agents/ data.
HELP
      return 0
      ;;
    *)
      die "Unknown migrate subcommand: $subcommand"
      ;;
  esac
}

_migrate_run() {
  local dry_run="0"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) dry_run="1"; shift ;;
      *) die "Unknown migrate arg: $1" ;;
    esac
  done

  local src="$HOME/.aria"
  local dst="$HOME/.agents"

  echo "=== Khala Migration: ~/.aria → ~/.agents ==="
  [[ "$dry_run" == "1" ]] && echo "  MODE: DRY-RUN (no changes)"
  echo ""

  # Pre-checks
  if [[ ! -e "$src" ]]; then
    echo "  Nothing to migrate: ~/.aria does not exist."
    return 0
  fi
  if [[ -L "$src" ]]; then
    echo "  Nothing to migrate: ~/.aria is already a symlink (migration complete)."
    echo "  To finalize and remove the symlink, run: khala migrate finalize"
    return 0
  fi
  if [[ -f "$dst/config.json" ]]; then
    echo "  WARNING: ~/.agents/ already has a substrate (config.json present)."
    echo "  This migration helper refuses to touch existing installs."
    echo "  If you really want to reconcile manually:"
    echo "    1. Back up ~/.aria and ~/.agents"
    echo "    2. Copy the pieces you want into ~/.agents/ manually"
    echo "    3. Remove ~/.aria once satisfied"
    return 1
  fi

  echo "  Legacy ~/.aria detected but ~/.agents/ has no substrate yet."
  echo "  This migration is a one-shot copy."
  echo ""

  # Build plan
  echo "  Migration plan:"
  for item in config.json agents khala skills runtimes atlas logs scripts README.md SOUL.md USER.md; do
    [[ -e "$src/$item" ]] && echo "    $src/$item  →  $dst/$item"
  done
  echo ""

  if [[ "$dry_run" == "1" ]]; then
    echo "  DRY-RUN complete. Re-run without --dry-run to apply."
    return 0
  fi

  read -p "  Proceed with migration? [y/N] " confirm
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "  Aborted."
    return 1
  fi

  echo ""
  echo "  Phase 1: Create ~/.agents/ skeleton"
  mkdir -p "$dst"/{bin,agents/{prompts,phantoms,teams,templates},khala/{channels/global,lib},skills}

  echo "  Phase 2: Move items"
  for item in config.json agents khala skills runtimes atlas logs scripts README.md SOUL.md USER.md; do
    if [[ -e "$src/$item" ]]; then
      if [[ ! -e "$dst/$item" ]]; then
        mv "$src/$item" "$dst/$item" && echo "    moved: $item"
      else
        echo "    SKIP (exists at target): $item"
      fi
    fi
  done

  echo "  Phase 3: Rewrite ~/.aria as symlink → ~/.agents"
  if [[ -d "$src" ]]; then
    local remaining
    remaining=$(find "$src" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$remaining" -gt 0 ]]; then
      echo "    NOTE: $remaining items remain in ~/.aria — renaming to .residue"
      mv "$src" "$src.residue.$(date +%Y%m%d-%H%M%S)"
    else
      rmdir "$src"
    fi
  fi
  ln -sfn "$dst" "$src"
  echo "    ~/.aria → ~/.agents (legacy compat)"

  echo ""
  echo "=== Migration complete ==="
  echo "  Verify with: khala status && khala doctor"
}

_migrate_finalize() {
  local src="$HOME/.aria"
  if [[ ! -L "$src" ]]; then
    die "~/.aria is not a symlink. Refusing to remove."
  fi
  read -p "Remove legacy ~/.aria symlink? [y/N] " confirm
  if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    rm "$src"
    echo "Removed ~/.aria symlink. Migration finalized."
  fi
}
