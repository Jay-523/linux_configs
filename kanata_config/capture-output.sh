#!/usr/bin/env bash
# Capture what kanata's virtual keyboard ACTUALLY emits, while you type test keys.
# Does NOT stop the service. Runs as root to read /dev/input.
set -euo pipefail
if [[ $EUID -ne 0 ]]; then exec sudo -E bash "$0" "$@"; fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WINDOW="${1:-15}"

# find the event device that kanata created for output (Name="kanata")
DEV=$(awk 'BEGIN{RS="";FS="\n"} /N: Name="kanata"/ {for(i=1;i<=NF;i++) if($i ~ /^H: Handlers=/){match($i,/event[0-9]+/); print "/dev/input/"substr($i,RSTART,RLENGTH); exit}}' /proc/bus/input/devices)

if [[ -z "${DEV:-}" ]]; then
  echo "!! could not find kanata's output device. Is the service running? (kstatus)"; exit 1
fi
echo ">> kanata output device: $DEV"
echo "==================================================================="
echo "  When it says 'type your test keys now':"
echo "    1) hold Ctrl, tap J, release   (do this 3x, slowly)"
echo "    2) then hold Ctrl, tap C, release   (a normal copy, for comparison)"
echo "==================================================================="
python3 "$DIR/read_kanata_output.py" "$DEV" "$WINDOW"
echo ">> DONE."
