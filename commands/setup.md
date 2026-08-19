---
description: Install grok-hud (CLI + tmux wrap so HUD auto-attaches under Grok)
argument-hint: ""
---

# /grok-hud:setup

Run the plugin installer (one command, idempotent). It also installs missing Git, Node.js ≥ 18, tmux, and the Grok CLI.

```bash
PLUGIN_ROOT="${GROK_PLUGIN_ROOT:-}"
if [ -z "$PLUGIN_ROOT" ] || [ ! -f "$PLUGIN_ROOT/install.sh" ]; then
  echo "Run: curl -fsSL https://raw.githubusercontent.com/mrkungfudn/grok-hud/main/install.sh | bash"
  exit 0
fi
bash "$PLUGIN_ROOT/install.sh"
```

Then tell the user to **open a new tab** and run `grok`. HUD is 5 lines under the TUI.

Disable: `GROK_HUD_AUTO=0 grok`. Config: `~/.grok/plugins/grok-hud/config.json`.
