#!/usr/bin/env bash
# Usage: scripts/push/send.sh "Title" "Body" [--token <t>] [--data k=v ...]
# Reads PUSH_URL and PUSH_ADMIN_KEY from the environment or scripts/push/.env.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
[ -f "$here/.env" ] && { set -a; . "$here/.env"; set +a; }
: "${PUSH_URL:?set PUSH_URL}"
title="${1:?title}"; body="${2:?body}"; shift 2
token=""; data=()
while [ $# -gt 0 ]; do
  case "$1" in
    --token) token="${2:?token}"; shift 2 ;;
    --data) data+=("${2:?k=v}"); shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
payload="$(TITLE="$title" BODY="$body" TOKEN="$token" python3 -I -c '
import json, os, sys
d = dict(a.split("=", 1) for a in sys.argv[1:])
t = os.environ["TOKEN"]
m = {"title": os.environ["TITLE"], "body": os.environ["BODY"], "target": {"token": t} if t else {"topic": "all"}}
if d: m["data"] = d
print(json.dumps(m))' ${data[@]+"${data[@]}"})"
curl -sS -w '\nHTTP %{http_code}\n' -X POST "$PUSH_URL" \
  -H "Authorization: Bearer ${PUSH_ADMIN_KEY:-}" \
  -H "Content-Type: application/json" \
  -d "$payload"
