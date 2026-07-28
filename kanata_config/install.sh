#!/usr/bin/env bash
# ============================================================================
#  install.sh — one-shot setup for the kanata keyboard remapper.
#  Idempotent: safe to re-run after editing kanata.kbd.
#
#  Usage:   sudo bash install.sh
#           (or just: bash install.sh  — it re-runs itself with sudo)
# ============================================================================
set -euo pipefail

KANATA_VERSION="v1.11.0"
KANATA_URL="https://github.com/jtroo/kanata/releases/download/${KANATA_VERSION}/linux-binaries-x64.zip"

# --- auto-elevate to root --------------------------------------------------
if [[ $EUID -ne 0 ]]; then
  echo ">> Re-running with sudo (you'll be asked for your password)..."
  exec sudo -E bash "$0" "$@"
fi

# --- resolve the real (non-root) user and paths ----------------------------
REAL_USER="${SUDO_USER:-root}"
USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KANATA_BIN="$USER_HOME/.local/bin/kanata"
CONFIG="$SCRIPT_DIR/kanata.kbd"

echo ">> user=$REAL_USER  home=$USER_HOME"
echo ">> repo=$SCRIPT_DIR"
echo ">> config=$CONFIG"

# --- 1. install the kanata binary if it's missing --------------------------
if [[ ! -x "$KANATA_BIN" ]]; then
  echo ">> kanata not found — downloading ${KANATA_VERSION}..."
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/k.zip" "$KANATA_URL"
  unzip -o "$tmp/k.zip" kanata_linux_x64 -d "$tmp" >/dev/null
  install -D -m 0755 "$tmp/kanata_linux_x64" "$KANATA_BIN"
  chown "$REAL_USER:$REAL_USER" "$KANATA_BIN"
  rm -rf "$tmp"
fi
echo ">> kanata: $("$KANATA_BIN" --version)"

# --- 2. validate the config BEFORE we install anything ---------------------
echo ">> validating config..."
if ! "$KANATA_BIN" --cfg "$CONFIG" --check; then
  echo "!! config is invalid — aborting, nothing was changed." >&2
  exit 1
fi

# --- 3. ensure the uinput kernel module is loaded now + at every boot ------
modprobe uinput || true
echo uinput > /etc/modules-load.d/uinput.conf

# --- 4. udev rule so kanata can also be run without sudo (optional) --------
install -m 0644 "$SCRIPT_DIR/41-kanata-uinput.rules" /etc/udev/rules.d/41-kanata-uinput.rules
udevadm control --reload-rules && udevadm trigger || true
# make sure the invoking user is in the `input` group (needed for non-root runs)
usermod -aG input "$REAL_USER" || true

# --- 4b. auto-re-grab: restart kanata when a keyboard (re)connects ---------
# (MX Keys Bluetooth drop fix — see RUNBOOK Incident 4 / requirements OPS-3)
rm -f /etc/udev/rules.d/42-kanata-regrab.rules   # stale pre-fix name (never matched)
install -m 0644 "$SCRIPT_DIR/70-kanata-regrab.rules" /etc/udev/rules.d/70-kanata-regrab.rules
install -m 0644 "$SCRIPT_DIR/kanata-regrab.service" /etc/systemd/system/kanata-regrab.service
udevadm control --reload-rules || true

# --- 5. install + (re)start the systemd service (runs as root) -------------
cat > /etc/systemd/system/kanata.service <<EOF
[Unit]
Description=kanata keyboard remapper (Karabiner-style config-as-code)
Documentation=https://github.com/jtroo/kanata
After=multi-user.target

[Service]
Type=simple
ExecStartPre=/sbin/modprobe uinput
ExecStart=$KANATA_BIN --cfg $CONFIG
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable kanata.service >/dev/null 2>&1 || true
systemctl restart kanata.service

# --- 6. report -------------------------------------------------------------
sleep 1
echo
echo "============================================================"
systemctl --no-pager --lines=0 status kanata.service || true
echo "============================================================"
if systemctl is-active --quiet kanata.service; then
  echo ">> SUCCESS: kanata is running. Remaps are live now (no reboot needed)."
  echo ">>   Test: tap Left-Ctrl -> should produce Escape."
  echo ">>   Stop anytime: sudo systemctl stop kanata.service"
else
  echo "!! kanata is NOT active. Recent logs:"
  journalctl -u kanata.service -n 20 --no-pager || true
fi
