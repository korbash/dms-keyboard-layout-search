# Compatibility and verification

Tested locally on 26 September 2026 with DMS 1.6.2, Quickshell 0.3.1,
libxkbcommon 1.13.2 and xkeyboard-config 2.48, on Niri and EndeavourOS
(Arch-based). The initial registry entry lists `niri` and the `arch` family;
other compositor/distribution combinations have not been verified.

## XKB database coverage

The extraction helper compiled and read **597 installed layouts/variants**.
The registry also contains `custom`, a placeholder requiring a user-provided
symbols file; it is unconfigured on the test machine. No other compilation
failed. This checks keymap extraction, not end-to-end search in every language.
A separate test verifies a custom keymap with a remapped physical key.

Run `make coverage` to reproduce the extraction check against your own XKB
version. The number of available entries depends on that package version.

## Behavioral tests

Independent expected strings check that application aliases are present for:

| Layout | App | Query from that layout |
| --- | --- | --- |
| Russian | Firefox | ашкуащч |
| Ukrainian | Firefox | ашкуащч |
| Greek | Firefox | φιρεφοχ |
| German | Yazi | zayi |
| French | Yazi | yqwi |
| Turkish | Firefox | fırefox |
| Arabic | Firefox | بهقثبخء |
| Hebrew | Firefox | כןרקכםס |
| Persian | Firefox | بهقثبخط |
| Thai | Firefox | ดรพำดนป |
| Indian default XKB layout | Firefox | िगीािदं |
| English Dvorak | Firefox | ucp.urq |
| English Colemak | Firefox | tupftyx |

Additional cases cover reverse conversion, uppercase app names, shifted
punctuation, Unicode normalization, multi-codepoint outputs, unknown characters,
missing metadata, multiword names, existing keywords, overrides and deduplication.

The isolated Quickshell component test runs the real plugin and Python helper
with several layouts. It verifies launch metadata preservation, reindexing,
new applications, renamed applications, a failed refresh, rapid setting changes,
and restoration on disable. It uses lightweight service stubs and does not
change the desktop's keyboard settings.

The live Niri test checks Russian queries and prefixes against the running DMS
application service and the installed launcher's scoring code. The screenshot
shows an actual matching result from the desktop launcher. The settings component
was also instantiated against the live DMS service and reported the detected
US/Russian layouts without QML errors.

A further live check temporarily supplied each of the 13 sample XKB maps to
the running plugin and queried the real DMS application service. Each expected
query found the original application ID (Firefox, or Zed for German/French).
The automatic US/Russian snapshot was restored afterward. This exercises the
search index without changing the desktop keyboard configuration; it does not
simulate typing through each language's input method.

## Scope

Direct characters on base/Shift XKB levels are supported. No claim is made for
IME composition, Compose/dead-key sequences, AltGr levels or every compositor.
See the README for the full boundaries and runtime requirements.
