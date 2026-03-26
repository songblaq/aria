#!/usr/bin/env bash
# aria khala — Khala channel messaging

cmd_khala() {
  local sub="${1:-help}"; shift || true
  case "$sub" in
    publish)  _khala_publish "$@" ;;
    list)     _khala_list ;;
    tail)     _khala_tail "$@" ;;
    plaza-log)   _khala_plaza_log "$@" ;;
    plaza-check) _khala_plaza_check "$@" ;;
    *)        echo "Usage: aria khala {publish|list|tail|plaza-log|plaza-check}" ;;
  esac
}

_khala_publish() {
  local channel="${1:?Usage: aria khala publish <channel> <message>}"
  local message="${2:?Usage: aria khala publish <channel> <message>}"
  local from_runtime="${3:-$ARIA_RUNTIME}"

  local channel_file="$ARIA_KHALA_DIR/${channel}.jsonl"
  mkdir -p "$(dirname "$channel_file")"

  local ts; ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local msg_id="aria-$(date +%Y%m%d-%H%M%S)-${from_runtime}"

  python3 -c "
import json, sys
print(json.dumps({
    'id': '$msg_id', 'channel': '$channel',
    'from': {'runtime': '$from_runtime', 'agent': 'main'},
    'type': 'message', 'content': sys.argv[1],
    'priority': 'normal', 'timestamp': '$ts', 'ttl': 86400
}, ensure_ascii=False))
" "$message" >> "$channel_file"
  echo "Published to $channel from $from_runtime"
}

_khala_list() {
  echo "=== Khala Channels ==="
  for f in "$ARIA_KHALA_DIR"/**/*.jsonl; do
    [[ -f "$f" ]] || continue
    local ch; ch=$(echo "$f" | sed "s|$ARIA_KHALA_DIR/||;s/\.jsonl$//")
    printf "  %-35s %s msgs\n" "$ch" "$(wc -l < "$f" | tr -d ' ')"
  done
}

_khala_tail() {
  local channel="${1:?Usage: aria khala tail <channel> [count]}"
  local count="${2:-5}"
  local channel_file="$ARIA_KHALA_DIR/${channel}.jsonl"
  [[ -f "$channel_file" ]] || die "Channel not found: $channel"

  echo "=== Last $count: $channel ==="
  tail -n "$count" "$channel_file" | python3 -c "
import json, sys
for line in sys.stdin:
    try:
        m = json.loads(line)
        if not isinstance(m, dict):
            print(f'  {line.strip()}')
            continue
        fr = m.get('from', {})
        if isinstance(fr, dict):
            src = fr.get('runtime', fr.get('node', fr.get('instance', '?')))
        else:
            src = str(fr or '?')
        ts = m.get('timestamp') or m.get('ts') or '?'
        text = m.get('content') or m.get('body') or m.get('detail') or m.get('title') or m.get('subject') or m.get('action') or ''
        if m.get('title') and m.get('body'):
            text = f'{m.get(\"title\")}: {m.get(\"body\")}'
        print(f'  [{ts}] {src}: {text[:120]}')
    except: print(f'  {line.strip()}')" 2>/dev/null
}

_khala_plaza_log() {
  local type="status"
  local title=""
  local body=""
  local runtime="${ARIA_RUNTIME}"
  local nick=""
  local tags=""
  local artifacts=""
  local context_json=""
  local ttl=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type)        type="${2:-}"; shift 2 ;;
      --title)       title="${2:-}"; shift 2 ;;
      --body)        body="${2:-}"; shift 2 ;;
      --runtime)     runtime="${2:-}"; shift 2 ;;
      --nick)        nick="${2:-}"; shift 2 ;;
      --tags)        tags="${2:-}"; shift 2 ;;
      --artifacts)   artifacts="${2:-}"; shift 2 ;;
      --context-json) context_json="${2:-}"; shift 2 ;;
      --ttl)         ttl="${2:-}"; shift 2 ;;
      --help|-h)
        cat <<'HELP'
Usage: aria khala plaza-log [options]

  --type <status|need|done|work_complete|mission_report|alert|join|split|merge|benchmark|test-report>
  --title <text>            Short title (optional; auto-filled from body)
  --body <text>             Main body text (required)
  --runtime <id>            Runtime id (default: $ARIA_RUNTIME)
  --nick <nick>             Structured nick for from.nick
  --tags <a,b,c>            Comma-separated tags
  --artifacts <p1,p2>       Comma-separated artifact paths
  --context-json <json>     JSON object for context
  --ttl <seconds|null>      TTL override; use "null" for no TTL

Example:
  aria khala plaza-log \
    --type status \
    --title "ORBIT 정리 시작" \
    --body "unknown cron id 재발 여부를 확인하고 task_defs를 점검 중" \
    --runtime codex \
    --tags orbit,ops \
    --artifacts /abs/path/report.md
HELP
        return 0
        ;;
      *)
        if [[ -z "$body" ]]; then
          body="$1"
          shift
        else
          die "Unknown plaza-log arg: $1"
        fi
        ;;
    esac
  done

  [[ -n "$body" ]] || die "Usage: aria khala plaza-log --body <text> [options]"

  local channel_file="$ARIA_KHALA_DIR/global/plaza.jsonl"
  mkdir -p "$(dirname "$channel_file")"

  python3 - "$channel_file" "$type" "$title" "$body" "$runtime" "$nick" "$tags" "$artifacts" "$context_json" "$ttl" <<'PY'
import json
import sys
from datetime import datetime
from zoneinfo import ZoneInfo

channel_file, msg_type, title, body, runtime, nick, tags_csv, artifacts_csv, context_json, ttl_raw = sys.argv[1:]

now = datetime.now(ZoneInfo("Asia/Seoul"))
ts = now.isoformat(timespec="seconds")
stamp = now.strftime("%Y%m%d-%H%M%S-%f")
msg_id = f"plaza-{runtime}-{stamp}"

if not title:
    title = body.replace("\n", " ").strip()[:60]

tags = [x.strip() for x in tags_csv.split(",") if x.strip()] if tags_csv else []
artifacts = [x.strip() for x in artifacts_csv.split(",") if x.strip()] if artifacts_csv else []

context = None
if context_json:
    try:
        context = json.loads(context_json)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Invalid --context-json: {exc}")
    if not isinstance(context, dict):
        raise SystemExit("--context-json must decode to an object")

ttl = 86400
if ttl_raw:
    ttl = None if ttl_raw == "null" else int(ttl_raw)

from_obj = {"runtime": runtime, "agent": "main"}
if nick:
    from_obj["nick"] = nick

msg = {
    "id": msg_id,
    "channel": "global/plaza",
    "from": from_obj,
    "type": msg_type,
    "title": title,
    "body": body,
    "timestamp": ts,
    "ttl": ttl,
}
if tags:
    msg["tags"] = tags
if artifacts:
    msg["artifacts"] = artifacts
if context:
    msg["context"] = context

with open(channel_file, "a", encoding="utf-8") as f:
    f.write(json.dumps(msg, ensure_ascii=False) + "\n")

print(f"Plaza logged: {msg_id}")
PY
}

_khala_plaza_check() {
  local minutes="180"
  local runtime=""
  local type=""
  local contains=""
  local limit="10"
  local require="0"
  local json_mode="0"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --minutes)   minutes="${2:-}"; shift 2 ;;
      --runtime)   runtime="${2:-}"; shift 2 ;;
      --type)      type="${2:-}"; shift 2 ;;
      --contains)  contains="${2:-}"; shift 2 ;;
      --limit)     limit="${2:-}"; shift 2 ;;
      --require)   require="1"; shift ;;
      --json)      json_mode="1"; shift ;;
      --help|-h)
        cat <<'HELP'
Usage: aria khala plaza-check [options]

  --minutes <N>     Look back N minutes (default: 180)
  --runtime <id>    Filter by from.runtime
  --type <type>     Filter by message type
  --contains <txt>  Require txt in title/body/content
  --limit <N>       Show last N matches (default: 10)
  --require         Exit non-zero when no matches
  --json            Print JSON instead of a text summary

Example:
  aria khala plaza-check --minutes 60 --runtime codex --contains "ORBIT" --require
HELP
        return 0
        ;;
      *)
        die "Unknown plaza-check arg: $1"
        ;;
    esac
  done

  local channel_file="$ARIA_KHALA_DIR/global/plaza.jsonl"
  [[ -f "$channel_file" ]] || die "Channel not found: global/plaza"

  python3 - "$channel_file" "$minutes" "$runtime" "$type" "$contains" "$limit" "$require" "$json_mode" <<'PY'
import json
import sys
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo

channel_file, minutes, runtime, msg_type, contains, limit, require, json_mode = sys.argv[1:]
minutes = int(minutes)
limit = int(limit)
require = require == "1"
json_mode = json_mode == "1"

now = datetime.now(ZoneInfo("Asia/Seoul"))
since = now - timedelta(minutes=minutes)
matches = []

def parse_ts(msg):
    raw = msg.get("timestamp") or msg.get("ts")
    if not raw:
        return None
    raw = str(raw).replace("Z", "+00:00")
    try:
        return datetime.fromisoformat(raw)
    except ValueError:
        return None

with open(channel_file, encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except Exception:
            continue
        if not isinstance(msg, dict):
            continue
        dt = parse_ts(msg)
        if not dt:
            continue
        dt_kst = dt.astimezone(ZoneInfo("Asia/Seoul"))
        if dt_kst < since:
            continue
        from_obj = msg.get("from", {})
        if isinstance(from_obj, dict):
            runtime_value = from_obj.get("runtime")
        else:
            runtime_value = str(from_obj or "")
        if runtime and runtime_value != runtime:
            continue
        if msg_type and msg.get("type") != msg_type:
            continue
        hay = " ".join(
            str(msg.get(k, "")) for k in ("title", "body", "content", "subject")
        )
        if contains and contains not in hay:
            continue
        matches.append({
            "timestamp": dt_kst.isoformat(timespec="seconds"),
            "runtime": runtime_value or None,
            "type": msg.get("type"),
            "title": msg.get("title") or msg.get("subject") or "",
            "body": msg.get("body") or msg.get("content") or msg.get("detail") or msg.get("action") or "",
        })

matches = matches[-limit:]

if json_mode:
    print(json.dumps({
        "minutes": minutes,
        "runtime": runtime or None,
        "type": msg_type or None,
        "contains": contains or None,
        "count": len(matches),
        "matches": matches,
    }, ensure_ascii=False, indent=2))
else:
    print(f"=== Plaza Check ({minutes}m) ===")
    print(f"count={len(matches)} runtime={runtime or '*'} type={msg_type or '*'} contains={contains or '*'}")
    for m in matches:
        title = m["title"] or m["body"][:60]
        print(f"[{m['timestamp']}] {m['runtime']} {m['type']} | {title}")

if require and not matches:
    raise SystemExit(1)
PY
}
