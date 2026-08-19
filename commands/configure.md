---
description: Configure grok-hud display options (language, layout, thresholds, colors)
argument-hint: "[language=en|zh] [layout=expanded|compact]"
---

# /grok-hud:configure

Sửa `~/.grok/plugins/grok-hud/config.json` (tạo bằng `grok-hud --init-config` nếu thiếu).

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

Tài liệu đầy đủ: https://github.com/mrkungfudn/grok-hud
