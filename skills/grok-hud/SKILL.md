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

Grok has no statusLine API. This plugin:

1. CLI `grok-hud` reads `~/.grok/sessions/**/signals.json` and live `updates.jsonl`
2. `install.sh` wraps `grok` in an isolated tmux socket and paints a 5-line HUD under the TUI

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/mrkungfudn/grok-hud/main/install.sh | bash
```

Then a **new tab**, type `grok`.

## Routes

| Intent | Do |
|---|---|
| Install / repair | `/grok-hud:setup` or `install.sh` |
| Snapshot | `grok-hud --once` |
| Disable HUD | `GROK_HUD_AUTO=0 grok` |
| Config | `~/.grok/plugins/grok-hud/config.json` |
| Credits | builtin `/usage` |
| Context in-TUI | builtin `/context` |
