#!/usr/bin/env bash
# Capture REAL kanata output events for diagnosis.
# Stops the service, runs kanata with debug logging for a fixed window while you
# type test keys in any app, then restarts the service. Writes a readable log.
set -euo pipefail

if [[ $EUID -ne 0 ]]; then exec sudo -E bash "$0" "$@"; fi

BIN=/home/dragonshree/.local/bin/kanata
CFG=/home/dragonshree/jay/configuring_linux/kanata_config/kanata.kbd
LOG=/tmp/kanata_dbg.log
WINDOW=15

echo ">> stopping service..."
systemctl stop kanata.service || true
sleep 1

echo ">> starting kanata in debug for ${WINDOW}s..."
: > "$LOG"
"$BIN" --cfg "$CFG" -d --no-wait >"$LOG" 2>&1 &
KPID=$!
sleep 2   # let it grab the keyboard

echo ""
echo "==================================================================="
echo "  NOW: press  Ctrl+J  slowly 3-4 times (hold Ctrl, tap J, release)."
echo "  Then try Ctrl+H once too. You have ${WINDOW} seconds."
echo "==================================================================="
for i in $(seq "$WINDOW" -1 1); do printf "\r  %2d s left... " "$i"; sleep 1; done
echo ""

kill "$KPID" 2>/dev/null || true
wait "$KPID" 2>/dev/null || true
chmod 644 "$LOG"

echo ">> restarting service..."
systemctl start kanata.service

echo ">> DONE. Debug log saved to $LOG ($(wc -l <"$LOG") lines)."
echo ">> (Claude will read it.)"
