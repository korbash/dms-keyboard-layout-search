This plugin lets users find installed apps after typing with another keyboard
layout. It extends the existing DMS app index with physical-key aliases from
the actual Wayland XKB keymap, or from explicitly selected XKB layouts/variants.
No launcher trigger prefix is required.

Category: `utilities`; capability: `daemon`. The plugin runs in the background
and augments the built-in search; it has no separate launcher trigger or widget.
The installable files live in `plugin/`. Dependencies are Python 3, libxkbcommon,
xkeyboard-config and xkbcli (for automatic Wayland keymap detection).

Runtime checked with DMS 1.6.2 and Niri on EndeavourOS (Arch-based).
Automated checks cover 13 layout/variant examples, metadata preservation, reindexing, failed refreshes and disabling.
The extraction helper also read 597 installed XKB layouts/variants. Compose,
dead-key sequences, AltGr and IME conversion are not supported; ranking uses
the launcher's normal keyword scoring. Other compositors have not been live tested.

The code was developed with substantial AI assistance. Test scope and
limitations are documented in the repository.
