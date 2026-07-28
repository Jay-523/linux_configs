# kanata_config

Keyboard config-as-code for Linux (Ubuntu 24.04, GNOME/Wayland), replacing my old
macOS Karabiner Elements setup (`Jay-523/karabiner_scripts`).

**Tool:** [kanata](https://github.com/jtroo/kanata) — a QMK-style software remapper that
works at the evdev/uinput level, so it is display-server agnostic (works on Wayland).

## Files
- `kanata.kbd` — the config (single source of truth). Edit this, then restart the service.
- `kanata.service` — systemd unit (runs kanata as root at boot, incl. the login screen).
- `41-kanata-uinput.rules` — optional udev rule to run kanata without sudo (non-root).

## Install
```bash
# 1. Binary already at ~/.local/bin/kanata  (kanata 1.11.0, from GitHub releases)

# 2. Load uinput now + at every boot
sudo modprobe uinput
echo uinput | sudo tee /etc/modules-load.d/uinput.conf

# 3. Install + enable the service
sudo cp kanata.service /etc/systemd/system/kanata.service
sudo systemctl daemon-reload
sudo systemctl enable --now kanata.service
```

## Validate / test a config change
```bash
kanata --cfg kanata.kbd --check      # syntax check
sudo systemctl restart kanata.service
systemctl status kanata.service
```

## Modifier scheme (mirrors macOS)
| Key | Role |
|-----|------|
| **Left Alt = ⌘ Command** | `⌘+letter/digit` -> `Ctrl+<same>` (⌘C/V/A/L/T/W/Z/S/F/1-9...). `⌘←/→` line start/end, `⌘↑/↓` doc top/bottom, `⌘[ ]` browser back/fwd, `⌘Tab` Alt+Tab. `⌘⇧<key>` stacks (⌘⇧Z redo). |
| **Ctrl (hold)** | `Ctrl+hjkl` = arrows; `+Shift` selects; `+Super` line/doc motion. Tap Ctrl = Escape. |
| **Right Alt = ⌥ Option** | stays a real Alt (Alt+Tab cycle, menus). `⌥+hjkl` = word/line motion; `⌥D` delete word. |
| **Caps Lock** | Hyper (Ctrl+Shift+Alt+Super) when held |
| **Right Shift** | tap = right-click, hold = Shift |
| **Physical Escape** | left mouse click |

> Note: the ⌘ layer is **not app-aware**. In a terminal `⌘C` = `Ctrl+C` (interrupt),
> so use `Ctrl+Shift+C` / `Ctrl+Shift+V` there. For full app-aware Mac emulation
> the alternative is Toshy (a separate, heavier keymapper).
