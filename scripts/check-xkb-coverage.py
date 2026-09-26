#!/usr/bin/env python3
"""Compile every installed XKB layout/variant and report extraction coverage."""
import argparse
import importlib.util
import json
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('xkb_layouts', root / 'plugin/xkb_layouts.py')
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--registry', type=Path, default=Path('/usr/share/X11/xkb/rules/evdev.xml'))
args = parser.parse_args()
registry = ET.parse(args.registry)
xkb = helper.Xkb()
report = {'tested': 0, 'compiled': 0, 'failed': [], 'withoutDirectCharacters': [], 'unconfigured': []}
try:
    for node in registry.findall('.//layoutList/layout'):
        layout = node.findtext('configItem/name')
        variants = [''] + [v.findtext('configItem/name') for v in node.findall('variantList/variant')]
        for variant in variants:
            label = f'{layout}({variant})' if variant else layout
            report['tested'] += 1
            try:
                maps = xkb.layouts(xkb.compile(layout, variant), label)
                report['compiled'] += 1
                if not any(text and text.strip() for m in maps for levels in m['keys'].values() for text in levels):
                    report['withoutDirectCharacters'].append(label)
            except (ValueError, RuntimeError) as error:
                if layout == 'custom':
                    report['unconfigured'].append(label)
                else:
                    report['failed'].append({'layout': label, 'error': str(error)})
finally:
    xkb.close()
print(json.dumps(report, indent=2))
raise SystemExit(bool(report['failed']))
