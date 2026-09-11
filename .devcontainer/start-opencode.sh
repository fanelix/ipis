#!/usr/bin/env bash
# Start the OpenCode server under pm2 and wait until it actually answers.
#
# Design notes:
# - `opencode web` is required for the browser UI. Its attempt to launch a
#   local browser is harmless in a headless container; OpenCode ignores that
#   failure and keeps the web server running.
# - pm2 supervises the opencode process directly instead of supervising this
#   script, so `pm2 restart`/`pm2 delete` really control the server and cannot
#   leave an orphan holding the port.
# - Nothing here hardcodes a Codespace name or workspace path. Every Codespace
#   gets a different forwarded hostname, so pinning one is always wrong.
# - Server authentication is disabled on purpose; see the unset below.
set -uo pipefail

PORT="${OPENCODE_PORT:-4097}"
APP_NAME="opencode-web"
LOG_DIR="/tmp/opencode"
WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$LOG_DIR"

OPENCODE_BIN="$(command -v opencode || true)"
if [ -z "$OPENCODE_BIN" ]; then
  echo "ERROR: 'opencode' is not on PATH. Did postCreateCommand finish?" >&2
  exit 1
fi

# Keep OpenCode's data directory (sessions and provider credentials) on the
# persistent /workspaces volume; $HOME is rebuilt with the container.
PERSIST="$WORKSPACE_DIR/.opencode-state"
DATA_DIR="$HOME/.local/share/opencode"
mkdir -p "$PERSIST" "$(dirname "$DATA_DIR")"
chmod 700 "$PERSIST" 2>/dev/null || true
if [ ! -L "$DATA_DIR" ]; then
  if [ -d "$DATA_DIR" ]; then
    cp -a "$DATA_DIR"/. "$PERSIST"/ 2>/dev/null || true
    mv "$DATA_DIR" "$DATA_DIR.bak.$(date +%s)"
  fi
  ln -sfn "$PERSIST" "$DATA_DIR"
fi

# Server authentication is deliberately disabled. OpenCode takes its password
# only from OPENCODE_SERVER_PASSWORD and offers no CLI flag for it, so clearing
# the variable here keeps the server passwordless even when a Codespaces secret
# of that name is injected into the container. With a password set, every
# request answers 401, including the health check below.
unset OPENCODE_SERVER_PASSWORD

echo "NOTE: OpenCode server authentication is disabled."
echo "      Access is gated only by Codespaces port visibility."
echo "      Keep port ${PORT} set to Private in the Ports panel."

# Clear the previous pm2 entry and any orphaned server still holding the port.
# A second instance on a busy port exits immediately with a ServeError, which
# under pm2 turns into a restart loop and no working forwarded port.
pm2 delete "$APP_NAME" >/dev/null 2>&1 || true
pkill -f "opencode web .*--port ${PORT}" >/dev/null 2>&1 || true
sleep 1

pm2 start "$OPENCODE_BIN" \
  --name "$APP_NAME" \
  --output "$LOG_DIR/out.log" \
  --error "$LOG_DIR/err.log" \
  -- web --hostname 0.0.0.0 --port "$PORT"

pm2 save >/dev/null 2>&1 || true

# Real readiness check. `curl -f` fails on non-2xx; the previous version used
# plain `curl -sS`, which reports success even on a 404 and so proved nothing.
# Authenticate the check when server protection is enabled; otherwise a
# healthy protected server returns 401 and would be mistaken for a failure.
CURL_AUTH=()
if [ -n "${OPENCODE_SERVER_PASSWORD:-}" ]; then
  CURL_AUTH=(-u "${OPENCODE_SERVER_USERNAME:-opencode}:${OPENCODE_SERVER_PASSWORD}")
fi

for _ in $(seq 1 30); do
  if curl -fsS --max-time 2 "${CURL_AUTH[@]}" "http://127.0.0.1:${PORT}/global/health" >/dev/null 2>&1; then
    echo "OpenCode is listening on port ${PORT}."
    echo "Open it from the Ports panel; the forwarded URL only exists while this Codespace is running."
    exit 0
  fi
  sleep 1
done

echo "ERROR: OpenCode did not become ready on port ${PORT}." >&2
pm2 logs "$APP_NAME" --lines 40 --nostream 2>/dev/null || true
exit 1
