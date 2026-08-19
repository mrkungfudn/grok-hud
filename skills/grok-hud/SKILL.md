---
name: grok-hud
description: >-
  Status HUD for Grok sessions (context tokens, model, git, usage, recent tools).
  Auto-attaches under the TUI via tmux after install.sh.
when-to-use: >-
  User mentions grok-hud, statusline, HUD, context %, token usage meter, or
  wants a live footer under Grok.
argument-hint: "[setup | status | watch | configure]"
---

# grok-hud

Grok không có statusLine API. Plugin này:

1. CLI `grok-hud` đọc `~/.grok/sessions/**/signals.json`
2. `install.sh` bọc lệnh `grok` bằng tmux socket riêng, vẽ 5 dòng HUD dưới TUI

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/mrkungfudn/grok-hud/main/install.sh | bash
```

Rồi tab mới, gõ `grok`.

## Routes

| Ý | Làm |
|---|---|
| Cài / sửa | `/grok-hud:setup` hoặc `install.sh` |
| Snapshot | `grok-hud --once` |
| Tắt HUD | `GROK_HUD_AUTO=0 grok` |
| Config | `~/.grok/plugins/grok-hud/config.json` |
| Credits | builtin `/usage` |
| Context in-TUI | builtin `/context` |
