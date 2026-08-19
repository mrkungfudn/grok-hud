# grok-hud

Thanh trạng thái 5 dòng **dưới TUI Grok**: model, git, context, quota tuần, tool đang chạy. Grok không có `statusLine` API — HUD gắn bằng tmux, cùng một cửa sổ, không tách pane.

## Cài (một lệnh)

Cần sẵn: **Grok CLI**, **Node.js ≥ 18**, **tmux**, **git**.

```bash
curl -fsSL https://raw.githubusercontent.com/mrkungfudn/grok-hud/main/install.sh | bash
```

Mở **tab terminal mới**, gõ `grok`. HUD nằm dưới cùng.

macOS chưa có tmux:

```bash
brew install tmux
```

Cài lại / cập nhật: chạy đúng lệnh `curl … | bash` ở trên.

## Sau khi cài

| | |
|---|---|
| Bật HUD | gõ `grok` (tab mới, hoặc `source ~/.zshrc`) |
| Tắt HUD | `GROK_HUD_AUTO=0 grok` |
| Binary Grok trần | `~/.grok/bin/grok` |
| Sửa màu / field | `~/.grok/plugins/grok-hud/config.json` |
| Snapshot 1 lần | `grok-hud` |
| JSON | `grok-hud --json` |

## Năm dòng trên HUD

1. hostname · repo · branch* · số file bẩn
2. `[Grok 4.6 ◑ high]` · plan/ask · tên phiên · live · version · permission
3. Context bar % token · Time · Turns · Tools · Files · Lines +/-
4. Usage weekly · resets · sandbox · compact · err
5. tool gần nhất

## Gỡ

```bash
# 1) Xóa khối # >>> grok-hud >>> … # <<< grok-hud <<< trong ~/.zshrc và ~/.bashrc
# 2) Plugin
grok plugin uninstall grok-hud --confirm

# 3) File
rm -rf ~/.grok/plugins/grok-hud ~/.local/share/grok-hud ~/.local/bin/grok-hud
```

## Dev

```bash
git clone git@github.com:mrkungfudn/grok-hud.git
cd grok-hud
npm install
npm run build
bash install.sh
```

Config mẫu: [`config.example.json`](config.example.json).

## License

MIT. Copyright (c) 2026 mrkungfudn.
