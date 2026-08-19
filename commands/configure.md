---
description: Configure grok-hud display options (language, layout, thresholds, colors)
argument-hint: "[language=en|zh] [layout=expanded|compact]"
---

# /grok-hud:configure

Edit `~/.grok/plugins/grok-hud/config.json` (create it with `grok-hud --init-config` if missing).

| Pref | JSON path | Values |
|------|-----------|--------|
| language | `language` | `en`, `zh` |
| layout | `lineLayout` | `expanded`, `compact` |
| path depth | `pathLevels` | `1`, `2`, `3` |
| tools line | `display.showTools` | `true` / `false` |
| context format | `display.contextValue` | `percent`, `tokens`, `remaining`, `both` |
| warn / critical | `display.warningThreshold` / `criticalThreshold` | 0–100 |
| colors | `colors.*` | named (`cyan`) or hex (`#22d3ee`) |

Preview:

```bash
grok-hud --once
```

Full docs: https://github.com/mrkungfudn/grok-hud
