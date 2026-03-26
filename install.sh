#!/usr/bin/env bash
# ARIA Installer — sets up ~/.aria app data + links CLI
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")"; pwd)"
ARIA_HOME="${ARIA_HOME:-$HOME/.aria}"

echo "=== Installing ARIA (Agent-Runtime Integration Architecture) ==="
echo "  Project: $PROJECT_DIR"
echo "  App data: $ARIA_HOME"
echo ""

# ── 1. App data directories ──
echo "[1/6] Creating app data directories..."
mkdir -p "$ARIA_HOME"/{bin,khala/{channels,lib},knowledge/{lib,infra,projects,topics},registry/{runtimes,nodes},agents,nyx/prompts,skills,profiles/archetypes,runtimes/{openclaw/{skills,nyx-adapter},claude-code/skills,codex/skills,cursor/skills}}

# ── 2. Default config (skip if exists) ──
echo "[2/6] Config..."
if [[ ! -f "$ARIA_HOME/config.json" ]]; then
  cat > "$ARIA_HOME/config.json" <<'CONF'
{
  "version": "1.0.0",
  "name": "Agent-Runtime Integration Architecture",
  "short": "ARIA",
  "home": "~/.aria",
  "khala": { "backend": "clawbus", "channels_dir": "~/.aria/khala/channels", "default_ttl": 86400 },
  "knowledge": { "backend": "sqlite-fts5", "db": "~/.aria/knowledge/main.sqlite" },
  "nyx": { "agents_dir": "~/.aria/agents", "prompts_dir": "~/.aria/nyx/prompts", "routing": "~/.aria/nyx/routing.json" },
  "registry": { "runtimes_dir": "~/.aria/registry/runtimes", "nodes_dir": "~/.aria/registry/nodes" },
  "inference": { "primary": { "provider": "ollama", "base_url": "http://localhost:11434", "model": "" } },
  "runtimes": { "openclaw": { "enabled": true }, "claude-code": { "enabled": true }, "codex": { "enabled": false }, "cursor": { "enabled": false } }
}
CONF
  echo "  Created default config"
else
  echo "  Config exists, skipping"
fi

# ── 3. Link CLI ──
echo "[3/6] Linking CLI..."
chmod +x "$PROJECT_DIR/src/aria.sh"
mkdir -p "$ARIA_HOME/bin"
ln -sfn "$PROJECT_DIR/src/aria.sh" "$ARIA_HOME/bin/aria"
echo "  $ARIA_HOME/bin/aria → $PROJECT_DIR/src/aria.sh"

# ── 4. Legacy compat symlinks ──
echo "[4/6] Legacy compatibility..."
# Pre-ARIA app dir name on disk: ~/.arb → ~/.aria
if [[ -d "$HOME/.arb" && ! -L "$HOME/.arb" ]]; then
  echo "  WARNING: ~/.arb is a real directory. Back it up and create symlink manually."
else
  ln -sfn "$ARIA_HOME" "$HOME/.arb" 2>/dev/null && echo "  ~/.arb → ~/.aria" || echo "  ~/.arb symlink skipped"
fi
# Legacy CLI name: bin/arb → bin/aria
ln -sfn "$ARIA_HOME/bin/aria" "$ARIA_HOME/bin/arb" 2>/dev/null && echo "  bin/arb → bin/aria (compatibility)" || true

# ── 5. Install runtime plugins (if requested) ──
echo "[5/7] Plugins..."
for plugin_dir in "$PROJECT_DIR"/plugins/*/; do
  [[ -d "$plugin_dir" ]] || continue
  local_install="$plugin_dir/install.sh"
  if [[ -x "$local_install" ]]; then
    echo "  Installing plugin: $(basename "$plugin_dir")"
    bash "$local_install" "$ARIA_HOME"
  else
    echo "  Skipping $(basename "$plugin_dir") (no install.sh)"
  fi
done

# ── 6. Seed shared portable skills ──
echo "[6/7] Shared portable skills..."
bash "$PROJECT_DIR/scripts/sync-shared-skills.sh"

# ── 7. PATH hint ──
echo "[7/7] PATH setup..."
if echo "$PATH" | grep -q "$ARIA_HOME/bin"; then
  echo "  Already in PATH"
else
  echo "  Add to your shell rc:"
  echo "    export PATH=\"$ARIA_HOME/bin:\$PATH\""
fi

echo ""
echo "=== ARIA installed ==="
echo "  Run: aria status"
echo "  Or:  $ARIA_HOME/bin/aria status"
