import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('xkb_layouts', Path(__file__).resolve().parents[1] / 'plugin/xkb_layouts.py')
xkb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(xkb)


class XkbTests(unittest.TestCase):
    def test_specs(self):
        self.assertEqual(xkb.parse_specs(' us, ru, us(dvorak),ru '), [('us',''), ('ru',''), ('us','dvorak')])
        for value in ['us,', '../ru', 'us;echo hi', 'us($(id))', ',ru', 'us,,ru', ','.join('l'+str(i) for i in range(9))]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                xkb.parse_specs(value)

    def test_us_deduplicated_and_reference_always_present(self):
        self.assertEqual(len(xkb.snapshot('us')['layouts']), 1)
        layouts=xkb.snapshot('ru')['layouts']
        self.assertEqual(layouts[0]['keys']['AC04'][0], 'f')
        self.assertEqual(layouts[1]['keys']['AC04'][0], 'а')
        self.assertEqual(layouts[1]['keys']['AC04'][1], 'А')

    def test_dead_keys_not_emitted(self):
        layouts=xkb.snapshot('us(intl)')['layouts']
        self.assertEqual(layouts[1]['keys']['AC11'][0], '')

    def test_invalid_layout_fails_without_silent_fallback(self):
        with self.assertRaises(ValueError):
            xkb.snapshot('not_a_real_layout_54321')

    def test_missing_wayland_tool_and_timeout_are_actionable(self):
        for error in [FileNotFoundError(), subprocess.TimeoutExpired('xkbcli',5)]:
            with patch.object(xkb.subprocess,'run',side_effect=error), self.assertRaisesRegex(RuntimeError,'manually'):
                xkb.wayland_keymap()

    def test_custom_keymap_is_respected(self):
        text='''xkb_keymap {
          xkb_keycodes { include "evdev+aliases(qwerty)" };
          xkb_types { include "complete" };
          xkb_compat { include "complete" };
          xkb_symbols { include "pc+us" key <AC04> { [ Greek_phi, Greek_PHI ] }; };
        };'''
        data=xkb.snapshot(keymap_text=text)
        self.assertEqual(data['layouts'][1]['keys']['AC04'], ['φ','Φ'])


if __name__ == '__main__':
    unittest.main()
