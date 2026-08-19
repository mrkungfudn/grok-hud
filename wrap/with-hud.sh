# Source from ~/.zshrc or ~/.bashrc after install.
# Disable: GROK_HUD_AUTO=0
# Interactive `grok` → launch.sh (5-line tmux HUD, including inside herdr).
grok() {
  "$HOME/.grok/plugins/grok-hud/launch.sh" "$@"
}
