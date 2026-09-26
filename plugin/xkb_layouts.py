#!/usr/bin/env python3
"""Read character positions from XKB; no keyboard events are collected."""

import argparse
import ctypes as C
import ctypes.util
import json
from pathlib import Path
import re
import subprocess
import sys


class RuleNames(C.Structure):
    _fields_ = [(name, C.c_char_p) for name in ("rules", "model", "layout", "variant", "options")]


class Xkb:
    def __init__(self):
        library = ctypes.util.find_library("xkbcommon")
        if not library:
            raise RuntimeError("libxkbcommon is not installed")
        self.lib = C.CDLL(library)
        signatures = {
            "xkb_context_new": (C.c_void_p, [C.c_int]),
            "xkb_context_unref": (None, [C.c_void_p]),
            "xkb_keymap_new_from_names": (C.c_void_p, [C.c_void_p, C.POINTER(RuleNames), C.c_int]),
            "xkb_keymap_new_from_string": (C.c_void_p, [C.c_void_p, C.c_char_p, C.c_int, C.c_int]),
            "xkb_keymap_unref": (None, [C.c_void_p]),
            "xkb_keymap_min_keycode": (C.c_uint32, [C.c_void_p]),
            "xkb_keymap_max_keycode": (C.c_uint32, [C.c_void_p]),
            "xkb_keymap_num_layouts": (C.c_uint32, [C.c_void_p]),
            "xkb_keymap_layout_get_name": (C.c_char_p, [C.c_void_p, C.c_uint32]),
            "xkb_keymap_key_get_name": (C.c_char_p, [C.c_void_p, C.c_uint32]),
            "xkb_keymap_num_levels_for_key": (C.c_uint32, [C.c_void_p, C.c_uint32, C.c_uint32]),
            "xkb_keymap_key_get_syms_by_level": (C.c_int, [C.c_void_p, C.c_uint32, C.c_uint32, C.c_uint32, C.POINTER(C.POINTER(C.c_uint32))]),
            "xkb_keysym_to_utf32": (C.c_uint32, [C.c_uint32]),
        }
        for name, (result, arguments) in signatures.items():
            function = getattr(self.lib, name)
            function.restype, function.argtypes = result, arguments
        self.context = self.lib.xkb_context_new(0)
        if not self.context:
            raise RuntimeError("Could not create an XKB context")

    def close(self):
        if self.context:
            self.lib.xkb_context_unref(self.context)
            self.context = None

    def compile(self, layout, variant=""):
        names = RuleNames(b"evdev", b"pc105", layout.encode(), variant.encode(), b"")
        keymap = self.lib.xkb_keymap_new_from_names(self.context, C.byref(names), 0)
        if not keymap:
            raise ValueError(f"Unknown or unbuildable XKB layout: {layout}({variant})")
        return keymap

    def parse(self, text):
        keymap = self.lib.xkb_keymap_new_from_string(self.context, text.encode(), 1, 0)
        if not keymap:
            raise ValueError("Could not parse the compositor's XKB keymap")
        return keymap

    def layouts(self, keymap, prefix):
        result = []
        try:
            for group in range(self.lib.xkb_keymap_num_layouts(keymap)):
                name = self.lib.xkb_keymap_layout_get_name(keymap, group)
                keys = {}
                low = self.lib.xkb_keymap_min_keycode(keymap)
                high = self.lib.xkb_keymap_max_keycode(keymap)
                for code in range(low, high + 1):
                    raw_name = self.lib.xkb_keymap_key_get_name(keymap, code)
                    if not raw_name:
                        continue
                    key_name = raw_name.decode()
                    if not re.fullmatch(r"(?:A[EDCB]\d\d|TLDE|BKSL|LSGT|SPCE)", key_name):
                        continue
                    levels = []
                    for level in range(min(2, self.lib.xkb_keymap_num_levels_for_key(keymap, code, group))):
                        symbols = C.POINTER(C.c_uint32)()
                        count = self.lib.xkb_keymap_key_get_syms_by_level(keymap, code, group, level, C.byref(symbols))
                        points = [self.lib.xkb_keysym_to_utf32(symbols[i]) for i in range(count)]
                        # Dead keys and non-text symbols do not describe committed text.
                        levels.append("" if not points or any(p < 32 or p == 127 for p in points) else "".join(map(chr, points)))
                    keys[key_name] = levels
                result.append({"id": f"{prefix}:{group}", "name": name.decode() if name else prefix, "keys": keys})
        finally:
            self.lib.xkb_keymap_unref(keymap)
        return result


def parse_specs(text):
    if not text.strip():
        return []
    specs = []
    for token in text.split(","):
        match = re.fullmatch(r"\s*([a-zA-Z0-9_-]+)(?:\(([a-zA-Z0-9_-]+)\))?\s*", token)
        if not match:
            raise ValueError("Use comma-separated XKB codes, for example: us,ru,de,us(dvorak)")
        spec = (match[1], match[2] or "")
        if spec not in specs:
            specs.append(spec)
    if len(specs) > 8:
        raise ValueError("Select up to eight layouts at a time")
    return specs


def wayland_keymap():
    try:
        process = subprocess.run(["xkbcli", "dump-keymap-wayland"], capture_output=True, text=True, timeout=5)
    except FileNotFoundError as error:
        raise RuntimeError("Install xkbcli (libxkbcommon tools), or enter layouts manually in the plugin settings") from error
    except subprocess.TimeoutExpired as error:
        raise RuntimeError("Reading the Wayland keymap timed out; enter layouts manually in the plugin settings") from error
    if process.returncode or not process.stdout.startswith("xkb_keymap"):
        raise RuntimeError("Cannot read the Wayland keymap; check xkbcli dump-keymap-wayland, or enter layouts manually")
    return process.stdout


def snapshot(layout_specs="", keymap_text=None):
    xkb = Xkb()
    try:
        specs = parse_specs(layout_specs)
        source = "manual" if specs else "wayland"
        layouts = xkb.layouts(xkb.compile("us"), "us")
        if specs:
            for layout, variant in specs:
                layouts.extend(xkb.layouts(xkb.compile(layout, variant), f"{layout}({variant})"))
        else:
            layouts.extend(xkb.layouts(xkb.parse(keymap_text if keymap_text is not None else wayland_keymap()), "session"))
        unique, seen = [], set()
        for layout in layouts:
            signature = json.dumps(layout["keys"], sort_keys=True)
            if signature not in seen:
                seen.add(signature)
                unique.append(layout)
        if len(unique) > 9:
            raise ValueError("The keymap has more than eight layouts plus the US reference layout")
        return {"version": 1, "source": source, "layouts": unique}
    finally:
        xkb.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--layouts", default="", help="XKB codes and variants, e.g. us,ru,fr,us(dvorak); empty reads Wayland")
    parser.add_argument("--keymap", type=Path, help="Read a saved XKB keymap instead of connecting to Wayland (diagnostics)")
    args = parser.parse_args()
    try:
        result = snapshot(args.layouts, args.keymap.read_text() if args.keymap else None)
    except (OSError, ValueError, RuntimeError) as error:
        print(json.dumps({"error": str(error)}, ensure_ascii=False))
        return 1
    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
