# DMS Keyboard Layout Search

Search with the same physical keys in different keyboard layouts. With US and
Russian layouts, `set` and `ыуе` search the same local candidates, with equal
weight and deterministic ordering. `ашкуащч` finds Firefox without changing the
keyboard layout first.

Version 1.1 is an ordinary DMS **composite plugin**: a daemon reads the keyboard
map, and a launcher component implements `getItems()` / `executeItem()`. It does
not patch DMS, replace its launcher, change application metadata or install
systemd overrides. Search and ranking run in QML/JavaScript. A small Python
helper reads XKB at startup or when layouts are reloaded; it is not persistent.

## What appears in the launcher

One group, **DMS Keyboard Layout Search**, contains the combined results:

1. Applications, application actions (such as Steam Settings), and DMS core apps.
2. Settings and other visible sources according to DMS's group priorities and
   the user's configured launcher order.
3. Web-search and QR actions at their respective source positions.

Within a source, the strongest match across layout variants wins. Results are
identified by source and item identity, so two queries do not produce duplicate
rows or double a result's score. App history is counted once. Settings and
external providers retain their source ranking, merged deterministically.

No trigger prefix or layout label is required. Names and subtitles remain the
original ones. DMS itself labels launcher-provider rows as `Plugin` in All mode.

**DMS API boundaries:**

- This is a separate plugin group. Native Applications/Settings remain present;
  the plugin cannot insert into them or suppress their duplicates.
- DMS shows only the first **10** results of each provider in All mode. Select
  this plugin in the launcher to browse its full returned list (subject to
  DMS's plugin-view limit).
- External plugins receive the **literal query once**. Calling arbitrary
  stateful providers twice can overwrite their own pending search. Their
  returned actions are delegated back to the original provider.
- QR generation also receives the literal text, once.
- Match highlighting uses DMS's original query. The current plugin API cannot
  highlight letters matched through a converted layout query.
- Clipboard and files use independent async read requests for each variant;
  old replies are ignored. File search runs only when DMS has enabled files or
  folders in All mode and `dsearch` is available. Clipboard activation copies
  the original entry, not its shortened preview.
- Only sources allowed without a trigger are aggregated. Disabled/hidden
  sources are respected; the plugin excludes itself to avoid recursion.

The launcher contract is the normal plugin API. Reading apps/settings and
invoking DMS's service helpers still depends on the QML service interfaces of
the installed DMS version. No private service properties are assigned.

## Keyboard layouts

By default, the helper reads the actual Wayland keymap with
`xkbcli dump-keymap-wayland`. It includes the configured layouts plus a US
reference. This preserves layout variants and custom physical key positions.
It reads a keymap snapshot, not keyboard events.

Alternatively, enter XKB codes in the plugin settings:

```text
us,ru
us,de,fr
us,gr,ara,il
us(dvorak),us(colemak),tr
```

Up to eight layouts can be selected, plus the US reference. Manual mode uses
`evdev` rules and `pc105`. Reload layouts after changing the compositor keymap.
A failed reload retains the last valid mappings.

Conversion follows physical key positions, not translation. Base and Shift
levels are supported. AltGr, Compose/dead-key sequences and IME composition
are outside scope. Duplicate character positions and mixed-layout text can be
ambiguous; exact symmetry is verified for ordinary US/Russian letter queries.

## Requirements and installation

- DMS 1.6.2 or newer, with the launcher service interfaces used here.
- Python 3.9+, `libxkbcommon`, and an XKB data package such as
  `xkeyboard-config` / `xkb-data`.
- `xkbcli dump-keymap-wayland` for automatic detection; manual selection works
  without it.
- Optional: DMS clipboard backend and `dsearch`, for those enabled sources.

From the repository directory, create the link if it does not already exist:

```sh
mkdir -p ~/.config/DankMaterialShell/plugins
ln -s "$PWD/plugin" ~/.config/DankMaterialShell/plugins/keyboardLayoutSearch
dms ipc call plugin-scan scan
```

Enable **DMS Keyboard Layout Search** in DMS Settings → Plugins. On first load
it enables its own no-trigger setting. Its position among launcher plugins can
be adjusted in the launcher's plugin-order settings. Move it above Web Search
there if desired; ordering inside this plugin does not move its outer group.

When upgrading from 1.0, restart DMS once to refresh the composite manifest and
QML's cached JavaScript. Version 1.0's hidden application keywords are no longer
used; wrong-layout results now appear in the plugin's own group.

Disabling the plugin removes its provider and stops its helper jobs. There is
no application index to restore in 1.1.

## Diagnostics

Development scripts and test fixtures are not included in the published tree.
Release verification is recorded in the compatibility notes. After editing
imported JavaScript, QML may require a DMS restart to discard its old module cache.

Diagnostics:

```sh
dms ipc call keyboard-layout-search status
dms ipc call keyboard-layout-search variants 'ыуе'
dms ipc call keyboard-layout-search search 'ыуе'
dms ipc call keyboard-layout-search refresh
```

`search` reports this plugin's results, not the native Applications group. Its
first call may return partial results while settings load or async sources
complete; status reports `searching` while this plugin has pending requests.

See [compatibility and verification](docs/compatibility.md) for coverage and
[publication steps](docs/releasing.md) for release work. The prior core-patch
experiment is not part of the installable plugin or package.

[Source](https://github.com/korbash/dms-keyboard-layout-search) ·
[Releases](https://github.com/korbash/dms-keyboard-layout-search/releases)

MIT license, © 2026 korbash.
