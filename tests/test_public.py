"""Real public endpoint: isolated brains, shared durable learning, and trust boundaries."""
import asyncio
import copy
import json
import os
from pathlib import Path
import runpy
import socket
import subprocess
import sys
import tempfile
import time
import unittest

import numpy as np
from scipy.sparse import csr_matrix
from websockets.asyncio.client import connect
from websockets.exceptions import ConnectionClosed, InvalidStatus
from brain.connectome import Connectome, ROOT
from brain.director import normalize


def run_disconnect_worker():
    """Hold one real matrix operation so the disconnect cannot miss inference."""
    directory = Path(sys.argv[sys.argv.index('--logs') + 1])
    multiply = csr_matrix.__matmul__
    def gated_multiply(matrix, state):
        result = multiply(matrix, state)
        try:
            (directory / 'hold-compute').unlink()
        except FileNotFoundError:
            return result
        (directory / 'computing').touch()
        deadline = time.monotonic() + 10
        while not (directory / 'release-compute').exists():
            if time.monotonic() >= deadline:
                raise RuntimeError('Test did not release neural computation')
            time.sleep(.005)
        return result
    csr_matrix.__matmul__ = gated_multiply
    runpy.run_module('brain.server', run_name='__main__')


class PublicTests(unittest.IsolatedAsyncioTestCase):
    async def test_shared_learning_without_sharing_player_state(self):
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0))
            port = sock.getsockname()[1]
        origin = 'https://play.invalid'
        uri = f'ws://127.0.0.1:{port}/ws'
        reference = await asyncio.to_thread(Connectome)
        second = copy.copy(reference)
        second.state = np.zeros_like(reference.state)
        inputs = [dict(x=-2, z=-9, look_z=-1, speed=0, retreat=0, turn_rate=0),
                  dict(x=3, z=2, look_x=1, speed=3.2, retreat=1, turn_rate=20)]
        expected = [await asyncio.to_thread(model.step, normalize(t)) for model, t in zip((reference, second), inputs)]
        # Unknown identity-shaped fields must not leak into stored training data.
        inputs[0]['email'] = 'not-stored@example.invalid'
        inputs[0]['ip'] = '198.51.100.77'
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            output = (directory / 'server.log').open('w')
            command = [sys.executable, '-c',
                       'from tests.test_public import run_disconnect_worker; run_disconnect_worker()',
                       '--port', str(port), '--logs', str(directory),
                       '--public-origin', origin, '--allow-control', '--max-clients', '3']
            env = {**os.environ, 'OPENBLAS_NUM_THREADS': '1', 'OMP_NUM_THREADS': '1'}
            process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=output, stderr=output)
            async def receive(ws, kind):
                for _ in range(20):
                    message = json.loads(await asyncio.wait_for(ws.recv(), 10))
                    if message.get('type') == kind:
                        return message
                self.fail(f'Missing {kind}')
            async def send(ws, kind, **data):
                await ws.send(json.dumps({'type': kind, **data}))
            async def ready():
                for _ in range(100):
                    try:
                        return await connect(uri, origin=origin, proxy=None)
                    except OSError:
                        if process.poll() is not None:
                            self.fail((directory / 'server.log').read_text())
                        await asyncio.sleep(.1)
                self.fail('Public worker did not start')
            try:
                first = await ready()
                async with first, connect(uri, origin=origin, proxy=None) as other:
                    for ws in (first, other):
                        hello = await receive(ws, 'hello')
                        self.assertEqual(hello['info']['neurons'], 166700)
                        self.assertTrue(hello['info']['learning_only'])
                        self.assertTrue(hello['memory']['shared'])
                        self.assertEqual(hello['memory']['recent'], [])
                    for bad_origin in (None, 'https://untrusted.invalid'):
                        with self.assertRaises(InvalidStatus):
                            await connect(uri, origin=bad_origin, proxy=None)
                    async with connect(uri + '?token=ignored', origin=origin, proxy=None) as wrong:
                        with self.assertRaises(ConnectionClosed):
                            await wrong.recv()
                    async with connect(uri, origin=origin, proxy=None) as third:
                        await receive(third, 'hello')
                        async with connect(uri, origin=origin, proxy=None) as excess:
                            with self.assertRaises(ConnectionClosed):
                                await excess.recv()
                            self.assertEqual(excess.close_code, 1013)
                    await send(first, 'start', mode='fixed', seed=7, interval=2)
                    await receive(first, 'error')
                    await send(first, 'reset')
                    await receive(first, 'error')
                    for index, ws in enumerate((first, other)):
                        await send(ws, 'start', mode='learn', seed=index + 7, interval=2, round_id='same-untrusted-id')
                        started = await receive(ws, 'started')
                        self.assertNotEqual(started['session'], 'same-untrusted-id')
                    await asyncio.sleep(2)
                    for index, ws in enumerate((first, other)):
                        await send(ws, 'decision', id=1, telemetry=inputs[index])
                    results = await asyncio.gather(receive(first, 'decision'), receive(other, 'decision'))
                    for result, prediction in zip(results, expected):
                        self.assertNotEqual(result['action'], 'wait')
                        np.testing.assert_allclose(result['neural']['output'], prediction['output'], atol=1e-7)
                        np.testing.assert_allclose(result['neural']['readout'], prediction['readout'], atol=1e-7)
                        self.assertEqual(result['neural']['view_activity'], prediction['view_activity'])
                    for index, ws in enumerate((first, other)):
                        await send(ws, 'applied', id=1, accepted=True, telemetry=inputs[index])
                        await receive(ws, 'feedback_open')
                        await send(ws, 'feedback', id=1, rating=index * 2)
                        await receive(ws, 'reward')
                        await receive(ws, 'feedback')
                    saved = json.loads((directory / 'learning-v3.json').read_text())
                    self.assertEqual(saved['updates'], 2)
                    self.assertEqual(saved['feedback_counts']['rating'], 2)
                    await send(first, 'feedback', id=1, rating=2)
                    await receive(first, 'error')
                    await send(other, 'reset')
                    await receive(other, 'error')
                    self.assertEqual(json.loads((directory / 'learning-v3.json').read_text()), saved)
                    # Restarting a round must not clear the public event budget.
                    await send(first, 'start', mode='learn', seed=7, interval=2)
                    await receive(first, 'started')
                    await asyncio.sleep(2)
                    await send(first, 'decision', id=2, telemetry=inputs[0])
                    self.assertEqual((await receive(first, 'decision'))['action'], 'wait')
                    for ws in (first, other):
                        await send(ws, 'finish', outcome='won')
                        done = await receive(ws, 'finished')
                        self.assertEqual(done['memory']['updates'], 2)
                        self.assertEqual(done['memory']['recent'], [])
                    # Hiding the web tab cancels both motion and manual feedback, including after resume.
                    async with connect(uri, origin=origin, proxy=None) as paused:
                        await receive(paused, 'hello')
                        await send(paused, 'start', mode='learn', seed=3, interval=2)
                        await receive(paused, 'started')
                        await asyncio.sleep(2)
                        await send(paused, 'decision', id=40, telemetry=inputs[0])
                        self.assertNotEqual((await receive(paused, 'decision'))['action'], 'wait')
                        await send(paused, 'applied', id=40, accepted=True, telemetry=inputs[0])
                        await receive(paused, 'feedback_open')
                        saved_bytes = (directory / 'learning-v3.json').read_bytes()
                        await send(paused, 'pause')
                        await send(paused, 'decision', id=41, telemetry=inputs[0])
                        with self.assertRaises(asyncio.TimeoutError):
                            await asyncio.wait_for(paused.recv(), .25)
                        for kind in ('pause', 'resume'):
                            await send(paused, kind)
                            await send(paused, 'feedback', id=40, rating=2)
                            message = json.loads(await asyncio.wait_for(paused.recv(), 2))
                            self.assertEqual(message['type'], 'error')
                        for _ in range(23):
                            await send(paused, 'telemetry', telemetry=inputs[0])
                            await asyncio.sleep(.1)
                        with self.assertRaises(asyncio.TimeoutError):
                            await asyncio.wait_for(paused.recv(), .25)
                        await send(paused, 'finish', outcome='quit')
                        self.assertEqual((await receive(paused, 'finished'))['memory']['updates'], 2)
                        self.assertEqual((directory / 'learning-v3.json').read_bytes(), saved_bytes)
                    # Drop one socket inside a real step; the other must still meet the web deadline.
                    abandoned = []
                    for ws in (first, other):
                        await send(ws, 'start', mode='learn', seed=7, interval=2)
                        abandoned.append((await receive(ws, 'started'))['session'])
                    await asyncio.sleep(2)
                    (directory / 'hold-compute').touch()
                    await send(first, 'decision', id=50, telemetry=inputs[0])
                    async with asyncio.timeout(5):
                        while not (directory / 'computing').exists():
                            await asyncio.sleep(.005)
                    first.transport.abort()
                    try:
                        started = time.monotonic()
                        await send(other, 'decision', id=51, telemetry=inputs[1])
                        result = await asyncio.wait_for(receive(other, 'decision'), 5)
                        elapsed = time.monotonic() - started
                        self.assertEqual(result['id'], 51)
                        self.assertLess(elapsed, 5)
                        self.assertNotEqual(result['action'], 'wait')
                        np.testing.assert_allclose(result['neural']['readout'], expected[1]['readout'], atol=1e-7)
                        self.assertEqual(result['neural']['view_activity'], expected[1]['view_activity'])
                        # ACK promptly, within the server's separate 1.5-second application limit.
                        await send(other, 'applied', id=51, accepted=True, telemetry=inputs[1])
                        await receive(other, 'feedback_open')
                    finally:
                        (directory / 'release-compute').touch()
                    async with asyncio.timeout(5):
                        while True:
                            events = [json.loads(line) for line in (directory / 'gameplay.jsonl').read_text().splitlines()]
                            if any(e['type'] == 'finished' and e['session'] == abandoned[0] for e in events):
                                break
                            await asyncio.sleep(.01)
                    async with connect(uri, origin=origin, proxy=None) as replacement:
                        hello = await receive(replacement, 'hello')
                        self.assertEqual(hello['memory']['updates'], 2)
                        # A confirmed event with an incomplete reaction window must not train either.
                        await send(other, 'telemetry', telemetry=inputs[1])
                        other.transport.abort()
                    self.assertEqual((directory / 'learning-v3.json').read_bytes(), saved_bytes)
                    print(f'Disconnect during neural step: survivor RTT {elapsed * 1000:.2f} ms < 5000 ms; replacement accepted', flush=True)
                process.terminate()
                await asyncio.to_thread(process.wait, 10)
                records = (directory / 'gameplay.jsonl').read_text()
                for forbidden in ('not-stored@', '198.51.100.77', 'raw_inputs', 'view_activity', 'same-untrusted-id'):
                    self.assertNotIn(forbidden, records)
                events = [json.loads(line) for line in records.splitlines()]
                rewards = [e for e in events if e['type'] == 'reward']
                self.assertEqual(len(rewards), 2)
                self.assertTrue(all(len(e['features']) == 13 for e in rewards))
                self.assertNotEqual(rewards[0]['session'], rewards[1]['session'])
                lost = [e for e in events if e['type'] == 'finished' and e['session'] in abandoned]
                self.assertEqual(len(lost), 2)
                self.assertTrue(all(e['outcome'] == 'connection_lost' and e['summary']['rewards'] == 0 for e in lost))
                self.assertEqual(sorted(e['summary']['events'] for e in lost), [0, 1])
                self.assertEqual((directory / 'learning-v3.json').read_bytes(), saved_bytes)
                # A later visitor and a new worker must see the same saved shared model.
                process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=output, stderr=output)
                ws = await ready()
                async with ws:
                    hello = await receive(ws, 'hello')
                    self.assertEqual(hello['memory']['updates'], 2)
                    self.assertEqual(hello['memory']['feedback_counts']['rating'], 2)
                    self.assertEqual(hello['memory']['recent'], [])
                    self.assertEqual(json.loads((directory / 'learning-v3.json').read_text()), saved)
                    # Flooding is bounded even when no round has started.
                    for _ in range(41):
                        await send(ws, 'telemetry', telemetry={})
                    with self.assertRaises(ConnectionClosed):
                        await ws.recv()
                    self.assertEqual(ws.close_code, 1008)
            finally:
                if process.poll() is None:
                    process.terminate()
                    await asyncio.to_thread(process.wait, 10)
                output.close()


if __name__ == '__main__':
    unittest.main(verbosity=2)
