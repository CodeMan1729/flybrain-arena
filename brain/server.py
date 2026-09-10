"""One CPU connectome process; localhost-only authenticated WebSocket endpoint."""
import argparse
import asyncio
from datetime import datetime, timezone
import json
import os
import signal
from pathlib import Path
import time
import uuid
import numpy as np

from websockets.asyncio.server import serve
from websockets.exceptions import ConnectionClosed
from .connectome import Connectome, ROOT, ACTIONS
from .director import Budget, Readout, normalize, movement, reaction

async def run(port, token, log_dir):
    brain = await asyncio.to_thread(Connectome)
    stopped=asyncio.Event()
    asyncio.get_running_loop().add_signal_handler(signal.SIGTERM,stopped.set)
    busy=False
    log_dir.mkdir(parents=True,exist_ok=True)
    layer=Readout(42,log_dir/'learning-v3.json')
    if layer.path.exists():
        layer.load()  # Corrupt personal memory is never silently overwritten.
    elif (ROOT/'data/learning-prior.json').exists():
        layer.bootstrap(ROOT/'data/learning-prior.json')
    history_path=log_dir/'rounds.json'
    history=json.loads(history_path.read_text()) if history_path.exists() else []
    if not isinstance(history,list):raise ValueError('Invalid round history')
    def memory():
        return {**layer.summary(),'rounds':len(history),'recent':history[-5:]}
    async def handler(ws):
        nonlocal busy
        if ws.request.path != '/'+token or busy:
            await ws.close(1008,'Unauthorized or simulation in use');return
        busy=True
        connection=uuid.uuid4().hex
        log=(log_dir/f'{connection}.jsonl').open('a',buffering=1)
        seed=42;mode='fixed';interval=3.;last_decision=-1e10
        budget=Budget();policy=Readout(seed)
        pending=None;window=None;feedback_event=None;enabled=False;round_data=None;active_since=None
        def record(kind, **data):
            log.write(json.dumps({'type':kind,'utc':datetime.now(timezone.utc).isoformat(),'monotonic':time.monotonic(),
                'connection':connection,'session':round_data['id'] if round_data else None,'seed':seed,'mode':mode,'model':Readout.MODEL,**data},allow_nan=False)+'\n')
        def cancel_window(reason):
            nonlocal pending,window,feedback_event
            if window:record('reward_censored',id=window['id'],reason=reason,samples=len(window['samples']))
            pending=window=feedback_event=None
        def stop_clock():
            nonlocal active_since
            if active_since is not None and round_data:
                round_data['seconds']+=time.monotonic()-active_since
            active_since=None
        def finish(outcome):
            nonlocal round_data,enabled
            if not round_data:return
            stop_clock();cancel_window(outcome);enabled=False
            round_data.update(outcome=outcome,end_utc=datetime.now(timezone.utc).isoformat(),end_updates=layer.updates)
            index=next((i for i,r in enumerate(history) if r['id']==round_data['id']),len(history))
            if index==len(history):history.append(round_data)
            else:history[index]=round_data
            # ponytail: one small JSON history rewritten per round; use SQLite if years of sessions make it slow.
            tmp=history_path.with_suffix('.tmp')
            with tmp.open('w') as f:
                json.dump(history,f,allow_nan=False);f.flush();os.fsync(f.fileno())
            tmp.replace(history_path)
            record('finished',outcome=outcome,summary=round_data)
            round_data=None
        async def send(data):
            await ws.send(json.dumps(data,allow_nan=False))
        async def reward_event(event, reward, source, motion_reward=None):
            nonlocal window
            if mode=='learn':
                layer.update(event['action'],event['features'],reward,source=source);layer.save()
            event['reward']=reward;event['update_index']=layer.updates
            round_data['rewards']+=1;round_data['reward_sum']+=reward
            record('reward',id=event['id'],action=event['action'],reward=reward,source=source,motion_reward=motion_reward,
                baseline=event['baseline'],samples=event['samples'],updates=layer.updates)
            await send({'type':'reward','id':event['id'],'reward':reward,'source':source,'updates':layer.updates,'memory':memory()})
            window=None
        try:
            brain.reset()
            await send({'type':'hello','info':brain.info,'protocol':2,'memory':memory()})
            record('connected',dataset={k:v for k,v in brain.info.items() if k!='view'})
            async for raw in ws:
                try:
                    msg=json.loads(raw)
                    if not isinstance(msg,dict):raise ValueError('Expected object')
                    now=time.monotonic();kind=msg.get('type')
                    if kind=='start':
                        new_mode=msg.get('mode');new_seed=msg.get('seed',42);new_interval=msg.get('interval',3)
                        if new_mode not in ('random','fixed','learn'):raise ValueError('Unknown mode')
                        if type(new_seed) is not int or not 0<=new_seed<2**32:raise ValueError('Seed range')
                        if type(new_interval) not in (int,float) or not 2<=new_interval<=5:raise ValueError('Interval range 2..5 s')
                        rid=msg.get('round_id',uuid.uuid4().hex)
                        if not isinstance(rid,str) or not 1<=len(rid)<=80 or not all(c.isalnum() or c in '-_' for c in rid):raise ValueError('Invalid round id')
                        finish('restarted')
                        seed,mode,interval=new_seed,new_mode,float(new_interval)
                        policy=layer if mode=='learn' else Readout(seed)
                        policy.rng=np.random.default_rng(seed)
                        previous=next((r for r in history if r['id']==rid and r['outcome']=='connection_lost' and r['mode']==mode),None)
                        round_data=dict(previous) if previous else {'id':rid,'start_utc':datetime.now(timezone.utc).isoformat(),
                            'mode':mode,'seed':seed,'seconds':0.,'events':0,'rewards':0,'reward_sum':0.,'start_updates':layer.updates}
                        brain.reset();budget=Budget();cancel_window('start');enabled=msg.get('paused') is not True;last_decision=now;active_since=now if enabled else None
                        record('start',interval=interval,updates=layer.updates,continued=previous is not None)
                        await send({'type':'started','session':rid,'updates':layer.updates,'memory':memory()})
                    elif kind=='pause':
                        stop_clock();enabled=False;cancel_window('pause');record('paused')
                    elif kind=='resume':
                        if not round_data:raise ValueError('Start a round first')
                        if not enabled:active_since=now
                        enabled=True;last_decision=now;record('resumed')
                    elif kind=='finish':
                        outcome=msg.get('outcome')
                        if outcome not in ('won','quit'):raise ValueError('Invalid outcome')
                        finish(outcome)
                        await send({'type':'finished','memory':memory()})
                    elif kind in ('save','reset'):
                        if mode!='learn':raise ValueError('Öğrenme belleği yalnızca öğrenen modda değiştirilebilir')
                        if kind=='reset':
                            if enabled:raise ValueError('Belleği sıfırlamadan önce duraklatın')
                            cancel_window('reset')
                            if layer.path.exists():
                                backup=layer.path.with_name('learning-before-reset-'+str(time.time_ns())+'.json')
                                backup.write_bytes(layer.path.read_bytes())
                            layer.reset()
                        layer.save();record(kind,updates=layer.updates)
                        await send({'type':'parameters','operation':kind,'updates':layer.updates,'memory':memory()})
                    elif kind=='applied':
                        if enabled and pending and msg.get('id')==pending['id'] and now-pending['time']<1.5:
                            accepted=msg.get('accepted') is True
                            baseline=movement(msg.get('telemetry',{}))
                            if accepted and budget.commit(pending['action'],now) and pending['action']!='wait':
                                window={**pending,'time':now,'last_sample':now,'samples':[],'baseline':baseline,'complete':True,'manual':None,'reward':None}
                                feedback_event=window
                                round_data['events']+=1
                                if mode=='learn':await send({'type':'feedback_open','id':pending['id'],'action':pending['action'],'seconds':8})
                            record('applied',id=pending['id'],action=pending['action'],accepted=accepted)
                            pending=None
                    elif kind=='feedback':
                        rating=msg.get('rating');seq=msg.get('id')
                        if (mode!='learn' or not enabled or not feedback_event or type(seq) is not int
                            or seq!=feedback_event['id'] or now-feedback_event['time']>=8
                            or feedback_event['manual'] is not None or type(rating) is not int or rating not in (0,1,2)):
                            raise ValueError('Geri bildirim geçersiz, yinelenmiş veya süresi dolmuş')
                        reward=rating/2;previous=feedback_event['reward']
                        if previous is not None:
                            layer.correct(feedback_event['action'],feedback_event['features'],previous,reward,feedback_event['update_index'])
                            layer.save();round_data['reward_sum']+=reward-previous
                            feedback_event['reward']=reward
                            await send({'type':'reward','id':seq,'reward':reward,'source':'rating','updates':layer.updates,'memory':memory()})
                        else:
                            await reward_event(feedback_event,reward,'rating')
                        feedback_event['manual']=reward
                        record('feedback',id=seq,action=feedback_event['action'],rating=reward,previous_reward=previous,corrected=previous is not None,updates=layer.updates)
                        await send({'type':'feedback','id':seq,'accepted':True})
                    elif kind in ('telemetry','decision'):
                        t=msg.get('telemetry',{});sample=movement(t);values=normalize(t.get('vision',t))
                        if not enabled:continue
                        if window:
                            window['complete'] &= now-window['last_sample']<.4
                            window['last_sample']=now
                            window['samples'].append(sample)
                            if now-window['time']>=2:
                                if window['complete'] and len(window['samples'])>=10:
                                    score=reaction(window['baseline'],window['samples'])
                                    await reward_event(window,score,'motion',score)
                                else:cancel_window('missing telemetry')
                        if kind!='decision':continue
                        seq=msg.get('id')
                        if type(seq) is not int or seq<0:raise ValueError('Invalid request id')
                        if now-last_decision<interval-.05 or window or (pending and now-pending['time']<1.5):
                            await send({'type':'decision','id':seq,'action':'wait','reason':'cooldown'});continue
                        last_decision=now
                        result=await asyncio.to_thread(brain.step,values)
                        allowed=[a for a in ACTIONS[:3] if budget.allowed(a,time.monotonic())]
                        action,x,probabilities=policy.choose(mode,result,allowed)
                        pending={'id':seq,'time':time.monotonic(),'action':action,'features':x}
                        record('decision',id=seq,inputs=values.tolist(),raw_inputs=t,neural=result,action=action,
                            probabilities=probabilities,updates=layer.updates)
                        await send({'type':'decision','id':seq,'action':action,'neural':result,'budget_used':len(budget.events),
                            'updates':layer.updates,'reason':'budget' if not allowed else 'selected'})
                    else:raise ValueError('Unknown message type')
                except (ValueError,KeyError,TypeError,OverflowError) as exc:
                    record('invalid',error=str(exc));await send({'type':'error','message':str(exc),'action':'wait'})
        except ConnectionClosed:pass
        finally:
            try:
                finish('connection_lost')
                record('disconnected')
            finally:log.close();busy=False
    async with serve(handler,'127.0.0.1',port,origins=[None],max_size=8192,max_queue=4,ping_interval=10,ping_timeout=10):
        print(json.dumps({'ready':True,'port':port,'neurons':brain.info['neurons']}),flush=True)
        await stopped.wait()

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--port',type=int,default=8765);p.add_argument('--logs',type=Path,default=ROOT/'logs')
    args=p.parse_args();token=os.environ.get('FLYFEAR_TOKEN','')
    if len(token)<16:raise SystemExit('FLYFEAR_TOKEN must contain >=16 characters')
    try:asyncio.run(run(args.port,token,args.logs))
    except KeyboardInterrupt:pass
