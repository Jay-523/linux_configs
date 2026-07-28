#!/usr/bin/env python3
"""Read kanata's virtual output device raw and print decoded key events.
No external deps (parses the raw input_event struct). Run as root.
Usage: read_kanata_output.py <event-device-path> <seconds>
"""
import struct, sys, time, select, os

dev = sys.argv[1]
dur = float(sys.argv[2]) if len(sys.argv) > 2 else 15.0

# input_event on 64-bit Linux: long sec, long usec, u16 type, u16 code, s32 value
FMT = 'llHHi'
SZ = struct.calcsize(FMT)
EV_KEY = 0x01

NAMES = {29:'LCtrl',97:'RCtrl',42:'LShift',54:'RShift',56:'LAlt',100:'RAlt',
         125:'LMeta',126:'RMeta',36:'J',35:'H',37:'K',38:'L',32:'D',
         103:'Up',108:'Down',105:'Left',106:'Right',102:'Home',107:'End',
         1:'Esc',57:'Space',111:'Delete',15:'Tab',14:'Backspace',
         272:'MouseLeft',273:'MouseRight',46:'C',47:'V',30:'A'}
VAL = {1:'DOWN', 0:'up  ', 2:'rpt '}

fd = os.open(dev, os.O_RDONLY | os.O_NONBLOCK)
print(f"# reading {dev} for {dur:.0f}s — type your test keys now")
t0 = time.time()
end = t0 + dur
n = 0
while time.time() < end:
    r, _, _ = select.select([fd], [], [], 0.2)
    if not r:
        continue
    try:
        data = os.read(fd, SZ * 64)
    except BlockingIOError:
        continue
    for i in range(0, len(data) - SZ + 1, SZ):
        sec, usec, etype, code, value = struct.unpack(FMT, data[i:i+SZ])
        if etype != EV_KEY:
            continue
        name = NAMES.get(code, f'code{code}')
        ms = int((time.time() - t0) * 1000)
        print(f"  {ms:6d}ms   {VAL.get(value,'?'):4s}  {name}")
        n += 1
print(f"# done — {n} key events captured")
