"""Generate original, deterministic prototype sound effects using only Python."""
import math
import random
import struct
import wave
from pathlib import Path

assets = Path(__file__).resolve().parents[1] / "assets"
rng = random.Random(17)
rate = 22050
for name, duration in [("punch", 0.16), ("level", 0.42)]:
    samples = []
    for i in range(int(rate * duration)):
        t = i / rate
        if name == "punch":
            value = (0.6 * math.sin(2 * math.pi * (120 * t - 190 * t * t))
                     + 0.35 * rng.uniform(-1, 1)) * math.exp(-t * 32)
        else:
            frequency = [523.25, 659.25, 783.99][min(2, int(t / 0.12))]
            local = t % 0.12
            value = math.sin(2 * math.pi * frequency * t) * min(1, local * 150) * math.exp(-local * 15) * 0.4
        samples.append(struct.pack("<h", int(max(-1, min(1, value)) * 24000)))
    with wave.open(str(assets / f"{name}.wav"), "wb") as output:
        output.setparams((1, 2, rate, 0, "NONE", "not compressed"))
        output.writeframes(b"".join(samples))
