# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this folder is

Workspace for configuring Jay's Linux machine (Ubuntu 24.04, GNOME on **Wayland**) after migrating from macOS. The active project is `kanata_config/` — a git repo holding keyboard remapping config-as-code built on [kanata](https://github.com/jtroo/kanata) (evdev/uinput remapper, v1.11.0), replacing the old macOS Karabiner Elements setup. The stray `.deb` at the top level is just the Ghostty terminal installer.

**`linux_configuration.md`** is the living record of Jay's Linux preferences and config changes. Whenever Jay states a new preference or a configuration change is made in conversation, record it there (keyboard specifics stay in `kanata_config/` — the doc links out rather than duplicating).

**Why this file exists:** it is Jay's portable setup spec. When Jay distro-hops or moves to a new computer, the plan is to hand this one file to Claude and have the whole setup reproduced from it. So entries must be *reproducible on a fresh machine* — exact commands, package names/versions, and links to configs — not just descriptions of what changed.

## Required reading (in `kanata_config/`, in this order)

1. **`requirements.md`** — the behavioral spec and source of truth. Every remap has an ID (KB-*, CMD-*, SEM-*, OPS-*, LIM-*). Spec beats implementation: new behavior gets a row here *first*, then gets implemented.
2. **`RUNBOOK.md`** — incident log + debugging guide written for future AI assistants. Read it **before** debugging anything; it records the traps already fallen into. New surprises get logged there as incidents (template at the bottom).
3. **`readme.md`** — install steps + modifier scheme summary.

## Commands

```bash
kanata --cfg kanata.kbd --check   # validate syntax — SYNTAX ONLY, never proves behavior
krestart                          # user alias: sudo systemctl restart kanata.service (config is NOT live until this runs)
kstatus / klog                    # user aliases: service status / journal
journalctl -u kanata.service -b   # readable without sudo (user is in adm group)
bash install.sh                   # one-shot idempotent setup (self-elevates with sudo)
```

Behavior verification (in escalating order of ground truth — see RUNBOOK golden rules):

```bash
# 1. Deterministic simulator (build once from kanata source, v1.11.0, package kanata-sim)
kanata_simulated_input -c kanata.kbd -s sim.txt   # sim.txt: d:<key> / u:<key> / t:<ms>

# 2. Real-output capture — ground truth on actual hardware (needs sudo)
./capture-output.sh   # + read_kanata_output.py; reads kanata's virtual device (Name="kanata")
```

`--check` passing, or even a clean simulator run, does **not** prove a fix — Wayland/GNOME timing bugs (modifier flashes) only show up in real-output capture. Never claim a fix without live confirmation.

## Architecture

- **`kanata.kbd`** is the single source of truth. It runs via the systemd *system* service `kanata.service` (root, starts at boot, covers the login screen). Binary at `~/.local/bin/kanata`; kanata's virtual output device is named `kanata`.
- **udev**: `70-kanata-regrab.rules` + `kanata-regrab.service` auto-restart kanata when a keyboard (re)connects (must stay numbered >60 — see RUNBOOK Incident 5) (fixes Bluetooth MX Keys dropping its grab). The rule MUST keep excluding `ATTRS{name}!="kanata"` or a restart re-triggers itself in an infinite loop. `41-kanata-uinput.rules` is an optional non-root variant.
- **Core design invariant (SEM-2, RUNBOOK Incident 1):** no modifier flash/leak. Held modifiers are **pure layer switches** that never press a real modifier for remapped keys — `Ctrl+J` emits a bare `Down` with zero Ctrl events. Consequence (LIM-2): every passthrough `Ctrl+<key>` must be explicitly enumerated in `defsrc`/`base`/`cnav`; a key missing from the list silently loses its Ctrl. Do not "simplify" the enumeration back to emit-then-strip — that reintroduces the leak.
- Accepted limitations are listed in `requirements.md` §6 — they are deliberate; don't fix them silently.

## Change protocol (requirements.md §7)

1. Add/edit the spec row in `requirements.md` first.
2. Implement in `kanata.kbd`; run `--check`.
3. Verify with the simulator AND live after `krestart`.
4. Update the row's status; commit spec + config together.
5. Anything surprising → new incident in `RUNBOOK.md`.

## Environment constraints

- `sudo` requires a password — root steps cannot run non-interactively. Hand the user a `!`-prefixed one-liner to run themselves (e.g. `! sudo systemctl restart kanata.service`).
- First triage for "keyboard not working": is the service installed/active, and is the *external* keyboard actually grabbed? (`journalctl -u kanata.service -b | grep -E 'registering|removing'`). Built-in working while external isn't = the reconnect-grab issue, not a config bug.
