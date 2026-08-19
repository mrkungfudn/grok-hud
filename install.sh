#!/usr/bin/env bash
# grok-hud — one-command install
#
#   curl -fsSL https://raw.githubusercontent.com/mrkungfudn/grok-hud/main/install.sh | bash
#
# Needs: git, Node.js >= 18, npm, tmux, grok (https://x.ai/build)

set -euo pipefail

REPO="${GROK_HUD_REPO:-https://github.com/mrkungfudn/grok-hud.git}"
SRC="${GROK_HUD_SRC:-$HOME/.local/share/grok-hud}"
DATA="${GROK_HUD_DATA:-$HOME/.grok/plugins/grok-hud}"
MARKER_START="# >>> grok-hud >>>"
MARKER_END="# <<< grok-hud <<<"

die() { echo "grok-hud install: $*" >&2; exit 1; }
info() { echo "→ $*"; }

need() {
  command -v "$1" >/dev/null 2>&1 || die "missing \`$1\`. $2"
}

need git "Install git first."
need npm "Install Node.js >= 18 (https://nodejs.org)."
need node "Install Node.js >= 18."
need tmux "Install tmux (macOS: brew install tmux)."
need grok "Install Grok Build CLI first: https://x.ai/build"

NODE_MAJOR=$(node -p "process.versions.node.split('.')[0]" 2>/dev/null || echo 0)
if [ "$NODE_MAJOR" -lt 18 ]; then
  die "Node.js >= 18 required (found $(node -v))."
fi

# If this file lives in a checkout that already has wrap/, use that.
SELF=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SELF="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
fi
if [ -n "$SELF" ] && [ -f "$SELF/wrap/launch.sh" ]; then
  SRC=$SELF
  info "using local checkout $SRC"
else
  if [ -d "$SRC/.git" ]; then
    info "updating $SRC"
    git -C "$SRC" pull --ff-only
  else
    info "cloning $REPO → $SRC"
    mkdir -p "$(dirname "$SRC")"
    git clone --depth 1 "$REPO" "$SRC"
  fi
fi

info "building CLI"
(
  cd "$SRC"
  npm install
  npm run build
  chmod +x bin/grok-hud.js wrap/*.sh wrap/grok wrap/render.mjs 2>/dev/null || true
)

info "linking grok-hud onto PATH"
mkdir -p "$HOME/.local/bin"
ln -sfn "$SRC/bin/grok-hud.js" "$HOME/.local/bin/grok-hud"

info "installing wrap scripts → $DATA"
mkdir -p "$DATA/bin"
cp -f "$SRC/wrap/launch.sh" "$SRC/wrap/status-line.sh" "$SRC/wrap/path.sh" \
  "$SRC/wrap/tmux.conf" "$SRC/wrap/render.mjs" "$SRC/wrap/with-hud.sh" \
  "$SRC/wrap/ansi-to-tmux.py" "$DATA/"
cp -f "$SRC/wrap/grok" "$DATA/bin/grok"
chmod +x "$DATA/launch.sh" "$DATA/status-line.sh" "$DATA/bin/grok" "$DATA/render.mjs"
if [ ! -f "$DATA/config.json" ]; then
  cp "$SRC/config.example.json" "$DATA/config.json"
fi

info "registering Grok plugin"
if command -v grok >/dev/null 2>&1; then
  grok plugin install "$SRC" --trust 2>/dev/null || grok plugin update grok-hud 2>/dev/null || true
  grok plugin enable grok-hud 2>/dev/null || true
fi

hook_rc() {
  local rc=$1
  [ -f "$rc" ] || return 0
  if grep -q "$MARKER_START" "$rc" 2>/dev/null; then
    info "shell hook already in $rc"
    return 0
  fi
  info "adding shell hook → $rc"
  cat >>"$rc" <<EOF

$MARKER_START
export PATH="\$HOME/.grok/plugins/grok-hud/bin:\$HOME/.local/bin:\$PATH"
[ -r "\$HOME/.grok/plugins/grok-hud/with-hud.sh" ] && . "\$HOME/.grok/plugins/grok-hud/with-hud.sh"
$MARKER_END
EOF
}

hook_rc "$HOME/.zshrc"
hook_rc "$HOME/.bashrc"

echo
echo "Installed."
echo
echo "  New terminal tab, then:"
echo "    grok"
echo
echo "  HUD is 5 colored lines under the TUI (tmux, same window)."
echo "  Disable:  GROK_HUD_AUTO=0 grok"
echo "  Config:   ~/.grok/plugins/grok-hud/config.json"
echo
echo "  If \`grok\` still has no HUD, this tab is an old shell:"
echo "    source ~/.zshrc && grok"
