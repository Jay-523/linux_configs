# Linux Configuration — Jay's Preferences

Living document of every Linux configuration preference and change on this machine.
When a new preference or config change comes up in conversation, it gets recorded here
(or in the linked doc it belongs to). One line per fact where possible; link out when
a topic gets verbose.

## System

- **OS:** Ubuntu 24.04, GNOME on **Wayland**
- **Migrated from:** macOS — expect Mac muscle memory to drive decisions (see Keyboard)
- **Shells:** bash (default) and zsh — aliases and env changes go in **both** `~/.bashrc` and `~/.zshrc`
- **sudo:** requires a password; nothing root runs unattended

## Keyboard

Keyboard remapping is verbose enough to live in its own repo — do not duplicate it here.

- **Spec (source of truth):** [`kanata_config/requirements.md`](kanata_config/requirements.md) — every behavior has an ID; spec first, implementation second
- **Debugging / incident log:** [`kanata_config/RUNBOOK.md`](kanata_config/RUNBOOK.md)
- **Install & summary:** [`kanata_config/readme.md`](kanata_config/readme.md)
- **TL;DR:** kanata remaps everything Mac-style — Left Alt = ⌘, Ctrl-hold = vim nav layer (hjkl arrows), Caps = Hyper, Ctrl-tap = Escape. Runs as a systemd service; `krestart` after config edits.
- **Hardware:** built-in laptop keyboard + Logitech MX Keys B (Bluetooth)

## GNOME desktop

- **Dock: at the bottom, always hidden, reveals on mouse-push at the bottom edge.** Jay is keyboard-first and opens apps via keyboard, so the dock shouldn't take screen space. Moved from the default left edge because the hover-reveal interfered when mousing left. (2026-07-28)
  ```bash
  gsettings set org.gnome.shell.extensions.dash-to-dock dock-position BOTTOM
  gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed false
  gsettings set org.gnome.shell.extensions.dash-to-dock intellihide false
  ```
  `intellihide false` = fully hidden even on an empty desktop (not just when windows overlap). Revert with `dock-fixed true` / `dock-position LEFT`.
- **Top bar (black menu bar): auto-hidden** via the [Hide Top Bar](https://extensions.gnome.org/extension/545/hide-top-bar/) extension (v126, user-level install in `~/.local/share/gnome-shell/extensions/hidetopbar@mathieu.bidon.ca`, no sudo). Bar stays hidden; reveals on mouse at the top edge and in the Activities overview (Super). (2026-07-28)
  ```bash
  # config lives in dconf:
  dconf write /org/gnome/shell/extensions/hidetopbar/mouse-sensitive true
  dconf write /org/gnome/shell/extensions/hidetopbar/enable-intellihide false
  ```
  Disable with `gnome-extensions disable hidetopbar@mathieu.bidon.ca`. Note: after a GNOME/Ubuntu upgrade this extension may need a version bump (it's tied to the shell version).

## App switching & launcher (Raycast replacement)

- **App hotkeys — caps(Hyper)+letter focuses-or-launches an app** via the [Run or Raise](https://github.com/CZ-NIC/run-or-raise) GNOME extension (`run-or-raise@edvard.cz`, user-level install, config-as-code). Mirrors Jay's Raycast hotkeys from macOS. (2026-07-28)
  - Config: `~/.config/run-or-raise/shortcuts.conf` (format `shortcut,command,wm_class,title`; reloads live on edit)
  - Bindings: **caps+C** Chrome, **caps+R** Zed, **caps+B** Brave, **caps+T** Ghostty
  - Caps = Hyper (`<Ctrl><Shift><Alt><Super>`) comes from kanata — see Keyboard section
- **Launcher + clipboard history: [Vicinae](https://docs.vicinae.com) v0.24.0** — open-source Raycast clone (runs Raycast-compatible extensions, encrypted clipboard history). (2026-07-28)
  - **caps+Space** = launcher, **caps+V** = clipboard history (GNOME custom shortcuts → `vicinae toggle` / `vicinae deeplink vicinae://launch/clipboard/history`)
  - Install is the **AppImage extracted** to `~/.local/opt/vicinae` with a wrapper at `~/.local/bin/vicinae` — the release *tarball does not work on Ubuntu 24.04* (needs Qt 6.11; 24.04 ships Qt 6.4), and the AppImage can't mount directly (no libfuse2), hence the extract
  - Daemon: systemd user unit `~/.config/systemd/user/vicinae.service` (ExecStart uses absolute `%h/.local/bin/vicinae` — bare `vicinae` fails since systemd doesn't search `~/.local/bin`), enabled + running
  - Companion GNOME extension `vicinae@dagimg-dot` (Wayland clipboard capture + overlay) — user-level install
  - Paste support needs `/dev/uinput` write access: satisfied because Jay is in the `input` group

## Window management (Rectangle replacement)

All native GNOME/gsettings — no extra app. Kanata passes these chords through cleanly (cnav emits real `C-9`/`C-0`; Super falls through the cnav layer). (2026-07-28)

- **Ctrl+9 / Ctrl+0 = snap left/right** — added to Ubuntu's Tiling Assistant bindings (it owns tiling, not mutter):
  ```bash
  gsettings set org.gnome.shell.extensions.tiling-assistant tile-left-half  "['<Super>Left','<Super>KP_4','<Control>9']"
  gsettings set org.gnome.shell.extensions.tiling-assistant tile-right-half "['<Super>Right','<Super>KP_6','<Control>0']"
  ```
  Repeat-press should push the window to the adjacent monitor (Rectangle habit — verify; fallback is binding `move-to-monitor-left/right`, currently Super+Shift+Left/Right).
- **Ctrl+Super+Enter = maximize toggle** (physical chord: Ctrl + old-Option-position key + Enter — the MX Keys key labeled opt emits Super on Linux):
  ```bash
  gsettings set org.gnome.desktop.wm.keybindings toggle-maximized "['<Alt>F10','<Control><Super>Return']"
  ```
  Note: Ctrl+**LeftAlt**+Enter can never work — left Alt is kanata's cmd layer and emits no real Alt.
- **Accepted trade-off:** GNOME swallows Ctrl+9/Ctrl+0 globally, so browsers lose Ctrl+9 (last tab) and Ctrl+0 (reset zoom) — same trade-off as Rectangle on macOS.

## Terminal

- **Ghostty 1.3.1** (`/usr/bin/ghostty`, installed from the `.deb` in this folder)

## Aliases

Defined in both `~/.bashrc` and `~/.zshrc`:

| Alias | Does |
|-------|------|
| `krestart` | `sudo systemctl restart kanata.service` |
| `kstatus` | kanata service status |
| `klog` | kanata journal |

## Pending / wishlist

*(nothing yet — items land here before they're implemented)*
