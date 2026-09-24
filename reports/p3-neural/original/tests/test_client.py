"""Synthetic slow server fixture verifies production Godot client's deadline."""
import asyncio
import json
import os
from pathlib import Path
import unittest
from websockets.asyncio.server import serve
from websockets.exceptions import ConnectionClosed
from brain.connectome import ROOT

class ClientDeadlineTests(unittest.IsolatedAsyncioTestCase):
    async def test_delayed_reply_never_reaches_game(self):
        async def slow(ws):
            try:
                await ws.send(json.dumps({'type':'hello','info':{'fixture':'synthetic test only'}}))
                async for raw in ws:
                    data=json.loads(raw)
                    if data['type']=='start': await ws.send('{"type":"started"}')
                    if data['type']=='decision':
                        await asyncio.sleep(1.85)
                        await ws.send(json.dumps({'type':'decision','id':data['id'],'action':'lights'}))
            except ConnectionClosed: pass
        async with serve(slow,'127.0.0.1',0) as server:
            port=server.sockets[0].getsockname()[1]
            proc=await asyncio.create_subprocess_exec(str(ROOT/'tools/Godot.app/Contents/MacOS/Godot'),
                '--headless','--path',str(ROOT/'game'),'--script',str(ROOT/'tests/client.gd'),
                env={**os.environ,'FLYFEAR_PORT':str(port),'FLYFEAR_TOKEN':'test-latency-fixture'},
                stdout=asyncio.subprocess.PIPE,stderr=asyncio.subprocess.STDOUT)
            try:
                output,_=await asyncio.wait_for(proc.communicate(),12)
                self.assertEqual(proc.returncode,0,output.decode())
                self.assertIn('PASS: delayed response discarded',output.decode())
            finally:
                if proc.returncode is None:proc.kill();await proc.wait()

if __name__=='__main__':unittest.main(verbosity=2)
