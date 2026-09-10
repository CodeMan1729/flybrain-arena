"""Shared event budget, bounded movement proxy, and external reward readout."""
from collections import deque
import json
import math
import os
from pathlib import Path
import numpy as np
from .connectome import ACTIONS, FEATURES

def normalize(t):
    if not isinstance(t,dict): raise ValueError("Expected telemetry object")
    def number(key, default=0):
        value = t.get(key, default)
        if isinstance(value, bool) or not isinstance(value, (float,int)) or not math.isfinite(value):
            raise ValueError(f'Invalid telemetry: {key}')
        return value
    # World bounds: room x [-6,6], z [-6,6]; corridor z [-16,-6].
    values = [number('x')/6, (number('z')+5)/11, number('look_x'), number('look_z'), number('look_y'),
              2*number('speed')/3.2-1, 2*number('pause_seconds')/3-1, 2*number('retreat')/3.2-1]
    return np.clip(values,-1,1).astype(np.float32)

def reaction(baseline, samples):
    """Movement proxy [0,1]; compare pre-event movement with a 2 s window."""
    if not samples:
        return 0.0
    retreat = max(max(0, s['retreat']-baseline['retreat'])/3.2 for s in samples)
    turn = max(max(0, abs(s['turn_rate'])-abs(baseline['turn_rate']))/180 for s in samples)
    stop = max(max(0, baseline['speed']-s['speed'])/3.2 for s in samples) if baseline['speed'] > .4 else 0
    return float(np.clip(.4*min(retreat,1)+.35*min(turn,1)+.25*min(stop,1),0,1))

def movement(t):
    normalize(t)
    if any(isinstance(t.get(k,0),bool) or not isinstance(t.get(k,0),(int,float)) for k in ('speed','retreat','turn_rate')): raise ValueError('Invalid movement type')
    result = {k: float(t.get(k,0)) for k in ('speed','retreat','turn_rate')}
    if not all(math.isfinite(v) and abs(v) < 10000 for v in result.values()):
        raise ValueError('Invalid movement sample')
    return result

class Budget:
    LIMIT = 5
    GAP = 8.0
    REPEAT = 16.0
    def __init__(self):
        self.events = deque()
    def allowed(self, action, now):
        if action not in ACTIONS: raise ValueError('Unknown action')
        while self.events and self.events[0][0] <= now-60:
            self.events.popleft()
        return action == 'wait' or (len(self.events) < self.LIMIT and
            (not self.events or now-self.events[-1][0] >= self.GAP) and
            all(a != action or now-t >= self.REPEAT for t,a in self.events))
    def commit(self, action, now):
        if not self.allowed(action,now):
            return False
        if action != 'wait': self.events.append((now,action))
        return True

class Readout:
    """External discounted linear UCB. No connectome synapses are modified."""
    SIZE = 13
    MODEL = 'malecns-rate-readout-v2'
    def __init__(self, seed=42, path=None):
        self.rng = np.random.default_rng(seed)
        self.path = Path(path) if path else None
        self.reset()
    def reset(self):
        self.cov = np.tile(np.eye(self.SIZE), (3,1,1))
        self.target = np.zeros((3,self.SIZE))
        self.counts = np.zeros(3,dtype=int)
        self.reward_sum = np.zeros(3)
        self.updates = 0
    @property
    def weights(self):
        return np.linalg.solve(self.cov,self.target[...,None])[...,0]
    def features(self, neural):
        out = np.asarray(neural['readout'],dtype=float)
        if out.shape != (12,) or not np.isfinite(out).all() or np.any(np.abs(out)>1.001):
            raise ValueError('Invalid measured neural features')
        return np.r_[out,1.]
    def choose(self, mode, neural, allowed=None, explore=True):
        if mode not in ('random','fixed','learn'): raise ValueError('Unknown mode')
        x = self.features(neural)
        allowed = ACTIONS[:3] if allowed is None else allowed
        mask = np.array([a in allowed for a in ACTIONS[:3]])
        if not mask.any(): return 'wait',x,[0.,0.,0.,1.]
        prior = np.abs(x[:3])
        prior /= max(.05,float(prior.max()))
        if mode == 'random': p=mask.astype(float)
        elif mode == 'fixed': p=np.exp(1.2*prior)*mask
        else:
            uncertainty=np.sqrt(np.maximum(0,np.einsum('i,ai->a',x,np.linalg.solve(self.cov,np.tile(x,(3,1))[...,None])[...,0])))
            score=self.weights@x+.05*prior+(.25*uncertainty if explore else 0)
            score[~mask]=-np.inf
            p=np.isclose(score,score.max(),rtol=0,atol=1e-12).astype(float)
            p/=p.sum()
            if explore: p=.94*p+.06*mask/mask.sum()
        p/=p.sum()
        return ACTIONS[int(self.rng.choice(3,p=p))],x,[*p.tolist(),0.]
    def update(self, action, x, reward):
        x=np.asarray(x,dtype=float)
        if action not in ACTIONS[:3] or x.shape!=(self.SIZE,) or not np.isfinite(x).all() or np.any(np.abs(x)>1.001) or not math.isfinite(reward) or not 0<=reward<=1:
            raise ValueError('Invalid reward or neural features')
        i=ACTIONS.index(action)
        # ponytail: discounted linear response model; nonlinear player behavior needs a separately evaluated richer model.
        self.cov[i]=.995*self.cov[i]+.005*np.eye(self.SIZE)+np.outer(x,x)
        self.target[i]=.995*self.target[i]+reward*x
        self.counts[i]+=1;self.reward_sum[i]+=reward;self.updates+=1
    def summary(self):
        return {'updates':self.updates,'counts':self.counts.tolist(),
                'mean_reaction':np.divide(self.reward_sum,self.counts,out=np.zeros(3),where=self.counts>0).tolist()}
    def save(self):
        if not self.path:return
        self.path.parent.mkdir(parents=True,exist_ok=True)
        tmp=self.path.with_suffix('.tmp')
        with tmp.open('w') as f:
            json.dump({'schema':2,'model':self.MODEL,'cov':self.cov.tolist(),'target':self.target.tolist(),
                       'counts':self.counts.tolist(),'reward_sum':self.reward_sum.tolist(),'updates':self.updates},f,allow_nan=False)
            f.flush();os.fsync(f.fileno())
        tmp.replace(self.path)
    def load(self):
        if not self.path or not self.path.exists():return
        data=json.loads(self.path.read_text())
        # Preserve incompatible v1 parameters explicitly instead of pretending they transfer.
        if data.get('schema')==1 and data.get('model')=='malecns-rate-v1':
            backup=self.path.with_name(self.path.name+'.v1-backup')
            if not backup.exists():backup.write_bytes(self.path.read_bytes())
            return
        if data.get('schema')!=2 or data.get('model')!=self.MODEL:raise ValueError('Incompatible learning file')
        cov=np.asarray(data['cov'],dtype=float);target=np.asarray(data['target'],dtype=float)
        counts=np.asarray(data['counts']);rewards=np.asarray(data['reward_sum'],dtype=float)
        updates=data['updates']
        if (cov.shape!=(3,self.SIZE,self.SIZE) or target.shape!=(3,self.SIZE) or counts.shape!=(3,) or rewards.shape!=(3,)
            or counts.dtype.kind not in 'iu' or np.any(counts<0) or type(updates) is not int or updates!=int(counts.sum())
            or not all(np.isfinite(a).all() for a in (cov,target,rewards)) or np.any(rewards<0) or np.any(rewards>counts)
            or not np.allclose(cov,cov.swapaxes(1,2)) or np.linalg.eigvalsh(cov).min()<.99):
            raise ValueError('Invalid saved learning parameters')
        self.cov,self.target,self.counts,self.reward_sum,self.updates=cov,target,counts,rewards,updates
