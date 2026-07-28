# kanata Runbook & Incident Log

A living guide for future AI assistants (and humans) working on Jay's keyboard
setup. Read this **before** debugging — it captures how this system actually
behaves, the traps we already fell into, and the tools that resolved them.

## System at a glance
- **Tool:** [kanata](https://github.com/jtroo/kanata) v1.11.0 — evdev/uinput remapper, works on Wayland.
- **OS:** Ubuntu 24.04, GNOME on **Wayland**. Migrated from macOS Karabiner Elements.
- **Config (source of truth):** `kanata.kbd` in this folder (git-versioned).
- **Runs as:** systemd system service `kanata.service` (root, auto-starts at boot).
- **Binary:** `~/.local/bin/kanata`. **Virtual output device name:** `kanata`.
- **Aliases** (`~/.bashrc` + `~/.zshrc`): `krestart` (sudo restart), `kstatus`, `klog`.

## Golden rules (learned the hard way)
1. **`kanata --check` validates SYNTAX ONLY, never behavior.** A config can pass
   `--check` and still do the wrong thing. Verify behavior with the simulator
   and/or a real-output capture (see Tools).
2. **The simulator models kanata's key engine, NOT the Wayland compositor.** If
   the sim says "clean" but the user still sees a bug, the problem is in how the
   real events hit libinput/GNOME (timing, modifier flashes). Capture real output.
3. **Never claim a fix without live confirmation.** We once shipped a "fix" that
   passed `--check` and *looked* right but still leaked (see Incident 1).
4. **`sudo` requires a password in this environment.** The AI cannot run root
   steps non-interactively. Hand the user a `!`-prefixed one-liner to run.
5. **After editing `kanata.kbd`, it is NOT live until `krestart`.** Many "it's
   still broken" reports are simply an un-reloaded service (see Incident 4).

## Tools that cracked these cases
- **Deterministic config simulator** — pipes synthetic key events through the
  real config and prints emitted events. Build it:
  ```bash
  git clone --depth 1 --branch v1.11.0 https://github.com/jtroo/kanata.git
  cd kanata && cargo build --release -p kanata-sim   # -> target/release/kanata_simulated_input
  ```
  Run: `kanata_simulated_input -c kanata.kbd -s sim.txt`
  Input format: `d:<key>` down, `u:<key>` up, `t:<ms>` wait. E.g. Ctrl+J =
  `d:lctl t:60 d:j t:60 u:j t:60 u:lctl`.
- **Real-output capture** — `capture-output.sh` + `read_kanata_output.py` read
  kanata's own virtual device (`Name="kanata"`, e.g. `/dev/input/event11`) raw
  and decode key events. This is ground truth on the user's actual hardware
  (the simulator can't see Wayland). Needs sudo (reads `/dev/input`).
- **`journalctl -u kanata.service -b`** — shows device grabs (`registering ...`),
  layer changes (`Entered layer`), and errors. The AI can read this (adm group).
- **`/proc/bus/input/devices`** — list keyboards + which `eventN` each uses.

---

## Incident 1 — `Ctrl+hjkl` leaks Ctrl (arrows behave like `Ctrl+Arrow`)
**Severity:** high (core feature) · **Status:** RESOLVED (2026-07-27)

**Symptom:** `Ctrl+J` moved by paragraph / scrolled instead of one line — i.e.
the OS saw `Ctrl+Down`, not `Down`. Worked correctly in a raw terminal but not
in GUI apps.

**Investigation path (and the wrong turns):**
1. First hypothesis: `defoverrides` couldn't strip Ctrl because Control is a
   tap-hold that "eagerly emits" lctl. Rewrote nav into a `cnav` layer with
   `unmod`. Passed `--check`, *looked* correct → **still leaked.** (Wrong fix.)
2. Built the **simulator** and ran BOTH the old (override) and new (unmod)
   configs. **Both produced identical, clean output** (`↓LCtrl ↑LCtrl ↓Down`).
   Key realization: the sim can't reproduce the bug → it's not in kanata's key
   logic; it's in the kanata↔Wayland boundary.
3. **Captured real hardware output** with `read_kanata_output.py`. Confirmed
   kanata emits `↓LCtrl ↑LCtrl ↓Down ↑Down ↓LCtrl ↑LCtrl` — Control is released
   only **1ms** before Down, and re-pressed the same ms Down releases.

**Root cause:** A tap-hold modifier that then participates in a chord "flashes"
the modifier (press → release ~1ms around the target key). Wayland/GNOME reads
that 1ms-stale Ctrl as still-held → `Ctrl+Down`. Terminals tolerate it; GUI
apps don't. This is inherent to *any* design where Control's hold presses a real
`lctl` that must be stripped for nav keys.

**Fix:** Make Control's hold a **pure layer switch that never presses a real
`lctl`.** In the `cnav` layer, `hjkl` emit **bare arrows** (zero Ctrl events
around them → nothing to leak). Every other key is enumerated as explicit
`C-<key>` so `Ctrl+C/V/...` still work. Super-triggered line/doc motions shed
Super with `unmod`. Verified in the simulator across all cases before shipping.

**Lesson for future AI:** When a modifier "leaks" on Wayland, don't trust
`--check` or even the simulator alone — capture real output. The robust cure for
a tap-hold-modifier chord is to **never emit the real modifier for the remapped
keys** (pure layer + enumerate the passthrough combos), not to emit-then-strip it.

**Trade-off introduced:** the pure-layer design grabs the whole keyboard and
enumerates Ctrl combos. A `Ctrl+<key>` for a key not in the `cnav` list will lose
its Ctrl — add the key to `defsrc`/`base`/`cnav` to fix. Also, because Control is
invisible to GNOME, a lone Super tap during `Ctrl+Super+hjkl` can occasionally
open the Activities overview.

---

## Incident 2 — "Shortcuts aren't working" (nothing remapped at all)
**Severity:** medium · **Status:** RESOLVED (setup step missing)

**Symptom:** User reported no remaps working shortly after initial setup.

**Root cause:** The service was never installed/started — the root setup steps
(`modprobe uinput`, install `kanata.service`, `systemctl enable --now`) hadn't
been run yet. `systemctl status kanata.service` → `Unit could not be found`;
`lsmod | grep uinput` → empty.

**Fix:** Ran `install.sh` (self-elevating, idempotent). 

**Lesson:** First triage for "not working" = is the service actually installed,
active, and is a `kanata` process running? Check before touching the config.

---

## Incident 3 — "Did it survive the reboot / is it really running?"
**Severity:** low (reassurance) · **Status:** VERIFIED OK

**Symptom:** After a laptop reboot the user doubted kanata was running.

**Finding:** It was healthy — systemd started it **11 seconds after boot**
(`ExecMainStartTimestamp` ≈ boot time), `enabled`, and the journal showed live
`Entered layer` events. The systemd service is exactly what makes it survive
reboots; no manual start needed.

**Lesson:** Prove persistence with facts: compare `uptime -s` (boot) to the
kanata process start time (`ps -o lstart`) and `systemctl is-enabled`.

---

## Incident 4 — Mappings stop working on the external keyboard
**Severity:** medium (recurring) · **Status:** WORKAROUND (`krestart`); hardening PENDING

**Symptom:** After a reboot/suspend or reconnect, keymapping "isn't working."

**Root cause:** The external **Logitech MX KEYS B (Bluetooth)** disconnected
(`removing kbd device: eventN` + `Failed to ungrab`, often preceded by
`failed poll: Interrupted` from a suspend/resume). On reconnect, kanata's device
watcher **did not re-grab it**, so the user was typing on an ungrabbed keyboard.
kanata was still correctly grabbing the *built-in* keyboard (`event2`), which is
a fast way to confirm this diagnosis (built-in works, external doesn't).

**Diagnostic:** `journalctl -u kanata.service -b | grep -E 'registering|removing'`
and `grep -i 'MX KEYS' /proc/bus/input/devices`.

**Fix (now):** `krestart` re-scans and re-grabs all current keyboards.

**Pending hardening:** a udev rule to auto-restart kanata when a keyboard
reconnects. Must be scoped to real keyboards (`ID_INPUT_KEYBOARD==1`) and must
**exclude kanata's own virtual device** (`Name="kanata"`) or it self-triggers an
infinite restart loop.

**Lesson:** For "not working," always check *which* keyboard is grabbed —
Bluetooth/receiver keyboards churn device nodes and kanata can miss the re-grab.

---

## Incident 5 — udev regrab rule installed but never fired
**Severity:** medium · **Status:** RESOLVED (2026-07-28)

**Symptom:** The OPS-3 auto-re-grab (`42-kanata-regrab.rules` + `kanata-regrab.service`)
was installed, `udevadm verify` passed, yet `kanata-regrab.service` never activated —
not even across a full reboot (which floods keyboard add-events). The MX Keys event
device showed `ID_INPUT_KEYBOARD=1` but none of our `TAGS`/`SYSTEMD_WANTS`.

**Investigation:** `udevadm info /dev/input/event18` showed the property present but
our tag absent → the rule file was being read (confirmed via `udevadm test`) but the
match never succeeded at rule-execution time.

**Root cause:** **udev rule ordering.** `ID_INPUT_KEYBOARD` is set by the `input_id`
builtin invoked from `60-input-id.rules`. Our rule was numbered **42**, so it executed
*before* the property existed and silently never matched. `udevadm verify` checks
syntax only — it says nothing about whether a rule can ever match (same trap shape as
`kanata --check`: valid ≠ effective).

**Fix:** Renamed the rule to `70-kanata-regrab.rules` (sorts after 60); `install.sh`
removes the stale 42 file on reinstall.

**Lesson for future AI:** A udev rule that matches on `ENV{ID_INPUT_*}` MUST be
numbered >60. Verify a udev rule is *live*, not just installed: check
`udevadm info <dev>` for the expected `TAGS`/`SYSTEMD_WANTS` on a real device, and
check `journalctl -u <unit>` actually shows activations after a device add.

---

## Template for new incidents
```
## Incident N — <one-line symptom>
**Severity:** low/medium/high · **Status:** OPEN/RESOLVED/WORKAROUND (date)
**Symptom:** what the user observed.
**Investigation:** steps + wrong turns (wrong turns are valuable!).
**Root cause:** the real mechanism.
**Fix:** what changed.
**Lesson for future AI:** the reusable takeaway.
```
