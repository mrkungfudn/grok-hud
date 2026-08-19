#!/usr/bin/env bash
# Wrap interactive `grok` in an isolated tmux socket so a 5-line HUD sits
# under the TUI. Grok has no statusLine hook; tmux status rows are the footer.
#
# Disable: GROK_HUD_AUTO=0 grok
# Real binary: "$HOME/.grok/bin/grok"

set -euo pipefail

WRAP_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=/dev/null
. "$WRAP_DIR/path.sh"

DATA="${GROK_HUD_DATA:-$HOME/.grok/plugins/grok-hud}"
CONF="${DATA}/tmux.conf"

# Never exec our own shim (would recurse). Prefer the installer binary.
if [ -x "${GROK_BIN:-}" ]; then
  :
elif [ -x "$HOME/.grok/bin/grok" ]; then
  GROK_BIN="$HOME/.grok/bin/grok"
else
  GROK_BIN=""
  while IFS= read -r cand; do
    case "$cand" in
      *grok-hud*) continue ;;
    esac
    GROK_BIN=$cand
    break
  done < <(type -aP grok 2>/dev/null || true)
fi

if [ -z "${GROK_BIN}" ] || [ ! -x "${GROK_BIN}" ]; then
  echo "grok-hud: cannot find the real grok binary (expected ~/.grok/bin/grok)" >&2
  exit 127
fi

passthrough() {
  exec "$GROK_BIN" "$@"
}

case "${1:-}" in
  plugin|agent|completions|doctor|du|disk-usage|export|help|inspect|leader|login|logout|mcp|update|trace)
    passthrough "$@"
    ;;
esac

for a in "$@"; do
  case "$a" in
    -p|--single|--output-format|--json-schema|--prompt-file|--prompt-json|-h|--help|-v|--version)
      passthrough "$@"
      ;;
  esac
done

if [ "${GROK_HUD_AUTO:-1}" = "0" ]; then
  passthrough "$@"
fi

if ! command -v tmux >/dev/null 2>&1; then
  echo "grok-hud: tmux not found — running grok without HUD. Install tmux and re-run." >&2
  passthrough "$@"
fi

if [ ! -f "$CONF" ]; then
  echo "grok-hud: missing $CONF — re-run install.sh" >&2
  passthrough "$@"
fi

# Nested tmux (herdr, etc.): do not steal that server. Paint this window only.
if [ -n "${TMUX:-}" ]; then
  tmux set-option -w status on
  tmux set-option -w status-position bottom
  tmux set-option -w status-interval 1
  tmux set-option -w status-left ""
  tmux set-option -w status-right-length 240
  tmux set-option -w status-style "bg=default,fg=default"
  tmux set-option -w status-right "#(PATH=\"$PATH\" grok-hud --tmux --cwd \"#{pane_current_path}\" 2>/dev/null)"
  passthrough "$@"
fi

BG="$("$WRAP_DIR/theme-bg.sh" 2>/dev/null || echo '#0a0a0a')"
name="grok-hud-$$"
cmd=$(printf '%q ' "$GROK_BIN" "$@")
exec tmux -L grok-hud -f "$CONF" new-session -s "$name" \
  "$cmd" \; set-option -g status-style "bg=${BG},fg=default" \; set-option -g status-bg "$BG"
