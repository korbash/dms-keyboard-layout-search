#!/usr/bin/env python3
"""Hot reload only this plugin and wait for a usable index."""
import json
import os
from pathlib import Path
import subprocess
import time

root = Path(__file__).resolve().parents[1]
config = Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home()/'.config')))
link = config/'DankMaterialShell/plugins/keyboardLayoutSearch'
if not link.exists() or link.resolve() != root/'plugin':
    raise SystemExit('The installed plugin does not point at this project. See README installation instructions.')
def ipc(*args):
    result = subprocess.run(['dms','ipc','call',*args],capture_output=True,text=True,check=True)
    return result.stdout.strip()
print(ipc('plugins','reload','keyboardLayoutSearch'))
for _ in range(50):
    try:
        state=json.loads(ipc('keyboard-layout-search','status'))
        if state.get('error'):
            raise SystemExit(state['error'])
        if 'source' in state and not state['loading'] and state['layouts']:
            print(json.dumps(state,ensure_ascii=False))
            break
    except (json.JSONDecodeError,subprocess.CalledProcessError):
        pass
    time.sleep(.1)
else:
    raise SystemExit('Plugin did not become ready within five seconds')
