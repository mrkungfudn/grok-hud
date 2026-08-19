# grok-hud

A **5-line status HUD** under the Grok TUI: model, git, context, weekly credits, and recent tools.

Grok has no `statusLine` API. This attaches the HUD with tmux in the **same window** (no split pane).

![grok-hud under the Grok TUI](grok-hud-preview.png)

```
Tungs-MacBook-Pro │ orchestrator main* 1Δ
[Grok 4.6 ◑ high] │ plan │ Install grok-hud… │ ● live │ v1.0.5 │ always-approve
Context ██████░░░░ 63% (318k/500k) │ Time 2h 6m │ Turns 14 │ Tools 259 │ Files 37 │ Lines +1400 -464
Usage ███░░░░░░░ 33% (weekly) · resets 3d │ err 10
◐ run_terminal_command … | ✓ read_file | ✓ run_terminal_command ×2
```

| Line | What you see |
|------|----------------|
| 1 | hostname · repo · branch* · dirty files |
| 2 | `[model ◑ effort]` · plan/ask · session title · live · version · permission |
| 3 | context bar % tokens · time · turns · tools · files · lines +/- |
| 4 | weekly usage · reset countdown · sandbox · compact · errors |
| 5 | recent tools |

Colors come from one palette in `config.json` (hex). Context bar, `● live`, `+lines`, and `✓` share the same green; warnings share the same gold; errors share the same red.

## Install (one command)

Needs **Grok CLI**, **Node.js ≥ 18**, **tmux**, and **git**.

```bash
curl -fsSL https://raw.githubusercontent.com/mrkungfudn/grok-hud/main/install.sh | bash
```

Open a **new terminal tab**, then run `grok`. The HUD sits at the bottom.

macOS without tmux:

```bash
brew install tmux
```

To update, run the same `curl … | bash` again.

## Usage

| | |
|---|---|
| Show HUD | `grok` (new tab, or `source ~/.zshrc`) |
| Disable HUD | `GROK_HUD_AUTO=0 grok` |
| Bare Grok binary | `~/.grok/bin/grok` |
| Colors / fields | `~/.grok/plugins/grok-hud/config.json` |
| One-shot snapshot | `grok-hud` |
| JSON | `grok-hud --json` |

## Uninstall

```bash
# 1) Delete the # >>> grok-hud >>> … # <<< grok-hud <<< block in ~/.zshrc and ~/.bashrc
# 2) Plugin
grok plugin uninstall grok-hud --confirm

# 3) Files
rm -rf ~/.grok/plugins/grok-hud ~/.local/share/grok-hud ~/.local/bin/grok-hud
```

## Development

```bash
git clone git@github.com:mrkungfudn/grok-hud.git
cd grok-hud
npm install
npm run build
bash install.sh
```

See [`config.example.json`](config.example.json) for every option.

## License

MIT. Copyright (c) 2026 mrkungfudn.
