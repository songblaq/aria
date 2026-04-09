#!/usr/bin/env bash
# khala agent — read-only inspection of installed agent definitions

cmd_agent() {
  local sub="${1:-list}"; shift || true
  case "$sub" in
    list)  _agent_list "$@" ;;
    show)  _agent_show "$@" ;;
    path)  _agent_path "$@" ;;
    --help|-h|help)
      cat <<'HELP'
Usage:
  khala agent list [--json]           List all installed agents (persistent + phantom)
  khala agent show <id>               Print agent's AGENT.md + config + memory summary
  khala agent path <id>               Print absolute path to agent dir
HELP
      return 0
      ;;
    *) die "Unknown agent subcommand: $sub" ;;
  esac
}

_agent_list() {
  local json_mode="0"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) json_mode="1"; shift ;;
      *) die "Unknown agent list arg: $1" ;;
    esac
  done

  [[ -d "$KHALA_AGENTS_DIR" ]] || die "agents dir not found: $KHALA_AGENTS_DIR"

  python3 - "$KHALA_AGENTS_DIR" "$json_mode" <<'PY'
import json, sys, os
from pathlib import Path

agents_dir = Path(sys.argv[1])
json_mode = sys.argv[2] == "1"

persistent = []
for d in sorted(agents_dir.iterdir()):
    if not d.is_dir():
        continue
    agent_md = d / "AGENT.md"
    if not agent_md.exists():
        continue
    name = d.name
    if name in ("phantoms", "prompts", "teams", "templates"):
        continue
    cfg = d / "config.json"
    type_ = "?"
    domain = "?"
    if cfg.exists():
        try:
            c = json.load(open(cfg))
            type_ = c.get("type", "?")
            domain = c.get("domain", "?")
        except Exception:
            pass
    has_memory = (d / "memory" / "context.md").exists()
    has_harness = (d / "harness").is_dir()
    persistent.append({
        "id": name, "type": type_, "domain": domain,
        "memory": has_memory, "harness": has_harness,
        "path": str(d)
    })

phantoms = []
ph_dir = agents_dir / "phantoms"
if ph_dir.is_dir():
    for cat in sorted(ph_dir.iterdir()):
        if cat.is_dir():
            for f in sorted(cat.glob("*.md")):
                phantoms.append({"category": cat.name, "id": f.stem, "path": str(f)})

if json_mode:
    print(json.dumps({"persistent": persistent, "phantoms": phantoms}, ensure_ascii=False))
else:
    print("=== Persistent Agents ===")
    for a in persistent:
        memo = "M" if a["memory"] else "-"
        har = "H" if a["harness"] else "-"
        print(f"  {a['id']:<14} [{a['type']:<8}] {a['domain']:<22} {memo}{har}")
    print(f"\n  Total: {len(persistent)} persistent")

    print("\n=== Phantom Agents ===")
    by_cat = {}
    for p in phantoms:
        by_cat.setdefault(p["category"], []).append(p["id"])
    for cat, ids in sorted(by_cat.items()):
        print(f"  {cat:<16} ({len(ids):>2}): {', '.join(ids)}")
    print(f"\n  Total: {len(phantoms)} phantoms")
PY
}

_agent_show() {
  local id="${1:?Usage: khala agent show <id>}"
  local d="$KHALA_AGENTS_DIR/$id"
  [[ -d "$d" ]] || die "Agent not found: $id"

  echo "=== Agent: $id ==="
  echo "  Path: $d"
  echo ""
  if [[ -f "$d/config.json" ]]; then
    echo "--- config.json ---"
    cat "$d/config.json"
    echo ""
  fi
  if [[ -f "$d/AGENT.md" ]]; then
    echo "--- AGENT.md (first 25 lines) ---"
    head -25 "$d/AGENT.md"
    echo ""
  fi
  if [[ -f "$d/memory/context.md" ]]; then
    echo "--- memory/context.md (first 15 lines) ---"
    head -15 "$d/memory/context.md"
  fi
}

_agent_path() {
  local id="${1:?Usage: khala agent path <id>}"
  local d="$KHALA_AGENTS_DIR/$id"
  [[ -d "$d" ]] || die "Agent not found: $id"
  printf '%s\n' "$d"
}
