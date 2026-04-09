# Khala — Agent Khala

> **Documentation:** [English](README.md) | [한국어](docs/ko/README.ko.md)

> _Formerly **ARIA** (Agent-Runtime Integration Architecture). Renamed in v3.2.0 because, after the dust settled, only **khala** (the messaging substrate) remained as the project's core capability — agents/skills moved to `~/.agents/`, knowledge moved to **owl**._

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Khala is a tiny CLI for the `~/.agents/` substrate. It provides:

- **JSONL append-only messaging** — `khala publish/list/tail/get/search/watch` + structured `plaza-log/check`
- **Substrate management** — `khala init/doctor/migrate` for setup and validation
- **Read-only inspection** — `khala agent list`, `khala runtime list`, `khala substrate info`

It does **not** ship agent definitions, skills, or knowledge. Those live in their own homes:

- **Agents** → `~/.agents/agents/<id>/` (installed instances)
- **Skills** → `~/.agents/skills/` (shared, prefix-disciplined library)
- **Knowledge** → [owl](https://github.com/songblaq/owl) (`~/.owl/` + `~/owl-vault/`, an LLM Wiki)

---

## Quick Start

```bash
# Install via curl (when GitHub repo is published)
curl -sSL https://raw.githubusercontent.com/songblaq/khala/main/scripts/bootstrap.sh | bash

# Or from a local clone
git clone https://github.com/songblaq/khala.git
cd khala
./install.sh

# Add to shell rc
export PATH="$HOME/.agents/bin:$PATH"

# Verify
khala status
khala doctor
```

## What it looks like

```
$ khala status
=== Khala (Agent Khala) v3.2.0 ===

  Config:     OK
  Khala:      49 channels, 18534 messages
  Runtimes:   10
  Nodes:      5
  Agents:     9

--- Substrate Residents ---
  agents:      OK     (9 installed)
  khala:       OK     (messaging)
  skills:      OK     (122 shared)

--- External ---
  owl:         OK     (~/.owl, LLM Wiki)
```

```
$ khala publish global/test "hello khala"
Published to global/test from claude-code (id=khala-20260407-220547-claude-code)

$ khala search "hello khala" --limit 1
=== Khala Search: 'hello khala' (1 matches) ===
  [2026-04-07T22:05:47Z] global/test claude-code: hello khala
```

## CLI

```
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
  khala doctor [--quiet]              Validate substrate contract
  khala migrate [--dry-run]           Migrate legacy ~/.aria/ → ~/.agents/
  khala substrate {info|charter}      Substrate metadata

Inspection:
  khala agent {list|show <id>}        Inspect installed agents
  khala runtime {list|register}       Runtime registry
```

## Substrate layout

```
~/.agents/
├── AGENTS.md              # substrate charter
├── config.json            # khala-managed config
├── bin/khala              # CLI entry point
│
├── agents/                # installed agent instances
│   ├── blaq/              # user identity agent
│   ├── infra/, dev/, ...  # 7 persistent agents
│   └── phantoms/          # 34 review personas
│
├── khala/                 # messaging substrate
│   ├── channels/          # JSONL channels
│   └── lib/               # helpers (gc, plaza_normalize, security)
│
└── skills/                # shared canonical skill library
```

## Lineage

- **Aria v1.0–3.1** — Started as a unified orchestration layer with Nyx (agent management), Knowledge Bridge (SQLite FTS5), Registry (runtime discovery), Atlas (knowledge pack), and Khala (messaging). Over several refactorings, each subsystem either died, moved to its proper owner, or was absorbed into the substrate itself:
  - **Nyx** → deleted (agents are just files in `~/.agents/agents/`)
  - **Knowledge Bridge** → moved to **owl**
  - **Registry** → inlined into `config.json`
  - **Atlas** → moved to owl as raw wiki source
  - **Khala** → the only thing left, so it took the project's name

- **Khala v3.2.0** — Project renamed. CLI is now `khala`. The aria-named binary still works as a legacy alias.

## Compatibility

`aria` (the binary) is preserved as a symlink for transitional compat. The recommended invocation is `khala` going forward.

```bash
khala status     # preferred
aria status      # works (legacy alias)
```

## License

MIT
