# grok-hud — agent notes

English is the default language of this repo. Vietnamese lives only in [`README.vi.md`](README.vi.md).

## Version bump is mandatory

**Every shipped change bumps the version in the same commit.** Do not pile HUD fixes, wrap fixes, README, or installer work under the same number (0.2.0 sat through theme, live tokens, herdr, docs, ASCII, and the 245% bug before anyone bumped).

| Change | Bump |
|---|---|
| Bug fix, copy, docs, installer, skill | **patch** (`0.2.1` → `0.2.2`) |
| New HUD line / feature / breaking wrap behavior | **minor** (`0.2.2` → `0.3.0`) |

Touch all four in that commit:

- `package.json`
- `package-lock.json` (the two `"version"` fields on the root package)
- `plugin.json`
- `.grok-plugin/plugin.json`

GitHub's file list shows the **last commit subject per file**. After a bump, leftover files still showing an old Vietnamese subject need to be in that same commit (or they keep lying on github.com).

Current version: **0.2.4**.

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
5. **When tmux passes `#{pane_pid}`, never fall back to another live session.** A herdr splash used to steal this conversation's 300k bar. **And do not stub 0% just because `active_sessions.json` pid is stale** — Grok often lists the same old pid on 4 sessions while the herdr pane is a different grok. Resolve the session id with `lsof -p <pane_pid>` on `~/.grok/sessions/`.
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

## Updating the Grok CLI (not grok-hud)

The HUD `v1.0.x` on line 2 is Grok Build, read from `~/.grok/version.json`. That is **not** this repo's version.

Always call the **real** binary. `grok` on PATH is the HUD wrap; `~/.local/bin/grok` is also the wrap. Grok's own updater may retarget that link — `install.sh` puts the wrap back.

```bash
~/.grok/bin/grok --version
~/.grok/bin/grok update --check          # stable
~/.grok/bin/grok update                  # install latest on the current channel
~/.grok/bin/grok update --alpha          # alpha (faster, may have bugs)
~/.grok/bin/grok update --stable         # back to weekly stable
```

🔴 **`--check --alpha` already switches `channel` in `~/.grok/config.toml`.** Measured 20/08/2026: `--check --alpha` flipped the machine to alpha before anyone installed. Do not probe alpha unless you mean to stay there.

Measured same day:

| Channel | Latest | Notes |
|---|---|---|
| stable | **1.0.5** (15/08/2026) | [x.ai/build/changelog](https://x.ai/build/changelog) |
| alpha | **1.0.7** | 1.0.6 never showed on the public stable changelog |

After `grok update`, **open a new tab**. The running process keeps the old binary in memory; HUD `v…` only changes on a new `grok`.

## Commands & skill

Grok plugin commands under `commands/`: `setup`, `status`, `watch`, `configure`. Skill: `skills/grok-hud/SKILL.md`.

## Don't

- Don't commit `.env` or session dumps.
- Don't `tmux kill-server` on the default socket — other tools (herdr) use other sockets, but the HUD socket is fair game only for HUD sessions.
- Don't restore `~/.local/bin/grok` to the real binary while the wrap is supposed to be on PATH; `install.sh` retargets that link on purpose.
- Don't ship a fix without a version bump (see **Version bump is mandatory**).
- Don't run `grok update --check --alpha` "just to look" — it switches the channel.
