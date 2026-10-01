# Release and registry maintenance

The source repository is `korbash/dms-keyboard-layout-search` on GitHub, using
`main`. The plugin is already listed in the DMS registry (initial PR #952).
Release 1.1.0 uses a composite daemon/launcher manifest; results appear in its
own group without changing the DMS application index.

## Release checks

Before 1.1.0 publication, the development suite passed six Python tests,
24 JavaScript tests, offscreen QML lifecycle checks, live US/Russian searches,
and extraction of 597 installed XKB layouts/variants. Development scripts and
fixtures are preserved locally outside the published repository. Compatibility
claims and API limits are recorded in [compatibility.md](compatibility.md).

For later releases, verify the manifest and entry points, XKB extraction,
query symmetry, deduplication, group order and execution routing. Check the
plugin in a running DMS. Restart DMS after editing imported JavaScript, since
Qt can retain the old module across a plugin hot reload.

## Publication

1. Update the manifest version, date the changelog and review compatibility
   notes. Keep manifest and registry IDs, names, capabilities, descriptions,
   requirements and dependencies aligned.
2. Commit the release on `main`. Build a source archive from that exact commit,
   excluding local work directories, caches and development fixtures. Review
   the archive before uploading it.
3. Push `main`, create the version tag and publish a GitHub release with the
   archive attached. Include upgrade instructions and known API limits.
4. Verify public access to the manifest and screenshot URLs in the registry
   metadata, and check the release asset checksum.
5. If registry metadata changed, update only
   `plugins/korbash-dms-keyboard-layout-search.json` in a fork of
   `AvengeMedia/dms-plugin-registry`. Preserve unrelated accepted metadata;
   the current registry lists compositor and distribution support as `any`,
   while our live checks cover Niri on EndeavourOS.
6. Follow the registry's
   [contribution rules](https://github.com/AvengeMedia/dms-plugin-registry/blob/master/CONTRIBUTING.md),
   checked on 1 October 2026. Install `jinja2` and `requests` in a virtual
   environment, then run its validators:

   ```sh
   python3 .github/generate.py --validate
   CHANGED_PLUGINS=plugins/korbash-dms-keyboard-layout-search.json \
     python3 .github/validate_links.py
   ```

7. Submit a one-file PR targeting `master`, using
   [the prepared description](../packaging/registry-pr.md). Disclose substantial
   AI assistance. Do not include generated registry README or preview files.

The existing screenshot records the 1.0 Firefox lookup. In 1.1, lookup results
appear in a separate plugin group. The registry generates its own preview card.
Keep `i18n` unset unless central translation participation has been approved.
