"""Real local worker integration: auth, neural response, ACK/reward, reset, restart."""
import asyncio
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
import unittest

from websockets.asyncio.client import connect
from websockets.exceptions import ConnectionClosed, InvalidStatus
from brain.connectome import ROOT

class SocketTests(unittest.IsolatedAsyncioTestCase):
    async def test_real_worker(self):
        with socket.socket() as sock:
            sock.bind(('127.0.0.1',0)); port=sock.getsockname()[1]
        token='integration-test-token-42'
        with tempfile.TemporaryDirectory() as tmp:
            output=open(Path(tmp)/'server.log','w')
            proc=subprocess.Popen([sys.executable,'-m','brain.server','--port',str(port),'--logs',tmp,'--allow-control'],
                cwd=ROOT,env={**os.environ,'FLYFEAR_TOKEN':token},stdout=output,stderr=output)
            async def receive(ws,kind):
                for _ in range(20):
                    msg=json.loads(await asyncio.wait_for(ws.recv(),5))
                    if msg.get('type')==kind:return msg
                self.fail(f'Missing message {kind}')
            try:
                uri=f'ws://127.0.0.1:{port}/{token}'
                for _ in range(60):
                    try:
                        ws=await connect(uri,proxy=None);break
                    except OSError:await asyncio.sleep(.1)
                else:self.fail('Worker failed to start')
                async with ws:
                    hello=await receive(ws,'hello');self.assertEqual(hello['info']['neurons'],166700)
                    with self.assertRaises(InvalidStatus):
                        await connect(uri,origin='https://example.com',proxy=None)
                    async with connect(f'ws://127.0.0.1:{port}/wrong-token',proxy=None) as bad:
                        with self.assertRaises(ConnectionClosed): await bad.recv()
                    await ws.send('{"type":"decision","id":1,"telemetry":{"x":"bad"}}')
                    self.assertEqual((await receive(ws,'error'))['action'],'wait')
                    # Seed 3 selects a nonwait action first for a measurable reward test.
                    await ws.send(json.dumps({'type':'start','mode':'learn','seed':3,'interval':2}))
                    await receive(ws,'started');await asyncio.sleep(2)
                    t={'x':1,'z':0,'look_x':0,'look_z':-1,'speed':3.2,'retreat':0,'turn_rate':0,'pause_seconds':0}
                    await ws.send(json.dumps({'type':'decision','id':2,'telemetry':t}))
                    result=await receive(ws,'decision')
                    self.assertEqual(result['id'],2);self.assertGreater(result['neural']['active_neurons'],0)
                    self.assertNotEqual(result['action'],'wait')
                    await ws.send(json.dumps({'type':'applied','id':2,'accepted':True,'telemetry':t,'sound_variant':'knock'}))
                    t.update(speed=0,retreat=3.2,turn_rate=180)
                    for _ in range(23):
                        await ws.send(json.dumps({'type':'telemetry','telemetry':t}));await asyncio.sleep(.1)
                    reward=await receive(ws,'reward');self.assertEqual(reward['updates'],1);self.assertEqual(reward['reward'],1)
                    saved=json.loads((Path(tmp)/'learning-v3.json').read_text())
                    self.assertEqual(saved['updates'],1) # Automatic persistence without clicking Save.
                    await ws.send(json.dumps({'type':'feedback','id':2,'rating':0}))
                    corrected=await receive(ws,'reward')
                    self.assertEqual(corrected['reward'],0);self.assertEqual(corrected['updates'],1)
                    self.assertEqual(corrected['memory']['feedback_counts'],{'motion':0,'rating':1,'simulation':0})
                    await receive(ws,'feedback')
                    await ws.send(json.dumps({'type':'feedback','id':2,'rating':2}))
                    await receive(ws,'error') # A repeated rating cannot train twice.
                    # Duplicate ACK cannot train twice.
                    await ws.send(json.dumps({'type':'applied','id':2,'accepted':True,'telemetry':t}))
                    await ws.send('{"type":"save"}')
                    self.assertEqual((await receive(ws,'parameters'))['updates'],1)
                    self.assertTrue((Path(tmp)/'learning-v3.json').exists())
                    await ws.send('{"type":"finish","outcome":"won"}')
                    finished=await receive(ws,'finished')
                    self.assertEqual(finished['memory']['rounds'],1)
                    self.assertEqual(finished['memory']['recent'][-1]['rewards'],1)
                    self.assertEqual(finished['memory']['recent'][-1]['reward_sum'],0)
                    await ws.send(json.dumps({'type':'start','mode':'fixed','seed':3,'interval':2}))
                    await receive(ws,'started')
                    await ws.send('{"type":"save"}')
                    await receive(ws,'error')
                    self.assertEqual(json.loads((Path(tmp)/'learning-v3.json').read_text())['updates'],1)
                    await ws.send(json.dumps({'type':'start','mode':'learn','seed':3,'interval':2}))
                    self.assertEqual((await receive(ws,'started'))['updates'],1)
                    await asyncio.sleep(2)
                    await ws.send(json.dumps({'type':'decision','id':4,'telemetry':t}))
                    await receive(ws,'decision')
                    await ws.send(json.dumps({'type':'applied','id':4,'accepted':True,'telemetry':t}))
                    await receive(ws,'feedback_open')
                    await ws.send(json.dumps({'type':'feedback','id':99,'rating':2}))
                    await receive(ws,'error')
                    await ws.send(json.dumps({'type':'feedback','id':4,'rating':True}))
                    await receive(ws,'error')
                    await ws.send(json.dumps({'type':'feedback','id':4,'rating':2}))
                    early=await receive(ws,'reward')
                    self.assertEqual(early['updates'],2);self.assertEqual(early['reward'],1)
                    self.assertEqual(early['memory']['feedback_counts']['rating'],2)
                    await receive(ws,'feedback')
                    await ws.send('{"type":"pause"}')
                    await ws.send('{"type":"reset"}')
                    self.assertEqual((await receive(ws,'parameters'))['updates'],0)
                    await ws.send('{"type":"pause"}')
                    await ws.send(json.dumps({'type':'decision','id':3,'telemetry':t}))
                    with self.assertRaises(asyncio.TimeoutError):await asyncio.wait_for(ws.recv(),.25)
                await asyncio.sleep(.15)
                with (Path(tmp)/'godot-feedback.log').open('w') as game_output:
                    game=await asyncio.create_subprocess_exec(str(ROOT/'tools/Godot.app/Contents/MacOS/Godot'),
                        '--headless','--path',str(ROOT/'game'),'--script','../tests/feedback.gd',
                        env={**os.environ,'FLYFEAR_TOKEN':token,'FLYFEAR_PORT':str(port)},stdout=game_output,stderr=game_output)
                    try:
                        self.assertEqual(await asyncio.wait_for(game.wait(),20),0,(Path(tmp)/'godot-feedback.log').read_text())
                    finally:
                        if game.returncode is None:game.terminate();await game.wait()
                saved=json.loads((Path(tmp)/'learning-v3.json').read_text())
                self.assertEqual(saved['updates'],1);self.assertEqual(saved['feedback_counts']['rating'],1)
                async with connect(uri,proxy=None) as ws2:
                    self.assertEqual((await receive(ws2,'hello'))['protocol'],2)
                    await ws2.send(json.dumps({'type':'start','mode':'random','seed':1,'interval':2}))
                    await receive(ws2,'started');await asyncio.sleep(2)
                    await ws2.send(json.dumps({'type':'decision','id':99,'telemetry':t}))
                    self.assertEqual((await receive(ws2,'decision'))['action'],'steps')
                    await ws2.send(json.dumps({'type':'applied','id':99,'accepted':True,'telemetry':t,'sound_variant':'knock'}))
                    await ws2.send('{"type":"finish","outcome":"quit"}')
                    await receive(ws2,'finished')
                    proc.terminate();await asyncio.to_thread(proc.wait,5)
                    with self.assertRaises(ConnectionClosed):await ws2.recv()
                lines=[json.loads(s) for f in Path(tmp).glob('*.jsonl') for s in f.read_text().splitlines()]
                self.assertTrue(any(x['type']=='decision' and 'neural' in x and 'inputs' in x for x in lines))
                self.assertTrue(any(x['type']=='applied' and x['id']==2 and x.get('sound_variant')==('knock' if result['action']=='steps' else None) for x in lines))
                self.assertTrue(any(x['type']=='applied' and x['id']==99 and x['action']=='steps' and x['sound_variant']=='knock' for x in lines))
                self.assertEqual(sum(x['type']=='reward' for x in lines),3)
            finally:
                if proc.poll() is None:proc.terminate();proc.wait(timeout=5)
                output.close()

if __name__=='__main__':unittest.main(verbosity=2)
