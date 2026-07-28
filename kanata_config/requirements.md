# Keyboard Requirements — Source of Truth

**What this is:** the behavioral spec for Jay's keyboard, distilled from his macOS
Karabiner setup ([Jay-523/karabiner_scripts](https://github.com/Jay-523/karabiner_scripts))
plus decisions made during the Linux migration. **This document describes what the
keyboard MUST do — regardless of what `kanata.kbd` currently implements.**

- Any change to `kanata.kbd` is validated against this spec.
- New desired behavior ⇒ add a row here **first**, then implement.
- Companion docs: `RUNBOOK.md` (how to debug / incident log), `readme.md` (install & usage).

Status legend: ✅ implemented & verified · ⏳ wanted, not yet implemented · 📋 liked variant, not currently active

---

## 1. Semantics principles (non-negotiable)

| ID | Principle |
|----|-----------|
| SEM-1 | **Non-cascading remaps.** Rules act on *physical* keys only; the output of one remap NEVER feeds another rule. (Karabiner semantics: physical Escape→left-click coexists with Ctrl-tap→Escape — the synthesized Escape does not click.) |
| SEM-2 | **No modifier flash/leak.** A remapped combo must emit its output with *zero* stray modifier events around it. `Ctrl+J` must emit a bare `Down` — never `↓Ctrl ↑Ctrl ↓Down` (Wayland reads a ~1ms-stale modifier as held; see RUNBOOK Incident 1). |
| SEM-3 | **Behavior parity over key parity.** Mac rules translate to what they *did*, not the literal keys: word motion = `Ctrl+Arrow`, line = `Home`/`End`, document = `Ctrl+Home`/`Ctrl+End`, selection = `+Shift`. |
| SEM-4 | **Passthrough integrity.** Every combo NOT remapped must reach apps untouched (`Ctrl+C/V/A/T/…` stay real Ctrl shortcuts; plain typing unaffected). |

## 2. Modifier scheme (Linux era)

| Physical key | Role |
|--------------|------|
| Caps Lock | **Hyper** (Ctrl+Shift+Alt+Super) while held |
| Left/Right Ctrl | tap = Escape · hold = Ctrl-role (nav layer + real Ctrl combos). Jay never presses Ctrl "just for Ctrl", so aggressive tap→Escape is fine. |
| **Left Alt** | **⌘ Command** (Mac muscle memory; frees Ctrl+hjkl from app-shortcut collisions) |
| **Right Alt** | **⌥ Option** — remains a real Alt (menus, Alt+Tab cycling) + word-motion combos |
| Right Shift | tap = right mouse click · hold = Shift |
| Escape (physical) | left mouse click |

## 3. Core requirements

### 3.1 From Karabiner (`karabiner_all_rules.json` — "jay's personal remaps")

| ID | Trigger | Expected result | Mac origin | Status |
|----|---------|-----------------|------------|--------|
| KB-1 | hold Caps Lock (+key) | Hyper = Ctrl+Shift+Alt+Super chord | Rule 1 | ✅ |
| KB-2 | Ctrl+Space | Escape | Rule 1 | ✅ |
| KB-3 | tap L/R Ctrl alone | Escape | Rule 2 (`to_if_alone`) | ✅ |
| KB-4 | hold L/R Ctrl + other key | acts as Ctrl (lazy) | Rule 2 | ✅ |
| KB-5 | tap Right Shift alone | right mouse click (button2) | Rule 3 | ✅ |
| KB-6 | hold Right Shift + key | acts as Shift (lazy) | Rule 3 | ✅ |
| KB-7 | press physical Escape | left mouse click | Rule 4 | ✅ |
| KB-8 | Ctrl+D | forward delete | Rule 5 | ✅ |
| KB-9 | ⌥+D (Right Alt+D) | delete word forward (`Ctrl+Del`) | Rule 5 (Opt+D) | ✅ |
| KB-10 | delete-line combo | delete whole line (Mac: Cmd+Ctrl+D). App-specific on Linux; suggested `Ctrl+Shift+K` (VS Code) once a home is chosen | Rule 5 | ⏳ |

### 3.2 Vim navigation (Rule 6/7 — 24 manipulators, hjkl = ←↓↑→)

| ID | Trigger (hjkl) | Mac result | Linux expected result (SEM-3) | Status |
|----|----------------|-----------|-------------------------------|--------|
| KB-11 | Ctrl + hjkl | arrows | bare arrow keys (zero Ctrl events — SEM-2) | ✅ |
| KB-12 | Ctrl+Shift + hjkl | Shift+arrows | `Shift+Arrow` (extend selection) | ✅ |
| KB-13 | Ctrl+Cmd + h/l | Cmd+←/→ (line) | `Home` / `End` (Super shed, no leak) | ✅ |
| KB-14 | Ctrl+Cmd + k/j | Cmd+↑/↓ (doc) | `Ctrl+Home` / `Ctrl+End` | ✅ |
| KB-15 | Ctrl+Cmd+Shift + hjkl | Cmd+Shift+arrows | line/doc motion + Shift (select to line/doc bound) | ✅ |
| KB-16 | ⌥ + h/l (Right Alt) | Opt+←/→ (word) | `Ctrl+Left` / `Ctrl+Right` (word motion) | ✅ |
| KB-17 | ⌥ + j/k | Opt+↓/↑ | `Down` / `Up` | ✅ |
| KB-18 | ⌥+Shift + h/l | Opt+Shift+←/→ | `Ctrl+Shift+Left/Right` (word selection) | ✅ |
| KB-19 | ⌥+Shift + j/k | Opt+Shift+↓/↑ | `Shift+Down` / `Shift+Up` (line selection) | ⏳ |
| KB-20 | Ctrl+⌥ + hjkl | Opt+arrows | merged into KB-16/17 (⌥+hjkl alone covers it) — distinct combo not required | ✅ (by design) |

### 3.3 ⌘ Command layer (conversation, 2026-07-27 — Left Alt held)

| ID | Trigger | Expected result | Status |
|----|---------|-----------------|--------|
| CMD-1 | ⌘ + any letter | `Ctrl+<letter>` — ⌘A select-all, ⌘L address bar, ⌘C/V/X copy/paste/cut, ⌘T/W tab open/close, ⌘Z undo, ⌘S save, ⌘F find, ⌘R reload, ⌘Q quit… | ✅ |
| CMD-2 | ⌘ + digit / `-` / `=` | `Ctrl+<same>` (tab switching, zoom) | ✅ |
| CMD-3 | ⌘+Shift + key | Shift stacks: ⌘⇧Z redo, ⌘⇧T reopen tab | ✅ |
| CMD-4 | ⌘ + ← / → | `Home` / `End` (line start/end) | ✅ |
| CMD-5 | ⌘ + ↑ / ↓ | `Ctrl+Home` / `Ctrl+End` (doc top/bottom) | ✅ |
| CMD-6 | ⌘ + [ / ] | `Alt+Left` / `Alt+Right` (browser back/forward) | ✅ |
| CMD-7 | ⌘ + Tab | `Alt+Tab` (window switcher) | ✅ |
| CMD-8 | ⌘ + Backspace | `Ctrl+Backspace` (delete word back) | ✅ |

## 4. Variant library (liked, individually toggleable — Karabiner style)

Standalone rules from the Mac repo. Not contradictions (SEM-1: each acts on physical
input; in Karabiner they were toggled per-rule). Kept as options Jay likes.

| ID | Variant | Source file | Status |
|----|---------|-------------|--------|
| VAR-1 | Escape → Control | `remap_escape_to_control.json` | 📋 |
| VAR-2 | Caps Lock → Super | `rename_caps_lock_to_super.json` | 📋 |
| VAR-3 | Caps Lock → Shift/Super | `remap_caps_lock_shift_super.json` | 📋 |
| VAR-4 | Escape ↔ Delete swap | `swap_esc_delete.json` | 📋 |
| VAR-5 | plain ⌥+hjkl → ⌥+arrows (standalone nav file) | `vim_arrow_keys.json` | ✅ absorbed into KB-16/17 |

## 5. Operational requirements

| ID | Requirement | Status |
|----|-------------|--------|
| OPS-1 | Config-as-code: single git-versioned `kanata.kbd`; every behavior change is a commit | ✅ |
| OPS-2 | Survives reboot with no manual action (systemd service, active ≤ seconds after boot) | ✅ |
| OPS-3 | Applies to ALL keyboards — built-in AND external (Logitech MX KEYS B), **including after Bluetooth reconnect / suspend-resume**. Currently requires manual `krestart` after reconnect → udev auto-restart hardening pending (RUNBOOK Incident 4) | ⏳ |
| OPS-4 | Recovery affordances: `krestart` / `kstatus` / `klog` aliases; emergency exit `LCtrl+Space+Esc` | ✅ |
| OPS-5 | Behavior changes are verified deterministically (simulator) AND live before being called done (RUNBOOK golden rules) | ✅ practice |

## 6. Accepted limitations (known, deliberate — do not "fix" silently)

| ID | Limitation | Why accepted |
|----|-----------|--------------|
| LIM-1 | ⌘C in a terminal = `Ctrl+C` (SIGINT), not copy — use `Ctrl+Shift+C/V` there | ⌘ layer is not app-aware; app-awareness would require Toshy (rejected: heavier second keymapper) |
| LIM-2 | A `Ctrl+<key>` for a key absent from the `cnav` enumeration loses its Ctrl | Consequence of the pure-layer leak fix (SEM-2). Remedy: add the key to `defsrc`/`base`/`cnav` |
| LIM-3 | Lone Super tap during Ctrl+Super+hjkl may occasionally trigger GNOME Activities | Minor; Control is invisible to GNOME in the nav layer. Harden only if it annoys in practice |
| LIM-4 | KB-10 (delete-line) unbound | App-specific on Linux; awaiting Jay's choice of binding |

## 7. Change protocol

1. Want new behavior → **add/edit a row here first** (get the expected result explicit).
2. Implement in `kanata.kbd`; `kanata --cfg kanata.kbd --check`.
3. Verify with the simulator (`kanata_simulated_input`, see RUNBOOK) and live after `krestart`.
4. Update the row's status; commit spec + config together.
5. Anything surprising along the way → new incident in `RUNBOOK.md`.
