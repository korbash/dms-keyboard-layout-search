#!/usr/bin/env python3
"""Build a local source archive; never contact a remote or create a release."""
import json
from pathlib import Path
import tarfile

root = Path(__file__).resolve().parents[1]
version = json.loads((root/'plugin/plugin.json').read_text())['version']
name = f'dms-keyboard-layout-search-{version}'
output = root/'dist'/f'{name}.tar.gz'
preview = root/'assets/keyboard-layout-search.png'
if not preview.is_file() or preview.read_bytes()[:8] != b'\x89PNG\r\n\x1a\n':
    raise SystemExit('A verified PNG preview is required before packaging')
output.parent.mkdir(exist_ok=True)
allowed = ['plugin','scripts','tests','assets','docs','packaging','.github','Makefile','README.md','LICENSE','CHANGELOG.md','.gitignore']
with tarfile.open(output,'w:gz') as archive:
    for entry in allowed:
        candidate=root/entry
        files=sorted(candidate.rglob('*')) if candidate.is_dir() else [candidate]
        for file in files:
            if not file.is_file() or '__pycache__' in file.parts or file.suffix in {'.pyc','.qmlc','.jsc'}:
                continue
            if file.is_symlink():
                raise SystemExit(f'Refusing to package a symlink: {file}')
            archive.add(file,arcname=f'{name}/{file.relative_to(root)}',recursive=False)
print(output)
