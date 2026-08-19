#!/usr/bin/env bash
# Print one HUD line for tmux status-format[N]. Cache 1s per pane pid.

set -u
LINE="${1:-1}"
CWD="${2:-${PWD:-$HOME}}"
PANE_PID="${3:-}"

WRAP_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=/dev/null
. "$WRAP_DIR/path.sh"

DIR="${GROK_HUD_DATA:-$HOME/.grok/plugins/grok-hud}"
CACHE="${DIR}/.status-cache${PANE_PID:+.$PANE_PID}"
META="${CACHE}.meta"

now=$(date +%s)
old_ts=0
old_key=""
if [ -f "$META" ]; then
  read -r old_ts old_key <"$META" || true
fi

if [ ! -f "$CACHE" ] || [ "$CWD $PANE_PID" != "$old_key" ] || [ $((now - old_ts)) -ge 1 ]; then
  tmp="${CACHE}.$$"
  GROK_HUD_TMUX=1 node "$DIR/render.mjs" "$CWD" "$PANE_PID" >"$tmp" 2>/dev/null || true
  mv "$tmp" "$CACHE" 2>/dev/null || true
  printf '%s %s\n' "$now" "$CWD $PANE_PID" >"$META"
fi

sed -n "${LINE}p" "$CACHE" | tr -d '\r'
