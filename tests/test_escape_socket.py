"""Real backend and production Godot client. No user's processes or memory touched."""
import asyncio
import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import tempfile
import time
import unittest

from websockets.asyncio.client import connect
from brain.connectome import ROOT
from tools.godot_path import godot_path


class EscapeSocketTests(unittest.IsolatedAsyncioTestCase):
    async def test_live_protocol_and_godot(self):
        with socket.socket() as sock:
            sock.bind(('127.0.0.1',0)); port=sock.getsockname()[1]
        with tempfile.TemporaryDirectory() as tmp:
            token=secrets.token_hex(24)
            env={**os.environ,'FLYFEAR_TOKEN':token,'FLYFEAR_PORT':str(port)}
            with open(Path(tmp)/'server.log','w') as output:
                proc=subprocess.Popen([sys.executable,'-m','brain.server','--port',str(port),'--logs',tmp],
                                      cwd=ROOT,env=env,stdout=output,stderr=output)
                async def receive(ws,kind):
                    for _ in range(20):
                        message=json.loads(await asyncio.wait_for(ws.recv(),10))
                        if message.get('type')==kind:return message
                    self.fail('Missing '+kind)
                async def send(ws,kind,**fields):await ws.send(json.dumps({'type':kind,**fields}))
                try:
                    uri=f'ws://127.0.0.1:{port}/{token}'
                    for _ in range(200):
                        try: ws=await connect(uri,proxy=None);break
                        except OSError:
                            if proc.poll() is not None:self.fail((Path(tmp)/'server.log').read_text())
                            await asyncio.sleep(.1)
                    else:self.fail('Backend readiness timeout')
                    async with ws:
                        await receive(ws,'hello')
                        t={'vision':{},'threat':{'level':1,'bearing':-1}}
                        await send(ws,'escape',id=1,telemetry=t)
                        self.assertNotIn('neural',await receive(ws,'escape'))
                        await send(ws,'start',mode='learn',seed=42)
                        await receive(ws,'started')
                        start=time.perf_counter()
                        await send(ws,'escape',id=2,telemetry=t)
                        result=await receive(ws,'escape')
                        self.assertEqual(result['id'],2)
                        self.assertLess(result['neural']['escape']['lateral'],-.5)
                        print('ESCAPE_SOCKET_RTT_MS',round((time.perf_counter()-start)*1000,2),flush=True)
                        await send(ws,'escape',id=3,telemetry=t)
                        self.assertEqual((await receive(ws,'escape'))['reason'],'cooldown')
                        await send(ws,'escape',id=True,telemetry=t)
                        await receive(ws,'error')
                        await send(ws,'escape',id=4,telemetry={'threat':{'level':float('nan')}})
                        await receive(ws,'error')
                        await send(ws,'pause')
                        await send(ws,'escape',id=5,telemetry=t)
                        self.assertEqual((await receive(ws,'escape'))['reason'],'inactive')
                        await send(ws,'resume')
                        await asyncio.sleep(.3)
                        t['threat']['bearing']=1
                        await send(ws,'escape',id=6,telemetry=t)
                        self.assertGreater((await receive(ws,'escape'))['neural']['escape']['lateral'],.5)
                        await send(ws,'finish',outcome='quit')
                        end=await receive(ws,'finished')
                        self.assertEqual(end['memory']['updates'],0)
                        self.assertEqual(end['memory']['recent'][-1]['events'],0)
                    await asyncio.sleep(.3)
                    exe=godot_path()
                    result=await asyncio.to_thread(subprocess.run,[str(exe),'--headless','--path','game','--script','../tests/escape_live.gd'],
                                                   cwd=ROOT,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=45)
                    print(result.stdout,flush=True)
                    self.assertEqual(result.returncode,0,result.stdout+result.stderr)
                    self.assertNotIn('SCRIPT ERROR',result.stderr)
                    self.assertIn('LIVE_ESCAPE_RESULTS',result.stdout)
                finally:
                    proc.terminate()
                    await asyncio.to_thread(proc.wait,10)


if __name__=='__main__': unittest.main()

