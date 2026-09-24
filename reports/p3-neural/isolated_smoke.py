from pathlib import Path
import subprocess,json,os,socket,secrets,time,sys,shutil
root=Path.cwd();b=root/'reports/p3-neural';logs=b/('smoke-session-'+time.strftime('%H%M%S'));logs.mkdir(exist_ok=True)
# Own port, token and learning/history files; leave the user's running launcher alone.
with socket.socket() as sock:sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
env={**os.environ,'FLYFEAR_TOKEN':secrets.token_hex(24),'FLYFEAR_PORT':str(port),'OPENBLAS_NUM_THREADS':'1','OMP_NUM_THREADS':'1'}
server_cmd=[sys.executable,'-m','brain.server','--port',str(port),'--logs',str(logs),'--allow-control']
cmd=[str(root/'tools/Godot_v4.5.2-stable_win64_console.exe'),'--headless','--path','game','--','--smoke']
server=None
try:
 with (logs/'brain.log').open('w',encoding='utf-8') as out:
  server=subprocess.Popen(server_cmd,env=env,stdout=out,stderr=out)
  deadline=time.monotonic()+40
  while '"ready": true' not in (logs/'brain.log').read_text(encoding='utf-8'):
   assert server.poll() is None,'server exited'
   assert time.monotonic()<deadline,'server startup timed out'
   time.sleep(.2)
  p=subprocess.run(cmd,env=env,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=170)
  r=dict(command=cmd,server_command=server_cmd,cwd=str(root),inputs='real MaleCNS; isolated ephemeral port/token; own learning/history directory',stdout=p.stdout,stderr=p.stderr,exit_code=p.returncode)
  (b/'modified-isolated-smoke.json').write_text(json.dumps(r,indent=2));print('isolated smoke:',p.returncode,p.stderr)
  if p.returncode==0:
   shutil.copyfile(root/'reports/game-smoke.json',b/'game-smoke.json');print('passed:',json.loads((b/'game-smoke.json').read_text(encoding='utf-8'))['passed'])
finally:
 if server and server.poll() is None:
  server.terminate();server.wait(timeout=10)
