#!/usr/bin/env bash
set -u
DIAG="/workspaces/ipis/.opencode-diagnostics"
mkdir -p "$DIAG"
{
  echo "timestamp=$(date -Is)"
  echo "cwd=$(pwd)"
  echo "opencode_path=$(command -v opencode || true)"
  echo "opencode_version=$(opencode --version 2>&1 || true)"
  echo "node_version=$(node --version 2>&1 || true)"
  echo "npm_version=$(npm --version 2>&1 || true)"
  echo "OPENCODE env vars:"
  env | grep '^OPENCODE_' | sed 's/=.*$/=<set>/' || true
} > "$DIAG/startup.txt" 2>&1

opencode web --hostname 0.0.0.0 --port 4097 >> "$DIAG/server.log" 2>&1 &
PID=$!

for i in $(seq 1 20); do
  sleep 1
  if curl -sS -D "$DIAG/health.headers" http://127.0.0.1:4097/global/health -o "$DIAG/health.body"; then
    break
  fi
done

curl -sS -D "$DIAG/root.headers" http://127.0.0.1:4097/ -o "$DIAG/root.body" || true
curl -sS -D "$DIAG/doc.headers" http://127.0.0.1:4097/doc -o "$DIAG/doc.body" || true

FORWARDED_HOST="congenial-space-garbanzo-q7jw4595qj742xxq7-4097.app.github.dev"
curl -sS \
  -H "Host: $FORWARDED_HOST" \
  -H "X-Forwarded-Host: $FORWARDED_HOST" \
  -H "X-Forwarded-Proto: https" \
  -D "$DIAG/proxy-host.headers" \
  http://127.0.0.1:4097/ \
  -o "$DIAG/proxy-host.body" || true

wait "$PID"
