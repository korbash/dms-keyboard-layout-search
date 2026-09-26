#!/usr/bin/env python3
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='layout-search-test-') as directory:
    runtime = Path(directory)
    shutil.copytree(root / 'tests/runtime', runtime, dirs_exist_ok=True)
    (runtime / 'plugin').mkdir()
    for name in ['LayoutSearchDaemon.qml', 'LayoutMaps.js', 'xkb_layouts.py']:
        (runtime / 'plugin' / name).symlink_to(root / 'plugin' / name)
    env = dict(os.environ, QT_QPA_PLATFORM='offscreen', QT_QUICK_BACKEND='software')
    env.pop('WAYLAND_DISPLAY', None)
    result = subprocess.run(['quickshell', '--no-color', '-p', str(runtime)], env=env, capture_output=True, text=True, timeout=20)
    output = result.stdout + result.stderr
    print(output, end='')
    sys.exit(0 if result.returncode == 0 and 'LAYOUT_SEARCH_COMPONENT_PASS' in output and 'LAYOUT_SEARCH_FAIL' not in output else 1)
