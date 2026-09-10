"""Single owner: launch local brain + native Godot; reap only owned children."""
import fcntl
import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import time
import psutil

ROOT=Path(__file__).resolve().parents[1]
os.chdir(ROOT)
(ROOT/'logs').mkdir(exist_ok=True)
lock=(ROOT/'logs/launcher.lock').open('w')
try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
except BlockingIOError:raise SystemExit('FLYFEAR zaten çalışıyor. Açık oyuna dönün.')
args=sys.argv[1:]
testing='--smoke' in args or '--benchmark' in args
headless='--headless' in args
log_dir=ROOT/'logs'/('validation' if testing else 'sessions')
stamp=time.strftime('%Y%m%d-%H%M%S')
if testing:log_dir=log_dir/stamp
log_dir.mkdir(parents=True,exist_ok=True)
with socket.socket() as sock:
    sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
env={**os.environ,'FLYFEAR_TOKEN':secrets.token_hex(24),'FLYFEAR_PORT':str(port),'OPENBLAS_NUM_THREADS':'1','OMP_NUM_THREADS':'1'}
server_log=log_dir/f'{stamp}-brain.log'; game_log=log_dir/f'{stamp}-game.log'
server=None;game=None;measurements=[];exit_code=1
try:
    with server_log.open('w') as output:
        server=subprocess.Popen([str(ROOT/'.venv/bin/python'),'-m','brain.server','--port',str(port),'--logs',str(log_dir)],env=env,stdout=output,stderr=output)
    deadline=time.monotonic()+20
    while '"ready": true' not in server_log.read_text():
        if server.poll() is not None:raise RuntimeError(server_log.read_text())
        if time.monotonic()>deadline:raise RuntimeError('Beyin 20 saniyede hazır olmadı; log: '+str(server_log))
        time.sleep(.1)
    print('FLYFEAR hazır · localhost · tam MaleCNS grafiği',flush=True)
    command=[str(ROOT/'tools/Godot.app/Contents/MacOS/Godot'),'--path',str(ROOT/'game')]
    if headless:command.append('--headless')
    if args:command+=['--']+[a for a in args if a!='--headless']
    with game_log.open('w') as output:
        game=subprocess.Popen(command,env=env,stdout=output,stderr=output)
    started=time.monotonic()
    while game.poll() is None:
        now=time.monotonic()
        try:
            measurements.append({'seconds':round(now-started,2),'game_rss_mb':psutil.Process(game.pid).memory_info().rss/2**20,
                                 'brain_rss_mb':psutil.Process(server.pid).memory_info().rss/2**20 if server.poll() is None else 0})
        except psutil.NoSuchProcess:pass
        if testing and now-started>140:
            raise RuntimeError('Otomatik oyun testi 140 saniyeyi aştı; '+str(game_log))
        if 'SCRIPT ERROR' in game_log.read_text():raise RuntimeError(game_log.read_text()[:8000])
        time.sleep(.5)
    exit_code=game.returncode
    print('Oyun günlüğü: '+str(game_log),flush=True)
except KeyboardInterrupt:
    exit_code=130
except Exception as exc:
    print(str(exc),file=sys.stderr)
finally:
    for proc in (game,server):
        if proc and proc.poll() is None:
            proc.terminate()
            try:proc.wait(timeout=5)
            except subprocess.TimeoutExpired:proc.kill();proc.wait()
    memory={'samples':len(measurements),'game_peak_rss_mb':max((m['game_rss_mb'] for m in measurements),default=0),
            'brain_peak_rss_mb':max((m['brain_rss_mb'] for m in measurements),default=0),'trace':measurements,
            'game_exit_code':exit_code,'game_log':str(game_log.relative_to(ROOT)),'headless':headless}
    (log_dir/f'{stamp}-memory.json').write_text(json.dumps(memory,indent=2))
    if testing:
        (ROOT/'reports'/('runtime-headless.json' if headless else 'runtime-rendered.json')).write_text(json.dumps(memory,indent=2))
        if not headless:
            mode=next((a.split('=',1)[1] for a in args if a.startswith('--mode=')),'learn')
            (ROOT/'reports'/f'runtime-{mode}.json').write_text(json.dumps(memory,indent=2))
sys.exit(exit_code)
