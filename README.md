# grok-hud

[English](README.md) · [Tiếng Việt](README.vi.md)

```
                     __         __              __
   ____ __________  / /__      / /_  __  ______/ /
  / __ `/ ___/ __ \/ //_/_____/ __ \/ / / / __  /
 / /_/ / /  / /_/ / ,< /_____/ / / / /_/ / /_/ /
 \__, /_/   \____/_/|_|     /_/ /_/\__,_/\__,_/
/____/
```

A **5-line status HUD** under the Grok TUI: model, git, context, weekly credits, and recent tools.

Grok has no `statusLine` API. This attaches the HUD with tmux in the **same window** (no split pane).

## Sponsored by [XCloudPhone.com](https://xcloudphone.com)

<p align="center">
  <a href="https://xcloudphone.com">
    <img src="assets/xcloudphone-logo-dark.svg#gh-light-mode-only" alt="XCloudPhone" height="48">
    <img src="assets/xcloudphone-logo-light.svg#gh-dark-mode-only" alt="XCloudPhone" height="48">
  </a>
</p>

```
 ___  ___    ______    ___           ______     ____  ____   ________      _______     __    __       ______     _____  ___     _______             ______       ______     ___      ___
|"  \/"  |  /" _  "\  |"  |         /    " \   ("  _||_ " | |"      "\    |   __ "\   /" |  | "\     /    " \   (\"   \|"  \   /"     "|           /" _  "\     /    " \   |"  \    /"  |
 \   \  /  (: ( \___) ||  |        // ____  \  |   (  ) : | (.  ___  :)   (. |__) :) (:  (__)  :)   // ____  \  |.\\   \    | (: ______)          (: ( \___)   // ____  \   \   \  //   |
  \\  \/    \/ \      |:  |       /  /    ) :) (:  |  | . ) |: \   ) ||   |:  ____/   \/      \/   /  /    ) :) |: \.   \\  |  \/    |             \/ \       /  /    ) :)  /\\  \/.    |
  /\.  \    //  \ _    \  |___   (: (____/ //   \\ \__/ //  (| (___\ ||   (|  /       //  __  \\  (: (____/ //  |.  \    \. |  // ___)_    _____   //  \ _   (: (____/ //  |: \.        |
 /  \   \  (:   _) \  ( \_|:  \   \        /    /\\ __ //\  |:       :)  /|__/ \     (:  (  )  :)  \        /   |    \    \ | (:      "|  ))_  ") (:   _) \   \        /   |.  \    /:  |
|___/\___|  \_______)  \_______)   \"_____/    (__________) (________/  (_______)     \__|  |__/    \"_____/     \___|\____\)  \_______) (_____(   \_______)   \"_____/    |___|\__/|___|
```

**Real cloud phones for mobile gaming** — not an emulator, not a VPS. Rent a real Android handset in the cloud and play / farm 24/7.

→ [xcloudphone.com](https://xcloudphone.com)

---

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

The context bar follows Grok's live meter (`params._meta.totalTokens` in `updates.jsonl`), not the turn-end snapshot in `signals.json`. Tmux refreshes it about once a second.

## Install (one command)

```bash
curl -fsSL https://raw.githubusercontent.com/mrkungfudn/grok-hud/main/install.sh | bash
```

The installer **installs anything missing**: Git, Node.js ≥ 18, tmux, and the [Grok CLI](https://x.ai/build) (`curl -fsSL https://x.ai/cli/install.sh | bash`). On macOS it uses Homebrew (and installs Homebrew if needed). On Linux it uses apt / dnf / pacman, or nvm for Node.

Open a **new terminal tab**, then run `grok`. The HUD sits at the bottom.

Works inside **herdr** the same way (`herdr agent start --kind grok`, or type `grok` in a new herdr tab). Herdr is not tmux; grok-hud still wraps Grok in an isolated `tmux -L grok-hud` so the 5-line footer matches a normal tab. Use a **new** herdr tab after install — an old pane still has the unwrapped `grok` on PATH.

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
# Restore the real Grok CLI on PATH (installer had retargeted this to the HUD wrap):
ln -sfn "$HOME/.grok/bin/grok" "$HOME/.local/bin/grok"
```

## Development

```bash
git clone git@github.com:mrkungfudn/grok-hud.git
cd grok-hud
npm install
npm run build
bash install.sh
```

See [`config.example.json`](config.example.json) for every option. Agent notes: [`AGENTS.md`](AGENTS.md).

## License

MIT. Copyright (c) 2026 mrkungfudn.
