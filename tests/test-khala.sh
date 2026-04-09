#!/usr/bin/env bash
# Khala smoke test suite — covers CLI surface and substrate integrity
#
# Usage: bash tests/test-khala.sh
# Env:   AGENTS_HOME (optional, defaults to ~/.agents)
set -uo pipefail

AGENTS_HOME="${AGENTS_HOME:-$HOME/.agents}"
export PATH="$AGENTS_HOME/bin:$PATH"

PASS=0; FAIL=0

_test() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    echo "  ✅ $name"; PASS=$((PASS+1))
  else
    echo "  ❌ $name"; FAIL=$((FAIL+1))
  fi
}

_test_output() {
  local name="$1" pattern="$2"; shift 2
  local out
  out=$("$@" 2>&1)
  if echo "$out" | grep -q "$pattern"; then
    echo "  ✅ $name"; PASS=$((PASS+1))
  else
    echo "  ❌ $name (expected '$pattern' in output)"; FAIL=$((FAIL+1))
  fi
}

echo "=== Khala Smoke Test Suite ==="
echo "   AGENTS_HOME: $AGENTS_HOME"
echo ""

echo "-- CLI basics --"
_test_output "khala version"     "v3"  khala version
_test_output "khala help"        "Messaging"  khala help
_test_output "khala status"      "Khala"  khala status
_test_output "khala doctor"      "OK"  khala doctor
_test "khala doctor --quiet (exit 0)" khala doctor --quiet

echo ""
echo "-- Messaging (flat dispatch) --"
TEST_CHANNEL="test/khala-suite-$$"
TEST_UNIQUE="$(date +%s)-$$"
TEST_MSG="smoke-$TEST_UNIQUE"

_test_output "khala publish" "Published" khala publish "$TEST_CHANNEL" "$TEST_MSG"
_test_output "khala list" "channels" khala list
_test_output "khala list --json (NDJSON)" "channel" khala list --json
_test_output "khala tail" "$TEST_MSG" khala tail "$TEST_CHANNEL" -n 1
_test_output "khala tail --json" "$TEST_MSG" khala tail "$TEST_CHANNEL" -n 1 --json
# Search: unique token + exact channel (not glob) to guarantee single match
_test_output "khala search" "$TEST_MSG" khala search "$TEST_UNIQUE" --channel "$TEST_CHANNEL" --limit 1

# Extract the message id from the tail JSON for get test
MSG_ID=$(khala tail "$TEST_CHANNEL" -n 1 --json 2>/dev/null | python3 -c "import json,sys; [print(json.loads(l).get('id','')) for l in sys.stdin][0]" 2>/dev/null)
if [[ -n "$MSG_ID" ]]; then
  _test_output "khala get <id>" "$TEST_MSG" khala get "$TEST_CHANNEL" "$MSG_ID"
fi

echo ""
echo "-- Inspection --"
_test_output "khala agent list"     "Persistent" khala agent list
_test_output "khala agent list (blaq)" "blaq" khala agent list
_test_output "khala runtime list"   "Runtimes" khala runtime list
_test_output "khala substrate info" "Substrate" khala substrate info
_test_output "khala substrate info (owl external)" "External" khala substrate info

echo ""
echo "-- Substrate integrity --"
_test "config.json valid JSON" python3 -c "import json; json.load(open('$AGENTS_HOME/config.json'))"
_test "agents.json valid JSON" python3 -c "import json; d=json.load(open('$AGENTS_HOME/agents/agents.json')); assert len(d['agents'])>=1"
_test "AGENTS.md charter exists" test -f "$AGENTS_HOME/AGENTS.md"
_test "khala channels dir exists" test -d "$AGENTS_HOME/khala/channels"
_test "skills dir exists" test -d "$AGENTS_HOME/skills"

echo ""
echo "-- Legacy compatibility --"
_test_output "aria alias (legacy)" "v3" aria version
_test_output "aria status (legacy)" "Khala" aria status

echo ""
echo "-- Blaq identity agent --"
_test "blaq agent dir exists" test -d "$AGENTS_HOME/agents/blaq"
_test "blaq AGENT.md exists" test -f "$AGENTS_HOME/agents/blaq/AGENT.md"
_test "blaq config.json valid" python3 -c "import json; c=json.load(open('$AGENTS_HOME/agents/blaq/config.json')); assert c['type']=='identity'"
_test "blaq profile/ exists" test -d "$AGENTS_HOME/agents/blaq/profile"

echo ""
echo "=== Results ==="
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
echo ""
[ "$FAIL" -eq 0 ] && { echo "OK"; exit 0; } || { echo "FAIL"; exit 1; }
