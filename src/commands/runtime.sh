#!/usr/bin/env bash
# khala runtime — manage runtime registry in config.json

cmd_runtime() {
  local sub="${1:-list}"; shift || true
  case "$sub" in
    list)     _runtime_list "$@" ;;
    register) _runtime_register "$@" ;;
    enable)   _runtime_set_state "$1" true ;;
    disable)  _runtime_set_state "$1" false ;;
    --help|-h|help)
      cat <<'HELP'
Usage:
  khala runtime list [--json]                 List registered runtimes
  khala runtime register <id> --from <file>   Register runtime from JSON file
  khala runtime enable <id>                   Enable a registered runtime
  khala runtime disable <id>                  Disable a registered runtime
HELP
      return 0
      ;;
    *) die "Unknown runtime subcommand: $sub" ;;
  esac
}

_runtime_list() {
  local json_mode="0"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) json_mode="1"; shift ;;
      *) die "Unknown runtime list arg: $1" ;;
    esac
  done

  [[ -f "$KHALA_CONFIG" ]] || die "Config not found: $KHALA_CONFIG"

  python3 - "$KHALA_CONFIG" "$json_mode" <<'PY'
import json, sys
cfg_path, json_mode = sys.argv[1], sys.argv[2] == "1"
cfg = json.load(open(cfg_path))
runtimes = cfg.get("runtimes", {})

if json_mode:
    print(json.dumps({"runtimes": runtimes}, ensure_ascii=False))
else:
    print("=== Registered Runtimes ===")
    for rid, rdata in sorted(runtimes.items()):
        if isinstance(rdata, dict):
            enabled = "✓" if rdata.get("enabled") else "✗"
            type_ = rdata.get("type", "?")
            print(f"  [{enabled}] {rid:<16} {type_}")
        else:
            print(f"      {rid}")
    print(f"\n  Total: {len(runtimes)} runtimes")
PY
}

_runtime_register() {
  local id=""
  local from=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from) from="${2:?}"; shift 2 ;;
      *) if [[ -z "$id" ]]; then id="$1"; shift; else die "Unknown arg: $1"; fi ;;
    esac
  done

  [[ -n "$id" ]] || die "Usage: khala runtime register <id> --from <runtime.json>"
  [[ -f "$from" ]] || die "Source file not found: $from"
  [[ -f "$KHALA_CONFIG" ]] || die "Config not found: $KHALA_CONFIG"

  python3 - "$KHALA_CONFIG" "$id" "$from" <<'PY'
import json, sys
cfg_path, rid, src = sys.argv[1:]
with open(cfg_path) as f:
    cfg = json.load(f)
with open(src) as f:
    runtime_data = json.load(f)

# Ensure enabled by default unless source says otherwise
if "enabled" not in runtime_data:
    runtime_data["enabled"] = True

cfg.setdefault("runtimes", {})[rid] = runtime_data

with open(cfg_path, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
print(f"Registered runtime: {rid}")
PY
}

_runtime_set_state() {
  local id="${1:?Usage: khala runtime enable|disable <id>}"
  local enabled="$2"
  python3 - "$KHALA_CONFIG" "$id" "$enabled" <<'PY'
import json, sys
cfg_path, rid, enabled = sys.argv[1:]
with open(cfg_path) as f:
    cfg = json.load(f)
if rid not in cfg.get("runtimes", {}):
    sys.exit(f"Runtime not found: {rid}")
if isinstance(cfg["runtimes"][rid], dict):
    cfg["runtimes"][rid]["enabled"] = enabled == "true"
else:
    cfg["runtimes"][rid] = {"enabled": enabled == "true"}
with open(cfg_path, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
print(f"Runtime {rid} {'enabled' if enabled == 'true' else 'disabled'}")
PY
}
