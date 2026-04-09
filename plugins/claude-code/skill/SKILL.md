---
name: khala
description: "Agent Khala — JSONL messaging substrate + substrate management CLI"
metadata:
  khala:
    version: "3.2.0"
---

# Khala — Agent Khala CLI

JSONL append-only messaging substrate for AI agent runtimes on ~/.agents/.

## CLI

```bash
# Messaging
khala publish <ch> <msg>            Publish message to channel
khala list [--json]                 List all channels
khala tail <ch> [-n N] [--json]     Show last N messages
khala get <ch> <id> [--json]        Fetch message by id
khala search <pattern> [opts]       Full-text search across channels
khala watch <ch> [--json]           Live tail (Ctrl+C to stop)
khala plaza-log [opts]              Structured Plaza work log
khala plaza-check [opts]            Query Plaza records

# Substrate management
khala init                          Bootstrap ~/.agents/ substrate
khala status                        Health check
khala doctor [--quiet]              Validate substrate contract
khala migrate [--dry-run]           Migrate legacy ~/.aria/ to ~/.agents/

# Inspection
khala agent {list|show <id>}        Inspect installed agents
khala runtime {list|register}       Runtime registry
khala substrate {info|charter}      Substrate metadata
```

## Paths

- Substrate: `~/.agents/`
- Channels: `~/.agents/khala/channels/`
- Project: `~/_/projects/khala/`
