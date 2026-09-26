# Publishing 1.0.0

The project is prepared locally. No repository, push, release or registry PR
has been created. These are the remaining external steps, to perform only when
publication is requested.

1. Review the code and the actual compatibility claims. Run `make test
   test-component test-live coverage` on the release machine. Confirm the
   preview shows no personal information.
2. Create `korbash/dms-keyboard-layout-search` on GitHub, using `main`. Review the
   license, commit the prepared files, then push. These URLs are assumptions
   until the repository exists; update the README/registry if the name changes.
3. Change the README publication-status sentence and date the changelog. Run
   `make package`; review the archive. Tag `v1.0.0` and attach that archive to a
   release if desired.
4. Verify the repository, `plugin/plugin.json`, and
   `assets/keyboard-layout-search.png` are reachable at the URLs in the registry
   entry. Network link validation cannot pass before publication.
5. In a fork of `AvengeMedia/dms-plugin-registry`, copy
   `packaging/registry/korbash-dms-keyboard-layout-search.json` to `plugins/`.
   Run the registry's `python3 .github/generate.py --validate` and
   `python3 .github/validate_links.py`, following its current dependencies.
6. Use `packaging/registry-pr.md` as the submission description. Review the AI
   assistance disclosure and the documented test limits. Submit the PR.

Manifest and registry IDs, names, requirements and dependency lists must match.
For subsequent releases, bump the plugin version and changelog. Verify imported
JavaScript after restarting DMS, since Qt can cache it across plugin hot reloads.

The bundled CI only runs checks. The local packaging command only writes
`dist/`; neither performs a publication step.
