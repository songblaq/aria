#!/usr/bin/env bash
# khala messaging — append-only JSONL channels (formerly ARB bus)

cmd_khala() {
  local sub="${1:-help}"; shift || true
  case "$sub" in
    publish)     _khala_publish "$@" ;;
    list)        _khala_list "$@" ;;
    tail)        _khala_tail "$@" ;;
    get)         _khala_get "$@" ;;
    search)      _khala_search "$@" ;;
    watch)       _khala_watch "$@" ;;
    plaza-log)   _khala_plaza_log "$@" ;;
    plaza-check) _khala_plaza_check "$@" ;;
    help|--help|-h) _khala_help ;;
    *)           echo "Usage: khala {publish|list|tail|get|search|watch|plaza-log|plaza-check}"; return 1 ;;
  esac
}

_khala_help() {
  cat <<'HELP'
khala — messaging substrate

  publish <channel> <message> [--from <runtime>]   Publish a message to a channel
  list [--json]                                    List all channels with message counts
  tail <channel> [-n N] [--json]                   Show last N messages
  get <channel> <msg_id> [--json]                  Fetch a single message by id
  search <pattern> [--channel <glob>] [--field F]  Full-text search across channels
                  [--since <iso|rel>] [--limit N] [--json]
  watch <channel> [--json] [--interval <s>]        Tail -f style live subscription
  plaza-log [options]                              Structured Plaza work log
  plaza-check [options]                            Query Plaza records

  Run any subcommand with --help for details.
HELP
}

_khala_publish() {
  local channel=""
  local message=""
  local from_runtime="$KHALA_RUNTIME"
  local json_mode="0"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from)  from_runtime="${2:?}"; shift 2 ;;
      --json)  json_mode="1"; shift ;;
      --help|-h) echo "Usage: khala publish <channel> <message> [--from <runtime>] [--json]"; return 0 ;;
      *)
        if [[ -z "$channel" ]]; then channel="$1"; shift
        elif [[ -z "$message" ]]; then message="$1"; shift
        elif [[ "$from_runtime" == "$KHALA_RUNTIME" ]]; then from_runtime="$1"; shift  # legacy positional
        else die "Unknown publish arg: $1"; fi
        ;;
    esac
  done

  [[ -n "$channel" && -n "$message" ]] || die "Usage: khala publish <channel> <message> [--from <runtime>] [--json]"

  local channel_file="$KHALA_CHANNELS_DIR/${channel}.jsonl"
  mkdir -p "$(dirname "$channel_file")"

  local ts; ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local msg_id="khala-$(date +%Y%m%d-%H%M%S)-${from_runtime}"

  python3 - "$msg_id" "$channel" "$from_runtime" "$ts" "$message" "$channel_file" "$json_mode" <<'PY'
import json, sys
msg_id, channel, runtime, ts, content, channel_file, json_mode = sys.argv[1:]
msg = {
    "id": msg_id, "channel": channel,
    "from": {"runtime": runtime, "agent": "main"},
    "type": "message", "content": content,
    "priority": "normal", "timestamp": ts, "ttl": 86400
}
with open(channel_file, "a", encoding="utf-8") as f:
    f.write(json.dumps(msg, ensure_ascii=False) + "\n")
if json_mode == "1":
    print(json.dumps({"published": True, "id": msg_id, "channel": channel}, ensure_ascii=False))
else:
    print(f"Published to {channel} from {runtime} (id={msg_id})")
PY
}

_khala_list() {
  local json_mode="0"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) json_mode="1"; shift ;;
      --help|-h) echo "Usage: khala list [--json]"; return 0 ;;
      *) die "Unknown list arg: $1" ;;
    esac
  done

  [[ -d "$KHALA_CHANNELS_DIR" ]] || { [[ "$json_mode" == "1" ]] && echo "[]" || echo "(no channels)"; return 0; }

  python3 - "$KHALA_CHANNELS_DIR" "$json_mode" <<'PY'
import json, os, sys
from pathlib import Path

khala_dir = Path(sys.argv[1])
json_mode = sys.argv[2] == "1"

channels = []
for f in sorted(khala_dir.rglob("*.jsonl")):
    rel = f.relative_to(khala_dir)
    name = str(rel).removesuffix(".jsonl")
    try:
        with open(f, "rb") as fh:
            count = sum(1 for _ in fh)
    except OSError:
        count = -1
    channels.append({"channel": name, "messages": count, "path": str(f)})

if json_mode:
    for c in channels:
        print(json.dumps(c, ensure_ascii=False))
else:
    print("=== Khala Channels ===")
    for c in channels:
        print(f"  {c['channel']:<45s} {c['messages']:>6d} msgs")
    print(f"  ---")
    print(f"  Total: {len(channels)} channels, {sum(c['messages'] for c in channels if c['messages']>=0)} messages")
PY
}

_khala_tail() {
  local channel=""
  local count="5"
  local json_mode="0"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--count) count="${2:?count required}"; shift 2 ;;
      --json) json_mode="1"; shift ;;
      --help|-h) echo "Usage: khala tail <channel> [-n N] [--json]"; return 0 ;;
      *)
        if [[ -z "$channel" ]]; then channel="$1"; shift
        elif [[ "$1" =~ ^[0-9]+$ ]]; then count="$1"; shift  # legacy positional
        else die "Unknown tail arg: $1"; fi
        ;;
    esac
  done

  [[ -n "$channel" ]] || die "Usage: khala tail <channel> [-n N] [--json]"
  local channel_file="$KHALA_CHANNELS_DIR/${channel}.jsonl"
  [[ -f "$channel_file" ]] || die "Channel not found: $channel"

  python3 - "$channel_file" "$count" "$json_mode" "$channel" <<'PY'
import json, sys
from collections import deque

channel_file, count, json_mode, channel = sys.argv[1:]
count = int(count)
json_mode = json_mode == "1"

# Read last N lines without loading whole file
lines = deque(maxlen=count)
with open(channel_file, encoding="utf-8") as f:
    for line in f:
        line = line.rstrip("\n")
        if line:
            lines.append(line)

if not json_mode:
    print(f"=== Last {count}: {channel} ===")

for line in lines:
    try:
        m = json.loads(line)
    except Exception:
        if json_mode:
            print(json.dumps({"raw": line, "error": "parse_failed"}))
        else:
            print(f"  {line[:200]}")
        continue
    if not isinstance(m, dict):
        if json_mode:
            print(json.dumps({"raw": line}))
        else:
            print(f"  {line[:200]}")
        continue

    if json_mode:
        # Pass through as NDJSON
        print(json.dumps(m, ensure_ascii=False))
    else:
        fr = m.get("from", {})
        src = fr.get("runtime", fr.get("node", "?")) if isinstance(fr, dict) else str(fr or "?")
        ts = m.get("timestamp") or m.get("ts") or "?"
        text = m.get("content") or m.get("body") or m.get("detail") or m.get("title") or m.get("subject") or m.get("action") or ""
        if m.get("title") and m.get("body"):
            text = f"{m.get('title')}: {m.get('body')}"
        print(f"  [{ts}] {src}: {str(text)[:120]}")
PY
}

_khala_get() {
  local channel="${1:?Usage: khala get <channel> <msg_id> [--json]}"; shift
  local msg_id="${1:?Usage: khala get <channel> <msg_id> [--json]}"; shift
  local json_mode="0"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) json_mode="1"; shift ;;
      --help|-h) echo "Usage: khala get <channel> <msg_id> [--json]"; return 0 ;;
      *) die "Unknown get arg: $1" ;;
    esac
  done

  local channel_file="$KHALA_CHANNELS_DIR/${channel}.jsonl"
  [[ -f "$channel_file" ]] || die "Channel not found: $channel"

  python3 - "$channel_file" "$msg_id" "$json_mode" <<'PY'
import json, sys

channel_file, msg_id, json_mode = sys.argv[1:]
json_mode = json_mode == "1"

found = None
with open(channel_file, encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            m = json.loads(line)
        except Exception:
            continue
        if isinstance(m, dict) and m.get("id") == msg_id:
            found = m
            break

if not found:
    sys.stderr.write(f"Message not found: {msg_id} in {channel_file}\n")
    sys.exit(1)

if json_mode:
    print(json.dumps(found, ensure_ascii=False))
else:
    print(json.dumps(found, ensure_ascii=False, indent=2))
PY
}

_khala_search() {
  local pattern=""
  local channel_glob="*"
  local field="all"
  local since=""
  local limit="50"
  local json_mode="0"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --channel) channel_glob="${2:?}"; shift 2 ;;
      --field)   field="${2:?}"; shift 2 ;;
      --since)   since="${2:?}"; shift 2 ;;
      --limit)   limit="${2:?}"; shift 2 ;;
      --json)    json_mode="1"; shift ;;
      --help|-h)
        cat <<'HELP'
Usage: khala search <pattern> [options]

  --channel <glob>   Limit to channels matching glob (e.g. 'global/*')
  --field <name>     Match in: all (default) | content | body | title | subject
  --since <iso|rel>  Only messages since timestamp (e.g. '2026-04-01' or '2h')
  --limit <N>        Max results (default 50)
  --json             NDJSON output (one message per line)
HELP
        return 0
        ;;
      *)
        if [[ -z "$pattern" ]]; then pattern="$1"; shift
        else die "Unknown search arg: $1"; fi
        ;;
    esac
  done

  [[ -n "$pattern" ]] || die "Usage: khala search <pattern> [options]"

  python3 - "$KHALA_CHANNELS_DIR" "$pattern" "$channel_glob" "$field" "$since" "$limit" "$json_mode" <<'PY'
import json, sys, re, fnmatch
from pathlib import Path
from datetime import datetime, timedelta, timezone

khala_dir, pattern, channel_glob, field, since_raw, limit, json_mode = sys.argv[1:]
limit = int(limit)
json_mode = json_mode == "1"

# Parse --since
since_dt = None
if since_raw:
    if re.match(r"^\d+[smhd]$", since_raw):
        unit = since_raw[-1]
        n = int(since_raw[:-1])
        delta = {"s": "seconds", "m": "minutes", "h": "hours", "d": "days"}[unit]
        since_dt = datetime.now(timezone.utc) - timedelta(**{delta: n})
    else:
        try:
            since_dt = datetime.fromisoformat(since_raw.replace("Z", "+00:00"))
            if since_dt.tzinfo is None:
                since_dt = since_dt.replace(tzinfo=timezone.utc)
        except ValueError:
            sys.stderr.write(f"Invalid --since: {since_raw}\n"); sys.exit(2)

khala_path = Path(khala_dir)
matches = []
pat_re = re.compile(re.escape(pattern), re.IGNORECASE)

fields_to_check = [field] if field != "all" else ["content", "body", "title", "subject", "detail", "action"]

for f in sorted(khala_path.rglob("*.jsonl")):
    rel = str(f.relative_to(khala_path)).removesuffix(".jsonl")
    if not fnmatch.fnmatch(rel, channel_glob):
        continue
    try:
        with open(f, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    m = json.loads(line)
                except Exception:
                    continue
                if not isinstance(m, dict):
                    continue

                # Time filter
                if since_dt:
                    raw_ts = m.get("timestamp") or m.get("ts")
                    if raw_ts:
                        try:
                            dt = datetime.fromisoformat(str(raw_ts).replace("Z", "+00:00"))
                            if dt.tzinfo is None:
                                dt = dt.replace(tzinfo=timezone.utc)
                            if dt < since_dt:
                                continue
                        except ValueError:
                            pass

                # Field match
                hay = " ".join(str(m.get(k, "")) for k in fields_to_check)
                if not pat_re.search(hay):
                    continue

                m["_channel"] = rel
                matches.append(m)
                if len(matches) >= limit:
                    break
    except OSError:
        continue
    if len(matches) >= limit:
        break

if json_mode:
    for m in matches:
        print(json.dumps(m, ensure_ascii=False))
else:
    print(f"=== Khala Search: '{pattern}' ({len(matches)} matches) ===")
    for m in matches:
        ts = m.get("timestamp") or m.get("ts") or "?"
        fr = m.get("from", {})
        src = fr.get("runtime", "?") if isinstance(fr, dict) else str(fr)
        text = m.get("content") or m.get("body") or m.get("title") or ""
        print(f"  [{ts}] {m.get('_channel')} {src}: {str(text)[:100]}")
PY
}

_khala_watch() {
  local channel=""
  local interval="0.5"
  local json_mode="0"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --interval) interval="${2:?}"; shift 2 ;;
      --json)     json_mode="1"; shift ;;
      --help|-h)  echo "Usage: khala watch <channel> [--interval <s>] [--json]"; return 0 ;;
      *)
        if [[ -z "$channel" ]]; then channel="$1"; shift
        else die "Unknown watch arg: $1"; fi
        ;;
    esac
  done

  [[ -n "$channel" ]] || die "Usage: khala watch <channel> [--interval <s>] [--json]"
  local channel_file="$KHALA_CHANNELS_DIR/${channel}.jsonl"
  [[ -f "$channel_file" ]] || die "Channel not found: $channel"

  python3 - "$channel_file" "$interval" "$json_mode" "$channel" <<'PY'
import json, os, sys, time

channel_file, interval, json_mode, channel = sys.argv[1:]
interval = float(interval)
json_mode = json_mode == "1"

if not json_mode:
    sys.stderr.write(f"=== Watching {channel} (Ctrl+C to stop) ===\n")

# Start at end of file
try:
    pos = os.path.getsize(channel_file)
except OSError:
    pos = 0
inode = os.stat(channel_file).st_ino if os.path.exists(channel_file) else None

try:
    while True:
        try:
            current_inode = os.stat(channel_file).st_ino
            if current_inode != inode:
                # Rotation
                inode = current_inode
                pos = 0
            current_size = os.path.getsize(channel_file)
            if current_size > pos:
                with open(channel_file, encoding="utf-8") as f:
                    f.seek(pos)
                    for line in f:
                        line = line.rstrip("\n")
                        if not line:
                            continue
                        if json_mode:
                            try:
                                m = json.loads(line)
                                print(json.dumps(m, ensure_ascii=False), flush=True)
                            except Exception:
                                print(json.dumps({"raw": line}), flush=True)
                        else:
                            try:
                                m = json.loads(line)
                                fr = m.get("from", {})
                                src = fr.get("runtime", "?") if isinstance(fr, dict) else "?"
                                ts = m.get("timestamp") or "?"
                                text = m.get("content") or m.get("body") or m.get("title") or ""
                                print(f"[{ts}] {src}: {str(text)[:140]}", flush=True)
                            except Exception:
                                print(line[:200], flush=True)
                pos = current_size
            elif current_size < pos:
                # Truncated
                pos = current_size
        except FileNotFoundError:
            time.sleep(interval)
            continue
        time.sleep(interval)
except KeyboardInterrupt:
    sys.stderr.write("\n")
PY
}

_khala_plaza_log() {
  local type="status"
  local title=""
  local body=""
  local runtime="${KHALA_RUNTIME}"
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
Usage: khala plaza-log [options]

  --type <status|need|done|work_complete|mission_report|alert|join|split|merge|benchmark|test-report>
  --title <text>            Short title (optional; auto-filled from body)
  --body <text>             Main body text (required)
  --runtime <id>            Runtime id (default: $KHALA_RUNTIME)
  --nick <nick>             Structured nick for from.nick
  --tags <a,b,c>            Comma-separated tags
  --artifacts <p1,p2>       Comma-separated artifact paths
  --context-json <json>     JSON object for context
  --ttl <seconds|null>      TTL override; use "null" for no TTL

Example:
  khala plaza-log \
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

  [[ -n "$body" ]] || die "Usage: khala plaza-log --body <text> [options]"

  local channel_file="$KHALA_CHANNELS_DIR/global/plaza.jsonl"
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
Usage: khala plaza-check [options]

  --minutes <N>     Look back N minutes (default: 180)
  --runtime <id>    Filter by from.runtime
  --type <type>     Filter by message type
  --contains <txt>  Require txt in title/body/content
  --limit <N>       Show last N matches (default: 10)
  --require         Exit non-zero when no matches
  --json            Print JSON instead of a text summary

Example:
  khala plaza-check --minutes 60 --runtime codex --contains "ORBIT" --require
HELP
        return 0
        ;;
      *)
        die "Unknown plaza-check arg: $1"
        ;;
    esac
  done

  local channel_file="$KHALA_CHANNELS_DIR/global/plaza.jsonl"
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
