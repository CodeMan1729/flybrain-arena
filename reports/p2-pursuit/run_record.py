import json, subprocess, sys
from pathlib import Path
sys.stdout.reconfigure(encoding='utf-8')
root=Path.cwd()
name=sys.argv[1]
command=sys.argv[2:]
r=subprocess.run(command,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=300)
record={'cwd':str(root),'command':command,'inputs':'repository scene + test-defined inputs','stdout':r.stdout,'stderr':r.stderr,'exit_code':r.returncode}
(root/'reports/p2-pursuit'/f'{name}.json').write_text(json.dumps(record,indent=2),encoding='utf-8')
print(r.stdout); print(r.stderr); print('EXIT:',r.returncode)
sys.exit(r.returncode)
