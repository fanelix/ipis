#!/usr/bin/env bash
set -u

WORKSPACE="/workspaces/ipis"
PERSIST="$WORKSPACE/.opencode-state"
DATA_HOME="$HOME/.local/share"
TARGET="$DATA_HOME/opencode"
DIAG="$WORKSPACE/.opencode-diagnostics"

mkdir -p "$PERSIST" "$DATA_HOME" "$DIAG"
chmod 700 "$PERSIST" 2>/dev/null || true

# Persist OpenCode sessions/state across Codespaces rebuilds by keeping the
# real data under /workspaces and linking OpenCode's default data directory.
if [ -L "$TARGET" ]; then
  CURRENT_TARGET="$(readlink -f "$TARGET" 2>/dev/null || true)"
  EXPECTED_TARGET="$(readlink -f "$PERSIST" 2>/dev/null || true)"
  if [ "$CURRENT_TARGET" != "$EXPECTED_TARGET" ]; then
    rm -f "$TARGET"
    ln -s "$PERSIST" "$TARGET"
  fi
elif [ -d "$TARGET" ]; then
  cp -a "$TARGET"/. "$PERSIST"/ 2>/dev/null || true
  rm -rf "$TARGET"
  ln -s "$PERSIST" "$TARGET"
elif [ -e "$TARGET" ]; then
  mv "$TARGET" "$TARGET.backup.$(date +%s)"
  ln -s "$PERSIST" "$TARGET"
else
  ln -s "$PERSIST" "$TARGET"
fi

{
  echo "timestamp=$(date -Is)"
  echo "cwd=$(pwd)"
  echo "opencode_path=$(command -v opencode || true)"
  echo "opencode_version=$(opencode --version 2>&1 || true)"
  echo "node_version=$(node --version 2>&1 || true)"
  echo "npm_version=$(npm --version 2>&1 || true)"
  echo "opencode_data_path=$TARGET"
  echo "opencode_data_target=$(readlink -f "$TARGET" 2>/dev/null || true)"
  echo "persistent_state=$PERSIST"
  if [ -L "$TARGET" ] && [ "$(readlink -f "$TARGET" 2>/dev/null || true)" = "$(readlink -f "$PERSIST" 2>/dev/null || true)" ]; then
    echo "persistent_state_link=OK"
  else
    echo "persistent_state_link=ERROR"
  fi
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
