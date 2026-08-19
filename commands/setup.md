---
description: Install grok-hud (CLI + tmux wrap so HUD auto-attaches under Grok)
argument-hint: ""
---

# /grok-hud:setup

Chạy installer trong repo plugin (một lệnh, idempotent).

```bash
PLUGIN_ROOT="${GROK_PLUGIN_ROOT:-}"
if [ -z "$PLUGIN_ROOT" ] || [ ! -f "$PLUGIN_ROOT/install.sh" ]; then
  echo "Run: curl -fsSL https://raw.githubusercontent.com/mrkungfudn/grok-hud/main/install.sh | bash"
  exit 0
fi
bash "$PLUGIN_ROOT/install.sh"
```

Sau đó bảo user **mở tab mới** rồi gõ `grok`. HUD 5 dòng dưới TUI.

Tắt: `GROK_HUD_AUTO=0 grok`. Config: `~/.grok/plugins/grok-hud/config.json`.
