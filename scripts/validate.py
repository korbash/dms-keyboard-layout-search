#!/usr/bin/env python3
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root/'plugin/plugin.json').read_text())
registry = json.loads((root/'packaging/registry/korbash-dms-keyboard-layout-search.json').read_text())
for key in ['id','name','author','description','requires_dms','dependencies','capabilities']:
    assert manifest[key] == registry[key], f'Manifest and registry disagree: {key}'
assert re.fullmatch(r'[a-z][a-zA-Z0-9]*', manifest['id'])
assert re.fullmatch(r'\d+\.\d+\.\d+',manifest['version'])
assert manifest['type'] == 'daemon'
assert manifest['license'] == 'MIT'
for key in ['component','settings']:
    file = (root/'plugin'/manifest[key]).resolve()
    assert file.is_relative_to((root/'plugin').resolve()) and file.is_file(), key
assert registry['path'] == 'plugin'
assert registry['category'] == 'utilities'
assert registry['repo'] == 'https://github.com/korbash/dms-keyboard-layout-search'
assert registry['screenshot'].endswith('/main/assets/keyboard-layout-search.png')
assert set(manifest['permissions']) <= {'settings_read','settings_write','process'}
assert (root/'LICENSE').is_file()
print('Manifest, registry metadata and local entry points: OK')
