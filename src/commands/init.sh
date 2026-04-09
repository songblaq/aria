#!/usr/bin/env bash
# khala init — bootstrap or upgrade the ~/.agents/ substrate (idempotent, reserved-path-safe)

cmd_init() {
  local force="0"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force) force="1"; shift ;;
      --help|-h)
        cat <<'HELP'
Usage: khala init [--force]

  Bootstrap (or upgrade) the agent substrate at $AGENTS_HOME (default ~/.agents).

  Idempotent — safe to re-run. Never touches external tools:
    - ~/.owl/         (owl — LLM Wiki, external)
    - ~/owl-vault/    (owl vault, external)
HELP
        return 0
        ;;
      *) die "Unknown init arg: $1" ;;
    esac
  done

  echo "=== Khala init ==="
  echo "  Substrate:  $AGENTS_HOME"
  echo ""

  # External tool detection (informational only)
  if [[ -d "$HOME/.owl" ]]; then
    echo "  owl/        DETECTED at ~/.owl (external, preserved)"
  fi

  # Create skeleton
  khala_ensure_home

  # Charter
  if [[ ! -f "$KHALA_CHARTER" ]]; then
    _khala_seed_charter
    echo "  Created:     $KHALA_CHARTER"
  fi

  # Config (only if not present)
  if [[ ! -f "$KHALA_CONFIG" ]]; then
    _khala_seed_config
    echo "  Created:     $KHALA_CONFIG"
  fi

  echo ""
  echo "OK. Run 'khala status' to verify."
}

_khala_seed_charter() {
  cat > "$KHALA_CHARTER" <<'CHARTER'
# ~/.agents/ Substrate Charter

This directory is the agent substrate, managed by Agent Khala (the `khala` CLI).

## Layout

```
~/.agents/
├── AGENTS.md          # this charter
├── config.json        # khala-managed substrate config
├── bin/khala          # CLI entry point
│
├── agents/            # installed agent instances (incl. blaq identity)
├── khala/             # messaging substrate (channels + lib)
└── skills/            # shared canonical skill library
```

## Reserved-Path Contract

| Path                 | Owner      | Description                                 |
|----------------------|------------|---------------------------------------------|
| `agents/`            | khala      | Installed agent definitions and memory      |
| `khala/`             | khala      | JSONL append-only messaging channels        |
| `skills/`            | shared     | Canonical skill library, prefix-disciplined |
| `bin/khala`          | khala      | CLI executable (symlink to project)         |
| `config.json`        | khala      | Substrate configuration                     |
| `AGENTS.md`          | khala      | This file                                   |

## External (not in substrate)

These tools live outside `~/.agents/` but are part of the broader agent ecosystem:

- **owl** (`~/.owl/` + `~/owl-vault/`) — LLM-maintained personal Wiki (formerly agent-brain).
  Implements Karpathy's LLM Wiki pattern. Knowledge layer for the agent ecosystem.

## Runtime cohabitation

Other AI runtimes (OpenClaw, Claude Code, Codex, etc.) publish to `khala/channels/`
directly using their own libraries. Khala provides the channel format and tooling;
runtimes are free to write/read without going through the `khala` CLI.

## CLI

```
khala status                # health check
khala doctor                # validate this contract
khala substrate info        # show residents + external tools
khala substrate charter     # print this file
```
CHARTER
}

_khala_seed_config() {
  mkdir -p "$(dirname "$KHALA_CONFIG")"
  cat > "$KHALA_CONFIG" <<CONF
{
  "version": "3.2.0",
  "name": "Agent Khala",
  "short": "Khala",
  "home": "~/.agents",
  "substrate": {
    "home": "~/.agents",
    "charter": "~/.agents/AGENTS.md",
    "residents": {
      "agents": {
        "version": "1.0.0",
        "owns": ["agents/**"],
        "description": "Installed agent instances (incl. blaq identity)"
      },
      "khala": {
        "version": "${KHALA_VERSION}",
        "owns": ["khala/**"],
        "description": "Messaging substrate"
      },
      "skills": {
        "version": "1.0.0",
        "owns": ["skills/**"],
        "description": "Shared skill library"
      }
    },
    "external": {
      "owl": {
        "path": "~/.owl",
        "vault": "~/owl-vault",
        "description": "LLM Wiki (formerly agent-brain), now external",
        "project": "~/_/projects/owl"
      }
    },
    "shared": ["skills", "khala"]
  },
  "khala": {
    "backend": "khala",
    "channels_dir": "~/.agents/khala/channels",
    "lib_dir": "~/.agents/khala/lib",
    "default_ttl": 86400,
    "default_priority": "normal"
  },
  "agents": {
    "agents_dir": "~/.agents/agents",
    "routing": "~/.agents/agents/routing.json",
    "prompts_dir": "~/.agents/agents/prompts",
    "phantoms_dir": "~/.agents/agents/phantoms",
    "teams": "~/.agents/agents/teams/presets.json"
  },
  "runtimes": {},
  "nodes": {},
  "inference": {
    "primary": { "provider": "ollama", "base_url": "http://localhost:11434", "model": "" }
  }
}
CONF
}
