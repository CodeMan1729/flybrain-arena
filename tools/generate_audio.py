"""Original deterministic quiet PCM assets; no downloaded samples."""
import math
from pathlib import Path
import random
import struct
import wave

root=Path(__file__).resolve().parents[1]/'game/audio'
root.mkdir(exist_ok=True)
rng=random.Random(42);rate=22050
for name,duration in [('steps',1.5),('hum',8.0),('buzz',4.0),('breath',1.8),('creak',1.9),('knock',1.65)]:
    samples=[]
    air=0.0
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
        elif name=='buzz':
            # Periodic phase and flutter make the four-second loop seamless.
            phase=2*math.pi*190*t+.9*math.sin(2*math.pi*4*t)+.3*math.sin(2*math.pi*7*t)
            flutter=(.75+.16*math.cos(2*math.pi*13*t)+.09*math.cos(2*math.pi*29*t))*(.88+.12*math.cos(math.pi*t))
            x=.085*sum(math.sin(k*phase)/k for k in range(1,7))*flutter
        elif name=='breath':
            noise=rng.uniform(-1,1)
            air=.78*air+.22*noise
            envelope=sum(math.sin(math.pi*(t-at)/length)**2 for at,length in [(0.08,.65),(.86,.82)] if at<t<at+length)
            x=envelope*(.12*(noise-air)+.025*math.sin(2*math.pi*145*t)*(1+.3*math.sin(2*math.pi*31*t)))
        elif name=='creak':
            phase=2*math.pi*(125*t+48*t*t)+2.6*math.sin(2*math.pi*2.3*t)
            x=.085*(math.sin(phase)+.35*math.sin(2.7*phase)+.18*math.sin(5.1*phase))*(.7+.3*math.sin(2*math.pi*17*t))
        else:
            x=0
            for at in [.10,.52,1.12]:
                u=t-at
                if 0<=u<.4:
                    x+=(.14*math.sin(2*math.pi*112*u)+.065*math.sin(2*math.pi*263*u)+.04*rng.uniform(-1,1))*math.exp(-18*u)*min(1,u/.008)
        if name in ('breath','creak','knock'):
            x*=min(1,t/.045,(duration-t)/.14)
        samples.append(struct.pack('<h',int(max(-.18,min(.18,x))*32767)))
    with wave.open(str(root/(name+'.wav')),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(b''.join(samples))
