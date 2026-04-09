#!/usr/bin/env bash
# Khala Bootstrap — Agent Khala curl-piped installer entry point
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/songblaq/khala/main/scripts/bootstrap.sh | bash
#
# Or with override:
#   KHALA_INSTALL_DIR=/custom/path curl ... | bash
#
# What it does:
#   1. Verifies prerequisites (bash, python3, git, curl)
#   2. Clones (or updates) the khala project to $KHALA_INSTALL_DIR
#   3. Executes the project's install.sh in curl mode
set -euo pipefail

KHALA_INSTALL_DIR="${KHALA_INSTALL_DIR:-${ARIA_INSTALL_DIR:-$HOME/.local/share/khala}}"
KHALA_REPO="${KHALA_REPO:-${ARIA_REPO:-https://github.com/songblaq/khala.git}}"
KHALA_BRANCH="${KHALA_BRANCH:-${ARIA_BRANCH:-main}}"

echo "=== Khala Bootstrap (Agent Khala) ==="
echo "  Install dir: $KHALA_INSTALL_DIR"
echo "  Repository:  $KHALA_REPO ($KHALA_BRANCH)"
echo ""

# 1. Preflight
for cmd in bash python3 git curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: required command not found: $cmd" >&2
    exit 1
  fi
done

# 2. Platform check
case "$(uname -s)" in
  Darwin) ;;
  Linux)  ;;
  *)      echo "ERROR: Unsupported platform: $(uname -s)" >&2; exit 1 ;;
esac

# 3. Clone or update
if [[ -d "$KHALA_INSTALL_DIR/.git" ]]; then
  echo "Updating existing checkout..."
  git -C "$KHALA_INSTALL_DIR" fetch origin "$KHALA_BRANCH"
  git -C "$KHALA_INSTALL_DIR" reset --hard "origin/$KHALA_BRANCH"
else
  echo "Cloning fresh..."
  mkdir -p "$(dirname "$KHALA_INSTALL_DIR")"
  git clone --depth 1 --branch "$KHALA_BRANCH" "$KHALA_REPO" "$KHALA_INSTALL_DIR"
fi

# 4. Run installer in curl mode
KHALA_INSTALL_MODE=curl bash "$KHALA_INSTALL_DIR/install.sh"

echo ""
echo "=== Khala bootstrap complete ==="
echo "  Project:   $KHALA_INSTALL_DIR"
echo "  Substrate: ${AGENTS_HOME:-$HOME/.agents}"
echo ""
echo "  Add to your shell rc if not already:"
echo "    export PATH=\"\$HOME/.agents/bin:\$PATH\""
