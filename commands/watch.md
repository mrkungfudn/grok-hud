---
description: How grok-hud attaches live (tmux under Grok, not a split pane)
argument-hint: ""
---

# /grok-hud:watch

Sau `install.sh`, gõ `grok` là HUD tự hiện (5 dòng tmux dưới TUI).

Không tách pane iTerm. Không cần `--watch` trừ khi muốn pane riêng:

```bash
grok-hud --watch --cwd "$(pwd)"
```

Tắt wrap: `GROK_HUD_AUTO=0 grok`.
