#!/usr/bin/env bash
# grok-hud — one-command install
#
#   curl -fsSL https://raw.githubusercontent.com/mrkungfudn/grok-hud/main/install.sh | bash
#
# Installs anything missing: Git, Node.js ≥ 18, tmux, Grok CLI, then the HUD wrap.
# Official Grok CLI: https://x.ai/cli/install.sh  (https://x.ai/build)

set -euo pipefail

REPO="${GROK_HUD_REPO:-https://github.com/mrkungfudn/grok-hud.git}"
SRC="${GROK_HUD_SRC:-$HOME/.local/share/grok-hud}"
DATA="${GROK_HUD_DATA:-$HOME/.grok/plugins/grok-hud}"
MARKER_START="# >>> grok-hud >>>"
MARKER_END="# <<< grok-hud <<<"
GROK_CLI_INSTALL="${GROK_CLI_INSTALL:-https://x.ai/cli/install.sh}"
NVM_INSTALL="${NVM_INSTALL:-https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh}"
BREW_INSTALL="${BREW_INSTALL:-https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh}"

# HUD palette (truecolor). Fall back to 16-color when stdout is not a TTY
# (CI) so `curl | bash` on a real terminal still gets the banner.
if [ -t 1 ]; then
  C_CYAN=$'\033[38;2;34;211;238m'
  C_GOLD=$'\033[38;2;250;204;21m'
  C_GREEN=$'\033[38;2;74;222;128m'
  C_RED=$'\033[38;2;248;113;113m'
  C_DIM=$'\033[2m'
  C_BOLD=$'\033[1m'
  C_RESET=$'\033[0m'
else
  C_CYAN="" C_GOLD="" C_GREEN="" C_RED="" C_DIM="" C_BOLD="" C_RESET=""
fi

die()  { printf '%s%s grok-hud install:%s %s\n' "$C_RED" "$C_BOLD" "$C_RESET" "$*" >&2; exit 1; }
info() { printf '%s→%s %s\n' "$C_CYAN" "$C_RESET" "$*"; }
ok()   { printf '%s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s!%s %s\n' "$C_GOLD" "$C_RESET" "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

cols() { tput cols 2>/dev/null || echo "${COLUMNS:-80}"; }

banner() {
  printf '\n  %s%s grok-hud%s  %s5-line status HUD under the Grok TUI%s\n' \
    "$C_BOLD" "$C_CYAN" "$C_RESET" "$C_DIM" "$C_RESET"
  printf '\n'
  # Merlin1 (patorjk) of XCLOUDPHONE.COM — ~185 cols; skip on narrow terms
  # so the banner does not wrap into noise.
  if [ "$(cols)" -ge 160 ]; then
    printf '%s' "$C_GOLD"
    cat <<'EOF'
 ___  ___    ______    ___           ______     ____  ____   ________      _______     __    __       ______     _____  ___     _______             ______       ______     ___      ___
|"  \/"  |  /" _  "\  |"  |         /    " \   ("  _||_ " | |"      "\    |   __ "\   /" |  | "\     /    " \   (\"   \|"  \   /"     "|           /" _  "\     /    " \   |"  \    /"  |
 \   \  /  (: ( \___) ||  |        // ____  \  |   (  ) : | (.  ___  :)   (. |__) :) (:  (__)  :)   // ____  \  |.\\   \    | (: ______)          (: ( \___)   // ____  \   \   \  //   |
  \\  \/    \/ \      |:  |       /  /    ) :) (:  |  | . ) |: \   ) ||   |:  ____/   \/      \/   /  /    ) :) |: \.   \\  |  \/    |             \/ \       /  /    ) :)  /\\  \/.    |
  /\.  \    //  \ _    \  |___   (: (____/ //   \\ \__/ //  (| (___\ ||   (|  /       //  __  \\  (: (____/ //  |.  \    \. |  // ___)_    _____   //  \ _   (: (____/ //  |: \.        |
 /  \   \  (:   _) \  ( \_|:  \   \        /    /\\ __ //\  |:       :)  /|__/ \     (:  (  )  :)  \        /   |    \    \ | (:      "|  ))_  ") (:   _) \   \        /   |.  \    /:  |
|___/\___|  \_______)  \_______)   \"_____/    (__________) (________/  (_______)     \__|  |__/    \"_____/     \___|\____\)  \_______) (_____(   \_______)   \"_____/    |___|\__/|___|
EOF
    printf '%s' "$C_RESET"
  fi
  printf '  %sSponsored by%s %sXCloudPhone.com%s  ·  real cloud phones for mobile gaming\n' \
    "$C_DIM" "$C_RESET" "$C_GOLD" "$C_RESET"
  printf '  %shttps://xcloudphone.com%s\n\n' "$C_CYAN" "$C_RESET"
}

is_mac()   { [ "$(uname -s)" = Darwin ]; }
is_linux() { [ "$(uname -s)" = Linux ]; }

# Put Homebrew on PATH after a fresh install (Apple Silicon vs Intel).
load_brew() {
  if have brew; then return 0; fi
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  have brew
}

ensure_brew() {
  load_brew && return 0
  is_mac || return 1
  info "Homebrew not found — installing (needed for git / node / tmux)"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL "$BREW_INSTALL")"
  load_brew || die "Homebrew installed but not on PATH. Open a new tab and re-run."
}

# Distro package. macOS always goes through brew.
pkg_install() {
  local pkg=$1
  if is_mac; then
    ensure_brew || die "cannot install $pkg without Homebrew"
    brew install "$pkg"
  elif have apt-get; then
    sudo apt-get update -y
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
  elif have dnf; then
    sudo dnf install -y "$pkg"
  elif have pacman; then
    sudo pacman -S --noconfirm "$pkg"
  else
    die "cannot auto-install \`$pkg\` (no brew / apt / dnf / pacman)"
  fi
}

ensure_git() {
  if have git; then ok "git $(git --version | awk '{print $3}')"; return 0; fi
  info "installing git"
  pkg_install git
  have git || die "git still missing after install"
  ok "git installed"
}

node_major() {
  have node || { echo 0; return; }
  node -p "parseInt(process.versions.node.split('.')[0],10)" 2>/dev/null || echo 0
}

# nvm is the Linux fallback when distro Node is missing or older than 18.
ensure_nvm_node() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    info "installing nvm (Node.js ≥ 18)"
    curl -fsSL "$NVM_INSTALL" | bash
  fi
  # shellcheck source=/dev/null
  . "$NVM_DIR/nvm.sh"
  nvm install 22
  nvm use 22
}

ensure_node() {
  local major
  major=$(node_major)
  if [ "$major" -ge 18 ] && have npm; then
    ok "node $(node -v) · npm $(npm -v | head -1)"
    return 0
  fi
  if [ "$major" -gt 0 ] && [ "$major" -lt 18 ]; then
    warn "Node $(node -v) is too old (need ≥ 18) — upgrading"
  else
    info "installing Node.js ≥ 18"
  fi
  if is_mac; then
    ensure_brew || die "cannot install Node without Homebrew"
    brew install node
    load_brew
  elif have apt-get || have dnf || have pacman; then
    # Distro nodejs is often 12–16. Prefer nvm so we land on 22 without
    # fighting the package manager.
    ensure_nvm_node
  else
    ensure_nvm_node
  fi
  major=$(node_major)
  [ "$major" -ge 18 ] && have npm || die "Node.js ≥ 18 still missing (found $(node -v 2>/dev/null || echo none))"
  ok "node $(node -v) · npm $(npm -v | head -1)"
}

ensure_tmux() {
  if have tmux; then ok "tmux $(tmux -V)"; return 0; fi
  info "installing tmux"
  pkg_install tmux
  have tmux || die "tmux still missing after install"
  ok "tmux installed"
}

# Real Grok binary, not this repo's PATH shim (which also names itself grok).
real_grok() {
  if [ -x "$HOME/.grok/bin/grok" ]; then
    echo "$HOME/.grok/bin/grok"
    return 0
  fi
  local cand
  while IFS= read -r cand; do
    case "$cand" in
      *grok-hud*) continue ;;
    esac
    if [ -x "$cand" ]; then echo "$cand"; return 0; fi
  done < <(type -aP grok 2>/dev/null || true)
  return 1
}

ensure_grok() {
  if real_grok >/dev/null; then
    ok "Grok CLI $(real_grok)"
    return 0
  fi
  info "installing Grok CLI from x.ai"
  curl -fsSL "$GROK_CLI_INSTALL" | bash
  export PATH="$HOME/.grok/bin:$HOME/.local/bin:$PATH"
  real_grok >/dev/null || die "Grok CLI still missing. Install from https://x.ai/build and re-run."
  ok "Grok CLI $(real_grok)"
}

banner

have curl || die "curl is required to download installers"
ensure_git
ensure_node
ensure_tmux
ensure_grok

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
  "$SRC/wrap/tmux.conf" "$SRC/wrap/render.mjs" \
  "$SRC/wrap/ansi-to-tmux.py" "$SRC/wrap/theme-bg.sh" "$DATA/"
cp -f "$SRC/wrap/grok" "$DATA/bin/grok"
cp -f "$SRC/wrap/with-hud.sh" "$DATA/with-hud.sh"
cp -f "$SRC/wrap/with-hud.zsh" "$DATA/with-hud.zsh" 2>/dev/null || cp -f "$SRC/wrap/with-hud.sh" "$DATA/with-hud.zsh"
chmod +x "$DATA/launch.sh" "$DATA/status-line.sh" "$DATA/bin/grok" "$DATA/render.mjs" "$DATA/theme-bg.sh"
# herdr `agent start --kind grok` execs PATH `grok`, not the zsh function.
# Grok's installer points ~/.local/bin/grok at the real binary — that skips
# the HUD wrap. Real binary stays ~/.grok/bin/grok; this link is the wrap.
ln -sfn "$DATA/bin/grok" "$HOME/.local/bin/grok"
if [ ! -f "$DATA/config.json" ]; then
  cp "$SRC/config.example.json" "$DATA/config.json"
fi

info "registering Grok plugin"
# Call the REAL binary: PATH grok is now the wrap, and `plugin` passthrough
# works, but during first install GROK_BIN is safer.
if [ -x "$HOME/.grok/bin/grok" ]; then
  "$HOME/.grok/bin/grok" plugin install "$SRC" --trust 2>/dev/null \
    || "$HOME/.grok/bin/grok" plugin update grok-hud 2>/dev/null \
    || true
  "$HOME/.grok/bin/grok" plugin enable grok-hud 2>/dev/null || true
fi

hook_rc() {
  local rc=$1
  [ -f "$rc" ] || return 0
  # Marker, or an older hand-written PATH line (pre-marker installs).
  if grep -q "$MARKER_START" "$rc" 2>/dev/null \
    || grep -q 'grok-hud/bin' "$rc" 2>/dev/null; then
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

printf '\n%s✓ Installed.%s\n\n' "$C_GREEN" "$C_RESET"
printf '  New terminal tab, then:\n'
printf '    %sgrok%s\n\n' "$C_CYAN" "$C_RESET"
printf '  HUD is 5 colored lines under the TUI (tmux, same window).\n'
printf '  Works inside herdr too (new tab, or: herdr agent start --kind grok).\n'
printf '  Disable:  %sGROK_HUD_AUTO=0 grok%s\n' "$C_GOLD" "$C_RESET"
printf '  Config:   ~/.grok/plugins/grok-hud/config.json\n'
printf '\n'
printf '  If `grok` still has no HUD, this tab is an old shell:\n'
printf '    source ~/.zshrc && grok\n'
printf '\n  %sSponsored by%s %shttps://xcloudphone.com%s\n\n' "$C_DIM" "$C_RESET" "$C_GOLD" "$C_RESET"
