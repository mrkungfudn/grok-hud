# grok-hud — agent notes

English is the default language of this repo. Vietnamese lives only in [`README.vi.md`](README.vi.md).

## What this is

A 5-line status HUD under the Grok TUI (model, git, context, weekly credits, recent tools).

Grok has **no `statusLine` API**. Do not look for a Claude-style hook. The HUD is tmux status rows on an isolated socket `tmux -L grok-hud`.

## Layout

```
wrap/launch.sh      # `grok` → isolated tmux + real ~/.grok/bin/grok
wrap/tmux.conf      # status 5, theme background, OSC title passthrough
wrap/render.mjs     # 5-line Claude-like snapshot (hex palette, live tokens)
wrap/status-line.sh # tmux status-format[N] → render.mjs (1s cache per pane pid)
wrap/theme-bg.sh    # GrokNight / GrokDay / TokyoNight / auto → bg hex
src/                # grok-hud CLI (signals.json + updates.jsonl + git + usage)
install.sh          # one-command: missing deps + clone + build + wrap + zshrc
```

## Rules that have already burned us

1. **Never iTerm split / never `tmux split-window` for the HUD.** SIGWINCH makes the Grok TUI jump. Status rows only.
2. **Never attach to the caller's tmux server.** Always `-L grok-hud`. Herdr is *not* tmux (`TMUX` is unset in a herdr pane) — still wrap in `tmux -L grok-hud`.
3. **Already inside `*grok-hud*` → passthrough.** Nesting the HUD socket recourses.
4. **Live context = last `_meta.totalTokens` in `updates.jsonl`**, not `signals.json` (turn-end only, also lags auto-compact). Regex the tail; `JSON.parse` per line fails on huge `tool_call_update` rows. LAST sane value ≤ 2M, not MAX. **Must match `_meta":{"totalTokens":N`** — a bare `"totalTokens":N` also appears in nested API `usage` inside tool output (1.2M input+output vs real ~250k → HUD painted 245% of a 500k window).
5. **When tmux passes `#{pane_pid}`, never fall back to another live session.** A herdr splash used to steal this conversation's 300k bar.
6. **`herdr agent start --kind grok` execs PATH `grok`, not the zsh function.** `~/.local/bin/grok` must be the wrap; real binary stays `~/.grok/bin/grok`. Report the pane as grok with pane-id *first*: `herdr pane report-agent "$HERDR_PANE_ID" --source grok-hud --agent grok --state idle`. `exec -a grok tmux …` so argv0 still matches.
7. **HUD background follows the Grok theme**, not iTerm `#282a36` and not a hardcoded `#000000`. `theme-bg.sh` maps groknight / grokday / tokyonight / auto.
8. **tmux status ignores raw ANSI.** `render.mjs` converts to `#[fg=#rrggbb]` when `GROK_HUD_TMUX=1`.

## Install / verify

```bash
bash install.sh          # from a checkout, or: curl …/install.sh | bash
# new tab
grok                     # 5-line footer, not a split
GROK_HUD_AUTO=0 grok     # bare TUI
```

Missing Git / Node ≥ 18 / tmux / Grok CLI: `install.sh` installs them (Homebrew on macOS, apt/dnf/pacman or nvm on Linux, Grok via `https://x.ai/cli/install.sh`).

## Commands & skill

Grok plugin commands under `commands/`: `setup`, `status`, `watch`, `configure`. Skill: `skills/grok-hud/SKILL.md`.

## Don't

- Don't commit `.env` or session dumps.
- Don't `tmux kill-server` on the default socket — other tools (herdr) use other sockets, but the HUD socket is fair game only for HUD sessions.
- Don't restore `~/.local/bin/grok` to the real binary while the wrap is supposed to be on PATH; `install.sh` retargets that link on purpose.
