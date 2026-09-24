import json,subprocess,sys,time,os
sys.stdout.reconfigure(encoding="utf-8")
os.environ["PYTHONIOENCODING"]="utf-8"
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; base=Path(__file__).resolve().parent
python=str(ROOT/'.venv/Scripts/python.exe'); godot=str(ROOT/'tools/Godot_v4.5.2-stable_win64_console.exe')
commands=[('python-all',[python,'-m','unittest','discover','-s','tests','-v'])]
for name in ['combat_feedback','escape','combat_round','weapon_view','gameplay','pursuit','fly','hud','drone_visual','mobile','report','settings','brain_view']:
 commands.append((name,[godot,'--headless','--path','game','--script','../tests/'+name+'.gd']+(['--fixed-fps','60'] if name in ['pursuit','fly'] else [])))
commands.append(('test-ps1',["powershell","-NoProfile","-ExecutionPolicy","Bypass","-File","test.ps1","-SkipSmoke"]))
results=json.loads((base/"verification.json").read_text(encoding="utf-8")) if (base/"verification.json").exists() else []
if len(sys.argv)>1: commands=[(n,c) for n,c in commands if n in sys.argv[1:]]
for label,cmd in commands:
 start=time.monotonic()
 try:
  p=subprocess.run(cmd,cwd=ROOT,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=240)
  row={'label':label,'command':cmd,'cwd':str(ROOT),'inputs':'fixture embedded in named test','stdout':p.stdout,'stderr':p.stderr,'exit_code':p.returncode,'seconds':time.monotonic()-start}
 except subprocess.TimeoutExpired as e:row={'label':label,'command':cmd,'timeout':240,'stdout':str(e.stdout),'stderr':str(e.stderr),'exit_code':None}
 results.append(row); (base/'verification.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
 print(label,'exit',row['exit_code'],'PASS',row.get('stdout','').count('PASS:'),'seconds',round(time.monotonic()-start,1),flush=True)
 if label=='python-all': print(row['stderr'][-4000:],flush=True)
