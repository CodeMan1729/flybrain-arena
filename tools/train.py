"""Sequential synthetic-player training; real MaleCNS traces, no human fear claim."""
import argparse
from copy import deepcopy
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import time

import numpy as np

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from brain.connectome import Connectome, ROOT, ACTIONS
from brain.director import Readout, Budget, normalize

REPORT = ROOT/'reports/learning-v3'

def collect(confirm=False):
    brain=Connectome();traces=json.loads((REPORT/'traces.json').read_text()) if confirm else {};started=time.monotonic()
    digest=hashlib.sha256(brain.weights.data.tobytes()).hexdigest()
    for split,seed,count in ([('confirm',202612,160)] if confirm else [('train',202610,320),('test',202611,160)]):
        rng=np.random.default_rng(seed);rows=[];brain.reset()
        for i in range(count):
            angle=rng.uniform(-np.pi,np.pi);tilt=rng.uniform(-.6,.6)
            speed=float(rng.choice([0,.8,1.8,3.2]))
            t={'x':float(rng.uniform(-6,6)),'z':float(rng.uniform(-14,5)),
               'look_x':float(np.sin(angle)*np.cos(tilt)), 'look_z':float(np.cos(angle)*np.cos(tilt)),
               'look_y':float(np.sin(tilt)),'speed':speed,'pause_seconds':float(rng.uniform(0,3)) if speed==0 else 0.,
               'retreat':float(speed*rng.choice([0,0,1]))}
            values=normalize(t);out=brain.step(values);out.pop('view_activity')
            rows.append({'index':f'{split}-{i}','inputs':values.tolist(),'neural':out})
            if i%40==0:print(f'Full graph {split}: {i}/{count}',flush=True)
        traces[split]=rows
    assert digest==hashlib.sha256(brain.weights.data.tobytes()).hexdigest()
    if confirm:
        assert traces['metadata']['graph_sha256']==digest
        traces['metadata'].update(confirmation_seed=202612,confirmation_seconds=time.monotonic()-started,real_neural_steps=640)
    else:traces['metadata']={'graph_sha256':digest,'neurons':brain.info['neurons'],'edges':brain.info['edges'],
                        'seconds':time.monotonic()-started,'real_neural_steps':480,'split_seeds':[202610,202611]}
    (REPORT/'traces.json').write_text(json.dumps(traces))
    print('Neural traces saved',flush=True)

def player_preferences(seed, changed=False):
    rng=np.random.default_rng(seed)
    bias=np.array([-.22,0,.22])[rng.permutation(3)]
    return np.roll(bias,1) if changed else bias

def responses(inputs, bias, habit):
    x,z,lx,lz,ly,speed,pause,retreat=np.asarray(inputs)
    # Declared artificial player model. Only its selected event's noisy label reaches the learner.
    context=np.array([.22*(1-speed)/2+.14*(1+ly)/2+.12*(1-abs(x)),
                      .22*(1+speed)/2+.16*(1+lz)/2+.12*(1+retreat)/2,
                      .20*(1-abs(ly))+.14*(1+lx)/2+.12*(1+pause)/2])
    return np.clip(.20+context+bias-.24*habit,.02,.98)

def rollout(layer, trace, seed, episodes, mode='learn', training=False, changed=False,
            legacy=False, labels='reward', ablate=False, episode_offset=0):
    rng=np.random.default_rng(seed+991+episode_offset*100003);budget=Budget();habit=np.zeros(3);values=[];regrets=[];rows=[]
    bias=player_preferences(seed,changed)
    order=rng.permutation(len(trace));noise=rng.normal(0,.12,(episodes*60,3))
    shuffled=rng.permutation(episodes*60)
    for k in range(episodes*60):
        item=trace[int(order[k%len(order)])];t=k*3.
        neural=item['neural']
        if legacy: neural={**neural,'readout':np.clip(np.r_[neural['readout'][:4],np.array(neural['readout'][4:])*5],-1,1).tolist()}
        if ablate: neural={**neural,'readout':[0.]*12}
        allowed=[a for a in ACTIONS[:3] if budget.allowed(a,t)]
        action,features,prob=layer.choose(mode,neural,allowed,explore=training)
        assert budget.commit(action,t)
        habit*=.98
        if action=='wait':continue
        i=ACTIONS.index(action);expected=responses(item['inputs'],bias,habit)
        reward=float(np.clip(expected[i]+noise[k,i],0,1))
        observed=0. if labels=='zero' else float(np.clip(responses(trace[int(order[shuffled[k]%len(order)])]['inputs'],bias,np.zeros(3))[int(rng.integers(3))]+noise[k,i],0,1)) if labels=='shuffled' else reward
        if training:
            if legacy:layer.update(action,features,observed)
            else:layer.update(action,features,observed,source='simulation')
        values.append(float(expected[i]));regrets.append(float(max(expected[ACTIONS.index(a)] for a in allowed)-expected[i]))
        rows.append({'episode':k//60,'action':action,'expected':float(expected[i]),'observed':reward,'updates':layer.updates})
        habit[i]=min(1,habit[i]+.3)
    return {'mean_response':float(np.mean(values)),'regret':float(np.mean(regrets)),'events':len(values)},rows

def train(confirm=False):
    traces=json.loads((REPORT/'traces.json').read_text());train_trace,test_trace=traces['train'],traces['confirm' if confirm else 'test']
    spec=importlib.util.spec_from_file_location('brain.baseline_v2',REPORT/'director-v2.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    prior=Readout(4021,REPORT/'candidate-prior.json');prior.DISCOUNT=.9995
    if confirm:prior.load()
    training=[]
    # Sequential round-robin prevents the last synthetic personality from dominating the prior.
    for episode in range(0 if confirm else 12):
        for person in range(48):
            result,rows=rollout(prior,train_trace,5000+person,1,training=True,episode_offset=episode)
            training.append({'player':person,'episode':episode,**result})
        print(f'Pretraining {episode+1}/12: 48 players, {prior.updates} rewarded events',flush=True)
    if not confirm:prior.save()
    results=[];curves=[]
    for person in range(24):
        seed=(28000 if confirm else 18000)+person
        old=module.Readout(seed);cold=Readout(seed);warm=Readout(seed);warm.bootstrap(prior.path)
        zero=Readout(seed);shuffled=Readout(seed)
        for condition,layer,mode,legacy in [('random',Readout(seed),'random',False),('fixed',Readout(seed),'fixed',False),
                ('cold_start',deepcopy(cold),'learn',False),('pretrained_start',deepcopy(warm),'learn',False)]:
            score,_=rollout(layer,test_trace,seed,6,mode,legacy=legacy)
            results.append({'player':person,'condition':condition,**score})
        for condition,layer,legacy,labels in [('v2',old,True,'reward'),('v3_cold',cold,False,'reward'),
                                            ('v3_pretrained',warm,False,'reward'),('zero_reward',zero,False,'zero'),
                                            ('shuffled_reward',shuffled,False,'shuffled')]:
            before=layer.weights.copy()
            score,rows=rollout(layer,train_trace,seed,12,training=True,legacy=legacy,labels=labels)
            if labels=='reward':assert not np.array_equal(before,layer.weights)
            curves.extend({'player':person,'condition':condition,**row} for row in rows)
            frozen=layer.weights.copy()
            score,_=rollout(layer,test_trace,seed,6,legacy=legacy)
            np.testing.assert_array_equal(layer.weights,frozen)
            results.append({'player':person,'condition':condition,**score})
        # Evaluation of a new preference after the first personality has been learned.
        for condition,layer,legacy in [('v2_changed',old,True),('v3_changed',warm,False)]:
            score,_=rollout(deepcopy(layer),test_trace,seed,6,changed=True,legacy=legacy)
            results.append({'player':person,'condition':condition+'_before',**score})
            _,rows=rollout(layer,train_trace,seed,6,training=True,changed=True,legacy=legacy)
            curves.extend({'player':person,'condition':condition,**row} for row in rows)
            frozen=layer.weights.copy();score,_=rollout(layer,test_trace,seed,6,changed=True,legacy=legacy)
            np.testing.assert_array_equal(layer.weights,frozen)
            results.append({'player':person,'condition':condition,**score})
        warm.path=REPORT/'retention-check.json';warm.save();retained=Readout(seed,warm.path);retained.load()
        np.testing.assert_array_equal(retained.weights,warm.weights)
        for condition,layer,ablate in [('retained',retained,False),('reset',Readout(seed),False),('neural_ablated',deepcopy(retained),True)]:
            score,_=rollout(layer,test_trace,seed,6,changed=True,ablate=ablate)
            results.append({'player':person,'condition':condition,**score})
        print(f'Held-out player {person+1}/24 complete',flush=True)
    means={c:float(np.mean([r['mean_response'] for r in results if r['condition']==c])) for c in sorted({r['condition'] for r in results})}
    def paired(a,b):
        differences=[next(r['mean_response'] for r in results if r['player']==p and r['condition']==a)-next(r['mean_response'] for r in results if r['player']==p and r['condition']==b) for p in range(24)]
        boot=np.mean(np.random.default_rng(807).choice(differences,(10000,24)),axis=1)
        return {'mean':float(np.mean(differences)),'interval_95':np.quantile(boot,[.025,.975]).tolist(),'positive_players':int(np.count_nonzero(np.array(differences)>0))}
    comparisons={f'{a}_minus_{b}':paired(a,b) for a,b in [('v3_pretrained','v2'),('v3_pretrained','random'),
                 ('v3_changed','v2_changed'),('v3_changed','v3_changed_before'),('pretrained_start','cold_start')]}
    report={'kind':'Synthetic response and habituation simulator; NOT measured human fear','confirmation':confirm,
        'model':Readout.MODEL,'training_players':48,'held_out_players':24,'training_events':prior.updates,
        'neural':traces['metadata'],'means':means,'comparisons':comparisons,'results':results,
        'budget':'Identical 5/60s, 8s gap, 16s repeat; 3s decisions; 60 decisions per episode',
        'evaluation':'Frozen weights and no exploration; separate neural contexts and persona seeds',
        'persona_seed_start':28000 if confirm else 18000,
        'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [ROOT/'brain/director.py',ROOT/'brain/connectome.py',Path(__file__),REPORT/'director-v2.py']},
        'limitations':'Synthetic preference families and reused full-graph traces; no human labels, no biological plasticity, no learned timing or learned flight. Each preference change rotates the simulated bias; response rules are not discovered facts about people.'}
    if not confirm:(REPORT/'training.json').write_text(json.dumps(training))
    prefix='confirmation-' if confirm else ''
    (REPORT/(prefix+'curves.jsonl')).write_text(''.join(json.dumps(row)+'\n' for row in curves))
    (REPORT/(prefix+'summary.json')).write_text(json.dumps(report,indent=2))
    print(json.dumps({'means':means,'comparisons':comparisons},indent=2),flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--collect',action='store_true');parser.add_argument('--confirm',action='store_true');args=parser.parse_args()
    REPORT.mkdir(parents=True,exist_ok=True)
    if args.collect:collect(args.confirm)
    else:train(args.confirm)
