#!/usr/bin/env bash
# khala substrate — substrate metadata + resident discovery

cmd_substrate() {
  local sub="${1:-info}"; shift || true
  case "$sub" in
    info)      _substrate_info "$@" ;;
    residents) _substrate_residents "$@" ;;
    charter)   _substrate_charter ;;
    --help|-h|help)
      cat <<'HELP'
Usage:
  khala substrate info [--json]      Show substrate root, version, residents
  khala substrate residents [--json] Detailed resident scan
  khala substrate charter            Print AGENTS.md charter
HELP
      return 0
      ;;
    *) die "Unknown substrate subcommand: $sub" ;;
  esac
}

_substrate_info() {
  local json_mode="0"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) json_mode="1"; shift ;;
      *) die "Unknown arg: $1" ;;
    esac
  done

  python3 - "$AGENTS_HOME" "$KHALA_VERSION" "$json_mode" <<'PY'
import json, os, sys
from pathlib import Path

home, version, json_mode = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
home = Path(home)

residents = {}
if (home / "agents").is_dir():
    ag_count = sum(1 for d in (home / "agents").iterdir() if d.is_dir() and (d / "AGENT.md").is_file())
    residents["agents"] = {"path": str(home / "agents"), "count": ag_count, "description": f"{ag_count} installed agents (incl. blaq identity)"}

# External (no longer a substrate resident)
external = {}
owl_home = Path.home() / ".owl"
if owl_home.is_dir():
    external["owl"] = {"path": str(owl_home), "description": "LLM Wiki (formerly agent-brain), now external"}

if (home / "aria").is_dir():
    residents["aria-legacy"] = {"path": str(home / "aria"), "description": "pre-v3.1 residue"}

shared = []
if (home / "khala").is_dir(): shared.append("khala")
if (home / "skills").is_dir(): shared.append("skills")
if (home / "bin").is_dir(): shared.append("bin")

info = {
    "substrate_home": str(home),
    "khala_version": version,
    "residents": residents,
    "external": external,
    "shared": shared,
    "charter": str(home / "AGENTS.md"),
}

if json_mode:
    print(json.dumps(info, indent=2, ensure_ascii=False))
else:
    print(f"=== Substrate: {home} ===")
    print(f"  Khala version: {version}")
    print(f"  Charter:       {info['charter']}")
    print()
    print("  Residents:")
    for name, data in residents.items():
        desc = data.get("description", "")
        print(f"    {name:<14} {data.get('path')}  {desc}")
    print()
    print(f"  Shared:        {', '.join(shared)}")
    if external:
        print()
        print("  External (not in substrate):")
        for name, data in external.items():
            print(f"    {name:<14} {data.get('path')}  {data.get('description','')}")
PY
}

_substrate_residents() {
  _substrate_info "$@"
}

_substrate_charter() {
  if [[ -f "$KHALA_CHARTER" ]]; then
    cat "$KHALA_CHARTER"
  else
    die "Charter not found: $KHALA_CHARTER (run 'khala init')"
  fi
}
