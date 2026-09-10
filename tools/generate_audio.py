"""Original deterministic quiet PCM assets; no downloaded samples."""
import math
from pathlib import Path
import random
import struct
import wave

root=Path(__file__).resolve().parents[1]/'game/audio'
root.mkdir(exist_ok=True)
rng=random.Random(42);rate=22050
for name,duration in [('steps',1.5),('hum',8.0),('buzz',4.0)]:
    samples=[]
    for i in range(int(rate*duration)):
        t=i/rate
        if name=='steps':
            x=0
            for at in [.05,.55,1.03]:
                u=t-at
                if 0<=u<.22:
                    x+=(.5*math.sin(2*math.pi*76*u)+.15*rng.uniform(-1,1))*math.exp(-25*u)*min(1,u/.01)
            x*=.30
        elif name=='hum':
            x=.045*(math.sin(2*math.pi*48*t)+.35*math.sin(2*math.pi*96*t)+.45*math.sin(2*math.pi*192*t)+.25*math.sin(2*math.pi*288*t))*(.75+.25*math.cos(2*math.pi*t/8))
        else:
            # Periodic phase and flutter make the four-second loop seamless.
            phase=2*math.pi*190*t+.9*math.sin(2*math.pi*4*t)+.3*math.sin(2*math.pi*7*t)
            flutter=(.75+.16*math.cos(2*math.pi*13*t)+.09*math.cos(2*math.pi*29*t))*(.88+.12*math.cos(math.pi*t))
            x=.085*sum(math.sin(k*phase)/k for k in range(1,7))*flutter
        samples.append(struct.pack('<h',int(max(-.18,min(.18,x))*32767)))
    with wave.open(str(root/(name+'.wav')),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(b''.join(samples))
