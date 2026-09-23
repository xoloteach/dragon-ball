"""Regenerate the original synthesized combat sound effects (no samples used)."""
from pathlib import Path
import math
import random
import struct
import wave

ROOT = Path(__file__).resolve().parent
RATE = 22050
random.seed(34019)


def write(name, duration, sample):
    path = ROOT / (name + ".wav")
    frames = []
    for i in range(int(RATE * duration)):
        t = i / RATE
        value = max(-1.0, min(1.0, sample(t, duration)))
        frames.append(struct.pack("<h", int(value * 29000)))
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(b"".join(frames))
    print(path)


def noise():
    return random.uniform(-1.0, 1.0)


write("impact_bass", .37, lambda t,d:
      (math.sin(2*math.pi*(90-58*t/d)*t)*.75 + noise()*.26) * math.exp(-12*t))
write("impact_crack", .19, lambda t,d:
      (noise()*.65 + math.sin(2*math.pi*720*t)*.25) * math.exp(-30*t))
write("ki_blast", .36, lambda t,d:
      (math.sin(2*math.pi*(920-610*t/d)*t)*.36 +
       math.sin(2*math.pi*(240-100*t/d)*t)*.35 + noise()*.20) * math.exp(-6*t))
write("beam", 1.07, lambda t,d:
      (math.sin(2*math.pi*(95+230*t/d)*t)*.34 +
       math.sin(2*math.pi*(380+340*t/d)*t)*.30 + noise()*.22) *
      min(1.0,t*16) * math.exp(-2.1*t))
write("charge", .7, lambda t,d:
      (math.sin(2*math.pi*(150+250*t/d)*t)*.35 +
       math.sin(2*math.pi*(600+500*t/d)*t)*.23 + noise()*.10) *
      min(1.0,t*10) * (1-t/d))
write("ui_confirm", .15, lambda t,d:
      (math.sin(2*math.pi*480*t)*.40 + math.sin(2*math.pi*720*t)*.21) * math.exp(-21*t))
