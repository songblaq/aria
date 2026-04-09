#!/usr/bin/env bash
# Khala Installer — Agent Khala (formerly Aria)
# Sets up the ~/.agents/ substrate and installs the khala CLI.
# Idempotent: safe to re-run for upgrades. Never touches reserved paths.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")"; pwd)"
AGENTS_HOME="${AGENTS_HOME:-${ARIA_HOME:-$HOME/.agents}}"
KHALA_INSTALL_MODE="${KHALA_INSTALL_MODE:-${ARIA_INSTALL_MODE:-local}}"

echo "=== Installing Agent Khala ==="
echo "  Project:   $PROJECT_DIR"
echo "  Substrate: $AGENTS_HOME"
echo "  Mode:      $KHALA_INSTALL_MODE"
echo ""

# ── 0. Preflight ──────────────────────────────────────────────────────────
echo "[1/8] Preflight..."
for cmd in python3 git curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "  ERROR: required command not found: $cmd" >&2
    exit 1
  fi
done
echo "  python3: $(python3 --version 2>&1)"
echo "  bash:    $BASH_VERSION"

# ── 1. External tool detection ────────────────────────────────────────────
echo "[2/8] External tools..."
if [[ -d "$HOME/.owl" ]]; then
  echo "  ✓ owl detected at ~/.owl/ (external, knowledge layer)"
fi
if [[ -d "$HOME/.aria" && ! -L "$HOME/.aria" && ! -f "$AGENTS_HOME/config.json" ]]; then
  echo "  ⚠ Legacy ~/.aria detected. Run 'khala migrate' after installation."
fi

# ── 2. Substrate skeleton (additive only, idempotent) ────────────────────
echo "[3/8] Creating substrate skeleton..."
mkdir -p "$AGENTS_HOME"/{bin,agents/{prompts,phantoms,teams,templates},khala/{channels/global,lib},skills}
echo "  $AGENTS_HOME (flat layout)"

# ── 3. Charter & config (skip if exists) ─────────────────────────────────
echo "[4/8] Charter & config..."
if [[ ! -f "$AGENTS_HOME/AGENTS.md" ]]; then
  if [[ -f "$PROJECT_DIR/templates/AGENTS.md" ]]; then
    cp "$PROJECT_DIR/templates/AGENTS.md" "$AGENTS_HOME/AGENTS.md"
    echo "  Created: AGENTS.md (charter)"
  fi
else
  echo "  AGENTS.md exists, preserved"
fi

if [[ ! -f "$AGENTS_HOME/config.json" ]]; then
  if [[ -f "$PROJECT_DIR/templates/khala-config-v3.json" ]]; then
    cp "$PROJECT_DIR/templates/khala-config-v3.json" "$AGENTS_HOME/config.json"
    echo "  Created: config.json"
  fi
else
  echo "  config.json exists, preserved"
fi

# ── 4. Link CLI ──────────────────────────────────────────────────────────
echo "[5/8] Linking CLI..."
chmod +x "$PROJECT_DIR/src/khala.sh"
ln -sfn "$PROJECT_DIR/src/khala.sh" "$AGENTS_HOME/bin/khala"
ln -sfn "$PROJECT_DIR/src/khala.sh" "$AGENTS_HOME/bin/aria"  # legacy alias
echo "  $AGENTS_HOME/bin/khala → $PROJECT_DIR/src/khala.sh"
echo "  $AGENTS_HOME/bin/aria  → (legacy alias)"

# ── 5. Khala helpers (copy from project, preserve existing) ──────────────
echo "[6/8] Khala helpers..."
if [[ -d "$PROJECT_DIR/templates/khala-lib" ]]; then
  cp -an "$PROJECT_DIR/templates/khala-lib/." "$AGENTS_HOME/khala/lib/"
  echo "  Helpers copied to khala/lib/"
else
  echo "  No khala-lib templates (skipping)"
fi

# ── 6. Plugins ───────────────────────────────────────────────────────────
# Export AGENTS_HOME so plugin install scripts and the khala CLI they invoke
# resolve to the correct substrate (not whatever the user's env defaults to).
export AGENTS_HOME
echo "[7/8] Plugins..."
for plugin_dir in "$PROJECT_DIR"/plugins/*/; do
  [[ -d "$plugin_dir" ]] || continue
  local_install="$plugin_dir/install.sh"
  if [[ -x "$local_install" ]]; then
    echo "  Installing: $(basename "$plugin_dir")"
    AGENTS_HOME="$AGENTS_HOME" bash "$local_install" "$AGENTS_HOME" || echo "    (plugin returned non-zero, continuing)"
  fi
done

# ── 7. Verification + PATH hint ──────────────────────────────────────────
echo "[8/8] Verification..."
if "$AGENTS_HOME/bin/khala" doctor --quiet 2>/dev/null; then
  echo "  doctor: OK"
else
  echo "  doctor: warnings (run 'khala doctor' for details)"
fi

echo ""
if echo "$PATH" | grep -q "$AGENTS_HOME/bin"; then
  echo "  PATH: $AGENTS_HOME/bin already on PATH"
else
  echo "  Add to your shell rc:"
  echo "    export PATH=\"$AGENTS_HOME/bin:\$PATH\""
fi

echo ""
echo "=== Agent Khala installed ==="
echo "  Run: khala status"
echo "  Or:  $AGENTS_HOME/bin/khala status"
