# Changelog

## 1.1.0 — 2026-10-01

- Replace application-index mutation with a normal composite launcher plugin.
- Search applications, desktop actions, built-in apps and settings with equally
  weighted keyboard-layout variants; merge duplicates within each source.
- Order sources using DMS's group priorities and configured launcher order.
- Include visible third-party providers and QR with the literal query once;
  delegate execution to the original provider.
- Search clipboard/files asynchronously in both layouts when enabled, with
  separate request IDs and cancellation of obsolete results.
- Keep results in the plugin's own group, with no shell patches or service
  overrides. All mode retains DMS's native 10-result limit for each plugin.
- Remove development scripts, test fixtures and their Makefile/CI entry points
  from the published source tree.

## 1.0.0 — 2026-09-27

- Find applications using keys from another configured XKB layout.
- Detect the actual Wayland keymap, or select XKB layouts and variants manually.
- Include a US reference map and support base/Shift text, Unicode sequences,
  custom application names, and new desktop entries.
- Restore original application metadata when disabled; retain the last working
  index if a keymap refresh fails.
- Add a settings panel, diagnostics, automated tests and registry metadata.
