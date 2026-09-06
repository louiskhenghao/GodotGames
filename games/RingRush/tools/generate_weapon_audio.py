#!/usr/bin/env python3
"""Original, deterministic, short mono effects; no third-party recordings."""
import math, random, struct, wave
from pathlib import Path
RATE = 22050
ROOT = Path(__file__).resolve().parents[1] / 'assets'
def write(name, duration, synth):
    rng = random.Random(62)
    data = []
    for i in range(int(duration * RATE)):
        t = i / RATE
        env = min(1, t * 1200) * (1 - t / duration) ** 1.7
        sample = max(-.9, min(.9, synth(t, rng) * env))
        data.append(struct.pack('<h', round(sample * 32767)))
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as f:
        f.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        f.writeframes(b''.join(data))
write('minigun', .11, lambda t, r: .42*r.uniform(-1,1)*math.exp(-t*27)+.35*math.sin(2*math.pi*(145*t-210*t*t))*math.exp(-t*18))
write('missile_launch', .28, lambda t, r: .24*r.uniform(-1,1)+.32*math.sin(2*math.pi*(180*t+520*t*t)))
write('flamethrower', .24, lambda t, r: .32*r.uniform(-1,1)*(0.7+0.3*math.sin(2*math.pi*43*t))+.16*math.sin(2*math.pi*72*t))
write('energy_bolt', .23, lambda t, r: .24*math.sin(2*math.pi*(900*t-1000*t*t))+.10*r.uniform(-1,1)*math.exp(-t*25))
