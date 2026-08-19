#!/usr/bin/env bash
# Print Grok TUI bg_base for the active theme (hex, no newline issues).
#
# Measured from grok 1.0.5 (ratatui RGB 0x11 R G B tables):
#   OscuraMidnight #030304 · RosePineMoon #232136 · TokyoNight #1a1b26
#   GrokDay        #f5f5f5 · GrokNight    #0a0a0a  (default)
#
# [ui] theme=auto follows the OS (dark → auto_dark_theme, light → auto_light_theme).
# /theme writes config.toml, so a 1s HUD refresh picks up light/dark switches.

set -u
CFG="${HOME}/.grok/config.toml"

read_ui() {
  python3 - "$CFG" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
text = p.read_text() if p.exists() else ""
vals = {"theme": "groknight", "auto_dark_theme": "groknight", "auto_light_theme": "grokday"}
in_ui = False
for raw in text.splitlines():
    s = raw.strip()
    if s.startswith("["):
        in_ui = s == "[ui]"
        continue
    if not in_ui or "=" not in s or s.startswith("#"):
        continue
    k, _, v = s.partition("=")
    k = k.strip()
    v = v.strip().strip('"').strip("'")
    if k in vals:
        vals[k] = v
print(vals["theme"] + "|" + vals["auto_dark_theme"] + "|" + vals["auto_light_theme"])
PY
}

os_is_dark() {
  # env first (SSH / tmux wrap), then macOS, else dark.
  case "${GROK_APPEARANCE:-${LC_GROK_APPEARANCE:-}}" in
    light|Light) return 1 ;;
    dark|Dark) return 0 ;;
  esac
  if command -v defaults >/dev/null 2>&1; then
    [ "$(defaults read -g AppleInterfaceStyle 2>/dev/null || true)" = "Dark" ]
    return $?
  fi
  return 0
}

normalize() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' _-'
}

hex_for() {
  case "$(normalize "$1")" in
    groknight|dark) echo "#0a0a0a" ;;
    grokday|light|day) echo "#f5f5f5" ;;
    tokyonight|tokyo) echo "#1a1b26" ;;
    rosepine|rosepinemoon) echo "#232136" ;;
    oscura|oscuramidnight) echo "#030304" ;;
    *) echo "#0a0a0a" ;;
  esac
}

THEME="${GROK_THEME:-${LC_GROK_THEME:-}}"
AUTO_DARK="groknight"
AUTO_LIGHT="grokday"
if [ -z "$THEME" ]; then
  _ui=$(read_ui)
  THEME="${_ui%%|*}"
  _rest="${_ui#*|}"
  AUTO_DARK="${_rest%%|*}"
  AUTO_LIGHT="${_rest#*|}"
  THEME="${THEME:-groknight}"
  AUTO_DARK="${AUTO_DARK:-groknight}"
  AUTO_LIGHT="${AUTO_LIGHT:-grokday}"
fi

case "$(normalize "$THEME")" in
  auto|system)
    if os_is_dark; then THEME="$AUTO_DARK"; else THEME="$AUTO_LIGHT"; fi
    ;;
esac

hex_for "$THEME"
