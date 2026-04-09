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
