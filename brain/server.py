"""Shared full connectome, isolated player states, and durable reward learning."""
import argparse
import asyncio
from collections import deque
import copy
from datetime import datetime, timezone
from http import HTTPStatus
import json
import logging
from logging.handlers import RotatingFileHandler
import os
import signal
from pathlib import Path
import time
import uuid
from urllib.parse import urlsplit
import numpy as np

from websockets.asyncio.server import serve
from websockets.exceptions import ConnectionClosed
from .connectome import Connectome, ROOT, ACTIONS
from .director import Budget, Readout, normalize, movement, reaction

async def run(port, token, log_dir, *, public_origin=None, allow_control=False, max_clients=8):
    public=public_origin is not None
    if public:
        origin=urlsplit(public_origin)
        if origin.scheme not in ('http','https') or not origin.netloc or origin.path or origin.query or origin.fragment or origin.username:
            raise ValueError('Expected an exact HTTP(S) origin')
        allow_control=False
    brain = await asyncio.to_thread(Connectome)
    stopped=asyncio.Event()
    asyncio.get_running_loop().add_signal_handler(signal.SIGTERM,stopped.set)
    clients=set()
    compute=asyncio.Semaphore(2)
    log_dir.mkdir(parents=True,exist_ok=True)
    layer=Readout(42,log_dir/'learning-v3.json')
    if layer.path.exists():
        layer.load()  # Corrupt personal memory is never silently overwritten.
    elif (ROOT/'data/learning-prior.json').exists():
        layer.bootstrap(ROOT/'data/learning-prior.json')
    history_path=log_dir/('shared-rounds.json' if public else 'rounds.json')
    saved_history=json.loads(history_path.read_text()) if history_path.exists() else (0 if public else [])
    total_rounds=saved_history if public else 0
    if public and (type(total_rounds) is not int or total_rounds<0):raise ValueError('Invalid shared round count')
    history=[] if public else saved_history
    if not isinstance(history,list):raise ValueError('Invalid round history')
    # ponytail: keep 20 MB of anonymous training evidence; the learned model retains all updates.
    public_log=RotatingFileHandler(log_dir/'gameplay.jsonl',maxBytes=5_000_000,backupCount=3,encoding='utf-8') if public else None
    def memory():
        return {**layer.summary(),'rounds':total_rounds if public else len(history),
                'recent':[] if public else history[-5:],'shared':public}
    def save_change(change, *args, **kwargs):
        previous=copy.deepcopy(layer.__dict__)
        try:
            change(*args,**kwargs)
            layer.save()
        except Exception:
            # Every session references this same policy object; restore it in place.
            layer.__dict__=previous
            raise
    def health(ws, request):
        if public and request.path=='/health':
            response=ws.respond(HTTPStatus.OK,json.dumps({'ready':True,'learning':True,'neurons':brain.info['neurons'],
                                                         'updates':layer.updates,'rounds':total_rounds}))
            response.headers['Content-Type']='application/json'
            response.headers['Cache-Control']='no-store'
            return response
    async def handler(ws):
        if ws.request.path != ('/ws' if public else '/'+token):
            await ws.close(1008,'Unauthorized');return
        if len(clients)>=(max_clients if public else 1):
            await ws.close(1013,'Sunucu dolu. Biraz sonra tekrar deneyin.');return
        clients.add(ws)
        # The large read-only graph is shared; each player owns their complete neural state.
        player_brain=copy.copy(brain)
        player_brain.state=np.zeros_like(brain.state)
        connection=uuid.uuid4().hex
        log=None if public else (log_dir/f'{connection}.jsonl').open('a',buffering=1)
        seed=42;mode='learn';interval=3.;last_decision=-1e10;last_start=-1e10
        received=deque()
        choice_rng=np.random.default_rng(seed)
        budget=Budget();policy=Readout(seed)
        pending=None;window=None;feedback_event=None;enabled=False;round_data=None;active_since=None
        def record(kind, **data):
            if public:
                if kind not in ('reward','feedback','finished'):return
                data={k:v for k,v in data.items() if k in ('id','action','reward','source','features','rating','previous_reward','corrected','updates','outcome','summary')}
            entry=json.dumps({'type':kind,'utc':datetime.now(timezone.utc).isoformat(),'monotonic':time.monotonic(),
                'connection':connection,'session':round_data['id'] if round_data else None,'seed':seed,'mode':mode,'model':Readout.MODEL,**data},allow_nan=False,separators=(',',':'))
            if public:public_log.emit(logging.makeLogRecord({'msg':entry,'levelno':logging.INFO,'levelname':'INFO'}))
            else:log.write(entry+'\n')
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
            nonlocal round_data,enabled,total_rounds
            if not round_data:return
            stop_clock();cancel_window(outcome);enabled=False
            round_data.update(outcome=outcome,end_utc=datetime.now(timezone.utc).isoformat(),end_updates=layer.updates)
            if public:total_rounds+=1
            else:
                index=next((i for i,r in enumerate(history) if r['id']==round_data['id']),len(history))
                if index==len(history):history.append(round_data)
                else:history[index]=round_data
            # ponytail: one small JSON history rewritten per round; use SQLite if years of sessions make it slow.
            tmp=history_path.with_suffix('.tmp')
            with tmp.open('w') as f:
                json.dump(total_rounds if public else history,f,allow_nan=False);f.flush();os.fsync(f.fileno())
            tmp.replace(history_path)
            record('finished',outcome=outcome,summary=round_data)
            round_data=None
        async def send(data):
            await ws.send(json.dumps(data,allow_nan=False,separators=(',',':')))
        async def reward_event(event, reward, source, motion_reward=None):
            nonlocal window
            if mode=='learn':
                save_change(layer.update,event['action'],event['features'],reward,source=source)
            event['reward']=reward;event['update_index']=layer.updates
            round_data['rewards']+=1;round_data['reward_sum']+=reward
            record('reward',id=event['id'],action=event['action'],reward=reward,source=source,motion_reward=motion_reward,
                baseline=event['baseline'],samples=event['samples'],features=event['features'].tolist(),updates=layer.updates)
            await send({'type':'reward','id':event['id'],'reward':reward,'source':source,'updates':layer.updates,'memory':memory()})
            window=None
        try:
            await send({'type':'hello','info':{**brain.info,'learning_only':not allow_control,'shared_learning':public},
                        'protocol':2,'memory':memory()})
            record('connected',dataset={k:v for k,v in brain.info.items() if k!='view'})
            while True:
                raw=await asyncio.wait_for(ws.recv(),90 if public else None)
                try:
                    msg=json.loads(raw)
                    if not isinstance(msg,dict):raise ValueError('Expected object')
                    now=time.monotonic();kind=msg.get('type')
                    if public:
                        while received and received[0]<now-1:received.popleft()
                        received.append(now)
                        if len(received)>40:
                            await ws.close(1008,'Message rate exceeded');break
                    if kind=='start':
                        new_mode=msg.get('mode');new_seed=msg.get('seed',42);new_interval=msg.get('interval',3)
                        if new_mode not in ('random','fixed','learn'):raise ValueError('Unknown mode')
                        if not allow_control and new_mode!='learn':raise ValueError('Oyun her turda öğrenir; kontrol modları yalnızca araştırma testleri içindir')
                        if public and now-last_start<2:raise ValueError('Yeni tur için biraz bekleyin')
                        if type(new_seed) is not int or not 0<=new_seed<2**32:raise ValueError('Seed range')
                        if type(new_interval) not in (int,float) or not 2<=new_interval<=5:raise ValueError('Interval range 2..5 s')
                        rid=uuid.uuid4().hex if public else msg.get('round_id',uuid.uuid4().hex)
                        if not isinstance(rid,str) or not 1<=len(rid)<=80 or not all(c.isalnum() or c in '-_' for c in rid):raise ValueError('Invalid round id')
                        finish('restarted')
                        seed,mode,interval=new_seed,new_mode,float(new_interval)
                        policy=layer if mode=='learn' else Readout(seed)
                        choice_rng=np.random.default_rng(seed)
                        previous=next((r for r in history if r['id']==rid and r['outcome']=='connection_lost' and r['mode']==mode),None)
                        round_data=dict(previous) if previous else {'id':rid,'start_utc':datetime.now(timezone.utc).isoformat(),
                            'mode':mode,'seed':seed,'seconds':0.,'events':0,'rewards':0,'reward_sum':0.,'start_updates':layer.updates}
                        player_brain.reset()
                        if not public:budget=Budget()
                        cancel_window('start');enabled=msg.get('paused') is not True;last_decision=last_start=now;active_since=now if enabled else None
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
                        if public:raise ValueError('Ortak öğrenme belleği oyuncular tarafından sıfırlanamaz')
                        if mode!='learn':raise ValueError('Öğrenme belleği yalnızca öğrenen modda değiştirilebilir')
                        if kind=='reset':
                            if enabled:raise ValueError('Belleği sıfırlamadan önce duraklatın')
                            cancel_window('reset')
                            if layer.path.exists():
                                backup=layer.path.with_name('learning-before-reset-'+str(time.time_ns())+'.json')
                                backup.write_bytes(layer.path.read_bytes())
                            save_change(layer.reset)
                        else:layer.save()
                        record(kind,updates=layer.updates)
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
                            sound=msg.get('sound_variant')
                            record('applied',id=pending['id'],action=pending['action'],accepted=accepted,
                                   sound_variant=sound if accepted and pending['action']=='steps' and sound in ('steps','breath','creak','knock') else None)
                            pending=None
                    elif kind=='feedback':
                        rating=msg.get('rating');seq=msg.get('id')
                        if (mode!='learn' or not enabled or not feedback_event or type(seq) is not int
                            or seq!=feedback_event['id'] or now-feedback_event['time']>=8
                            or feedback_event['manual'] is not None or type(rating) is not int or rating not in (0,1,2)):
                            raise ValueError('Geri bildirim geçersiz, yinelenmiş veya süresi dolmuş')
                        reward=rating/2;previous=feedback_event['reward']
                        if previous is not None:
                            save_change(layer.correct,feedback_event['action'],feedback_event['features'],previous,reward,feedback_event['update_index'])
                            round_data['reward_sum']+=reward-previous
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
                        if type(seq) is not int or not 0<=seq<2**53:raise ValueError('Invalid request id')
                        if now-last_decision<interval-.05 or window or (pending and now-pending['time']<1.5):
                            await send({'type':'decision','id':seq,'action':'wait','reason':'cooldown'});continue
                        last_decision=now
                        async with compute:
                            result=await asyncio.to_thread(player_brain.step,values)
                        allowed=[a for a in ACTIONS[:3] if budget.allowed(a,time.monotonic())]
                        action,x,probabilities=policy.choose(mode,result,allowed,rng=choice_rng)
                        pending={'id':seq,'time':time.monotonic(),'action':action,'features':x}
                        record('decision',id=seq,inputs=values.tolist(),raw_inputs=t,neural=result,action=action,
                            probabilities=probabilities,updates=layer.updates)
                        await send({'type':'decision','id':seq,'action':action,'neural':result,'budget_used':len(budget.events),
                            'updates':layer.updates,'reason':'budget' if not allowed else 'selected'})
                    else:raise ValueError('Unknown message type')
                except (ValueError,KeyError,TypeError,OverflowError) as exc:
                    record('invalid',error=str(exc));await send({'type':'error','message':str(exc),'action':'wait'})
        except ConnectionClosed:pass
        except asyncio.TimeoutError:
            await ws.close(1000,'Idle session')
        except OSError:
            stopped.set()  # Stop accepting play if durable learning cannot be saved.
            await ws.close(1011,'Öğrenme kaydı kullanılamıyor')
        finally:
            try:
                finish('connection_lost')
                record('disconnected')
            finally:
                if log:log.close()
                clients.discard(ws)
    async with serve(handler,'127.0.0.1',port,origins=[public_origin] if public else [None],
                     process_request=health,server_header=None,max_size=8192,max_queue=4,ping_interval=10,ping_timeout=10):
        print(json.dumps({'ready':True,'port':port,'neurons':brain.info['neurons']}),flush=True)
        await stopped.wait()
    if public_log:public_log.close()

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--port',type=int,default=8765);p.add_argument('--logs',type=Path,default=ROOT/'logs')
    p.add_argument('--public-origin',default=os.environ.get('FLYFEAR_PUBLIC_ORIGIN'))
    p.add_argument('--allow-control',action='store_true',help='Enable fixed/random modes only for offline research and tests')
    p.add_argument('--max-clients',type=int,default=8)
    args=p.parse_args();token=os.environ.get('FLYFEAR_TOKEN','')
    if not args.public_origin and len(token)<16:raise SystemExit('FLYFEAR_TOKEN must contain >=16 characters')
    if not 1<=args.max_clients<=32:raise SystemExit('max-clients must be 1..32')
    try:asyncio.run(run(args.port,token,args.logs,public_origin=args.public_origin,allow_control=args.allow_control,max_clients=args.max_clients))
    except KeyboardInterrupt:pass
