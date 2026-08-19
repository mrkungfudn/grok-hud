---
description: How grok-hud attaches live (tmux under Grok, not a split pane)
argument-hint: ""
---

# /grok-hud:watch

After `install.sh`, type `grok` and the HUD appears (5 tmux lines under the TUI).

No iTerm split. You do not need `--watch` unless you want a separate pane:

```bash
grok-hud --watch --cwd "$(pwd)"
```

Disable the wrap: `GROK_HUD_AUTO=0 grok`.
