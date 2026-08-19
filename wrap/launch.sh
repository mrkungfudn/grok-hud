#!/usr/bin/env bash
# Wrap interactive `grok` in an isolated tmux socket so a 5-line HUD sits
# under the TUI. Grok has no statusLine hook; tmux status rows are the footer.
# Repo language is English (Vietnamese lives in README.vi.md only).
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

# Already inside the HUD socket — nesting again would recurse.
case "${TMUX:-}" in
  *grok-hud*) passthrough "$@" ;;
esac

# Herdr is its own multiplexer ($TMUX is unset in a herdr pane). We still wrap
# Grok in `tmux -L grok-hud` so the 5-line footer matches iTerm. The pane's
# real process is tmux — `agent start --kind grok` then times out unless we
# report the pane as grok (and `exec -a grok` so argv0 still matches).
if [ -n "${HERDR_PANE_ID:-}" ] && command -v herdr >/dev/null 2>&1; then
  # Pane id MUST come first — `herdr pane report-agent --source X` parses X as a flag.
  herdr pane report-agent "$HERDR_PANE_ID" --source grok-hud --agent grok --state idle >/dev/null 2>&1 || true
fi

BG="$("$WRAP_DIR/theme-bg.sh" 2>/dev/null || echo '#0a0a0a')"
name="grok-hud-$$"
cmd=$(printf '%q ' "$GROK_BIN" "$@")
# Isolated socket — never touch herdr / an outer tmux. `env -u TMUX` is
# required when the caller is already tmux ("sessions should be nested with
# care"); herdr has TMUX unset so this is a no-op there.
# argv0=grok so herdr process detection still matches if report-agent races.
unset TMUX
exec -a grok tmux -L grok-hud -f "$CONF" new-session -s "$name" \
  "$cmd" \; set-option -g status-style "bg=${BG},fg=default" \; set-option -g status-bg "$BG"
