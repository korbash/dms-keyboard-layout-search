# Compatibility and verification

The 1.1 launcher implementation was tested on 1 October 2026 against the
running DMS UI revision `a954553ffdceaf27`, with Niri on EndeavourOS. The shell
runs from its original embedded UI; no DMS source patch or service override
is required. Other compositor/distribution combinations have not been tested.

## Coverage

The following checks passed before the 1.1.0 release. Development scripts and
test fixtures are kept outside the published source tree.

- Python tests validate XKB extraction, invalid layouts, automatic detection
  and custom physical key positions.
- JavaScript tests check independently specified strings for 13 XKB layouts,
  US/Russian query symmetry, Unicode normalization and multi-codepoint keys.
- Search tests execute the real launcher methods against service fixtures:
  equal local results, best-score merging, native source priority rules,
  user ordering, provider visibility, literal web/QR queries, action routing,
  recursion guards, async file/clipboard deduplication and obsolete replies.
- Offscreen Quickshell loads the real daemon, launcher and XKB helper. It
  verifies that application metadata remains untouched, override names are
  read dynamically, layout changes replace mappings, and failed refreshes
  retain working maps. It also exercises rapid consecutive settings changes
  and destruction of both surfaces.
- Live checks query Firefox, Telegram, Zed and Files using US/Russian names
  and prefixes. `set` and `ыуе` are compared by ID, score and order for the
  applications and settings returned by the plugin.

The release XKB extraction coverage run (1 October 2026) compiled and read
597 installed layouts/variants with libxkbcommon 1.13.2 and xkeyboard-config
2.48. Only the unconfigured `custom` placeholder was excluded. This checks
keymap extraction, not end-to-end search in every writing system.

## API boundaries

The plugin uses DMS's ordinary launcher/composite contracts. App discovery,
settings lookup and execution use existing QML service methods; their names
and behavior can change across DMS versions. It never assigns private caches,
application metadata, global launcher queries or shell functions.

DMS owns the outer plugin section, native row badges and the 10-result cap
in All mode. Category metadata cannot move plugin rows into native sections.
The aggregation order inside the plugin follows the section-priority rules
of the tested DMS revision and `SettingsData.launcherPluginOrder`.

Arbitrary third-party sources are queried once with literal text. Their own
layout support is not extended. Clipboard and file reads are independent
requests owned by this plugin; no shared query cache is rewritten. Only
currently enabled and visible sources are queried.

Custom app names and hidden-app preferences are respected through DMS's
visible-application accessor. Native app actions and original launch payloads
are preserved. Clipboard activation copies the complete stored entry; the
UI preview is only a display label.

Base/Shift characters are supported. IME, Compose, dead-key and AltGr input
remain outside scope. Maps with ambiguous duplicate character positions can
produce approximate alternatives.
