"""Original quiet PCM combat cues; deterministic synthesis, no downloaded samples.

Regeneration changes only five Arena assets; original horror sounds are retained.
"""
import math
from pathlib import Path
import random
import struct
import wave

RATE=22050
DURATIONS={'shot':.14,'hit':.12,'won':.6,'lost':.5,'rotor':4.0}


def samples(name):
    rng=random.Random(1701)
    duration=DURATIONS[name]
    count=round(RATE*duration)
    values=[]
    for i in range(count):
        t=i/RATE
        if name=='shot':
            x=(.13*rng.uniform(-1,1)+.075*math.sin(2*math.pi*(150*t-240*t*t)))*math.exp(-30*t)
        elif name=='hit':
            x=(.085*math.sin(2*math.pi*1450*t)+.05*math.sin(2*math.pi*2100*t))*math.exp(-32*t)
        elif name=='won':
            x=0
            for at,hz in [(0,440),(.14,554),(.28,659)]:
                u=t-at
                if 0<=u<.3:x+=.075*math.sin(2*math.pi*hz*u)*math.sin(math.pi*u/.3)**2
        elif name=='lost':
            x=.1*math.sin(2*math.pi*(240*t-150*t*t))*math.sin(math.pi*t/duration)**2
        else:
            # Integer periods: seamless low rotor/motor loop, unlike insect buzz.
            x=(.052*math.sin(2*math.pi*96*t)+.018*math.sin(2*math.pi*192*t)+
               .012*math.sin(2*math.pi*420*t))*(.85+.15*math.cos(2*math.pi*12*t))
        if name!='rotor':x*=min(1,i/(RATE*.004),(count-1-i)/(RATE*.012))
        values.append(round(max(-.18,min(.18,x))*32767))
    return values


def generate(directory):
    directory=Path(directory);directory.mkdir(parents=True,exist_ok=True)
    for name in DURATIONS:
        data=samples(name)
        with wave.open(str(directory/(name+'.wav')),'wb') as stream:
            stream.setnchannels(1);stream.setsampwidth(2);stream.setframerate(RATE)
            stream.writeframes(struct.pack('<'+'h'*len(data),*data))


if __name__=='__main__':generate(Path(__file__).resolve().parents[1]/'game/audio')
