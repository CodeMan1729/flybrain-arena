"""Frozen held-out evaluation of external learning, using full-graph neural traces.
Synthetic response task only; never a measurement of human fear or fly learning.
"""
from datetime import datetime,timezone
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from brain.connectome import Connectome,ROOT,ACTIONS
from brain.director import Budget,Readout,normalize

def response(inputs,action):
    # Predeclared synthetic context-dependent preferences; no human participants.
    x,speed=inputs[0],inputs[5]
    return float(np.clip({'lights':.5+.38*x,'steps':.5-.38*x,'silhouette':.45+.38*speed}[action],.02,.98))

def rollout(layer,mode,trace,seed,epochs,training=None,ablate=False):
    budget=Budget();teacher=np.random.default_rng(seed+8000);records=[]
    for k in range(len(trace)*epochs):
        item=trace[k%len(trace)];t=k*3.
        neural=item['neural'] if not ablate else {**item['neural'],'readout':[0.]*12}
        allowed=[a for a in ACTIONS[:3] if budget.allowed(a,t)]
        action,x,prob=layer.choose(mode,neural,allowed,explore=training is not None)
        assert budget.commit(action,t)
        reward=0.
        if action!='wait':
            reward=response(item['inputs'],action)
            if training is not None:
                observed=0. if training=='no_reward' else response(item['inputs'],ACTIONS[int(teacher.integers(3))]) if training=='shuffled' else reward
                layer.update(action,x,observed)
        records.append({'seed':seed,'t':t,'trace_index':item['index'],'action':action,'reward':reward,
                        'updates':layer.updates,'probabilities':prob})
    rewards=[r['reward'] for r in records if r['action']!='wait']
    return {'mean_response':float(np.mean(rewards)),'events':len(rewards),'updates':layer.updates},records

def main():
    brain=Connectome();graph_before=hashlib.sha256(brain.weights.data.tobytes()).hexdigest();traces=[]
    for split,seed,count in [('train',2101,128),('held_out',9107,64)]:
        rng=np.random.default_rng(seed);trace=[];brain.reset()
        for k in range(count):
            telemetry={'x':float(rng.uniform(-6,6)),'z':float(rng.uniform(-14,5)),
                'look_x':float(rng.uniform(-1,1)),'look_z':float(rng.uniform(-1,1)),
                'look_y':float(rng.uniform(-.5,.5)),'speed':float(rng.uniform(0,3.2)),
                'pause_seconds':float(rng.uniform(0,3)),'retreat':float(rng.uniform(0,3.2))}
            values=normalize(telemetry);result=brain.step(values)
            result.pop('view_activity')
            trace.append({'index':f'{split}-{k}','utc':datetime.now(timezone.utc).isoformat(),'inputs':values.tolist(),'neural':result})
            if k%32==0:print(f'{split}: {k}/{count}',flush=True)
        traces.append(trace)
    train,test=traces;results=[];records=[]
    for seed in [3,17,42,71,123,208,501,999]:
        trained=Readout(seed)
        training,rows=rollout(trained,'learn',train,seed,24,'reward')
        records.extend(dict(r,condition='train') for r in rows)
        weights=trained.weights.copy()
        with tempfile.TemporaryDirectory() as tmp:
            trained.path=Path(tmp)/'memory.json';trained.save()
            retained=Readout(seed,trained.path);retained.load()
            np.testing.assert_array_equal(retained.weights,weights)
        shuffled=Readout(seed);rollout(shuffled,'learn',train,seed,24,'shuffled')
        no_reward=Readout(seed);rollout(no_reward,'learn',train,seed,24,'no_reward')
        erased=Readout(seed)
        for condition,mode,layer,ablate in [('random','random',Readout(seed),False),('fixed','fixed',Readout(seed),False),
            ('untrained','learn',Readout(seed),False),('trained','learn',trained,False),('retained','learn',retained,False),
            ('shuffled_reward','learn',shuffled,False),('no_reward','learn',no_reward,False),
            ('memory_erased','learn',erased,False),('neural_features_ablated','learn',retained,True)]:
            layer.rng=np.random.default_rng(seed)
            before=layer.weights.copy()
            summary,rows=rollout(layer,mode,test,seed,8,ablate=ablate)
            np.testing.assert_array_equal(layer.weights,before)
            results.append({'seed':seed,'condition':condition,**summary})
            records.extend(dict(r,condition=condition) for r in rows)
    graph_after=hashlib.sha256(brain.weights.data.tobytes()).hexdigest()
    assert graph_before==graph_after
    means={c:float(np.mean([r['mean_response'] for r in results if r['condition']==c])) for c in sorted({r['condition'] for r in results})}
    paired=[next(r['mean_response'] for r in results if r['seed']==s and r['condition']=='trained')-next(r['mean_response'] for r in results if r['seed']==s and r['condition']=='fixed') for s in [3,17,42,71,123,208,501,999]]
    rng=np.random.default_rng(451);boot=np.mean(rng.choice(paired,(10000,len(paired)),replace=True),axis=1)
    report={'kind':'Synthetic context task; external decoder learning, NOT human fear or biological learning',
        'model':Readout.MODEL,'graph':'full MaleCNS v1.0','graph_weights_unchanged':graph_before==graph_after,
        'graph_weights_sha256':graph_after,'real_neural_decisions':192,'train_trace_seed':2101,'held_out_trace_seed':9107,
        'training_decisions_per_seed':3072,'evaluation_decisions_per_condition_seed':512,
        'training_epochs':24,'evaluation_frozen':True,'budget':'5/60s; 8s gap; 16s repeat; allowed actions masked before choice',
        'response_formula':'lights=.5+.38*x; steps=.5-.38*x; silhouette=.45+.38*speed; normalized x/speed, clipped .02..98',
        'means':means,'trained_minus_fixed_paired':paired,'paired_bootstrap_95_interval':np.quantile(boot,[.025,.975]).tolist(),
        'limitations':'8 policy seeds share 192 neural trace points; replay does not establish independent animals, human efficacy, closed-loop adaptation or unfamiliar response laws.',
        'results':results}
    (ROOT/'reports/experiment-traces.json').write_text(json.dumps({'train':train,'held_out':test}))
    (ROOT/'reports/experiment.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in records))
    (ROOT/'reports/experiment-summary.json').write_text(json.dumps(report,indent=2))
    print(json.dumps({k:v for k,v in report.items() if k!='results'},indent=2))

if __name__=='__main__':main()
