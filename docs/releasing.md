# Release and registry maintenance

The source repository is `korbash/dms-keyboard-layout-search` on GitHub, using
`main`. The first release is `v1.0.0`. The instructions below describe the
publication process and metadata to retain for future releases.

The submission follows the registry's
[contribution rules](https://github.com/AvengeMedia/dms-plugin-registry/blob/master/CONTRIBUTING.md)
and DMS's [manifest reference](https://danklinux.com/docs/dankmaterialshell/plugin-development#plugin-manifest-reference),
checked on 27 September 2026. The registry PR targets **`master`**. It adds only
`plugins/korbash-dms-keyboard-layout-search.json`; plugin source stays in our own
repository. Do not commit the registry's generated README or preview files.

## Metadata decisions

| Field | Prepared value | Reason |
| --- | --- | --- |
| `id` | `keyboardLayoutSearch` | Stable camelCase ID, identical in both manifests. |
| `name` | `DMS Keyboard Layout Search` | Identical display name in both manifests. |
| `category` | `utilities` | A utility that improves finding applications. |
| `type` / `capabilities` | `daemon` / `["daemon"]` | One background instance augments the app index. A launcher surface would require a separate trigger and a different API. `type` belongs to the plugin manifest. |
| `path` | `plugin` | Registry installation and validation resolve `plugin/plugin.json`. |
| `dependencies` | `python3`, `libxkbcommon`, `xkeyboard-config`, `xkbcli` | Python runs the helper, the library and data provide maps, and xkbcli reads the Wayland map in automatic mode. Package names vary by distribution; see the README. |
| `compositors` | `["niri"]` | The live desktop used for verification. |
| `distro` | `["arch"]` | Tested on EndeavourOS, part of the Arch family. Expand after verification on other distributions. |
| `requires_dms` | `>=1.6.2` | The tested minimum for the internal app-index integration. |
| `permissions` | `settings_read`, `settings_write`, `process` | Read/save the layout setting and run the local helper. |
| `screenshot` | Raw GitHub URL for `assets/keyboard-layout-search.png` | Actual query and Firefox result. The registry accepts this wide aspect ratio and generates its own preview card. |

Keep the existing screenshot: it shows the relevant launcher area without
desktop content. Do not add `i18n: true` to the initial registry submission;
that flag is for approved participation in DMS's central translation project.
The prepared PR text includes the required disclosure of substantial AI assistance.

## Publication sequence

1. Review the code and the actual compatibility claims. Run `make test
   test-component test-live coverage` on the release machine. Confirm the
   preview shows no personal information.
2. Update the README publication status and date the changelog. Review the
   license and commit these release changes locally. Run `make package` and
   review the archive.
3. Push the reviewed commits to `korbash/dms-keyboard-layout-search`, branch
   `main`. Tag the version and attach the reviewed archive to its GitHub release.
   Repository creation is only needed for the initial publication.
4. Verify the repository, `plugin/plugin.json`, and
   `assets/keyboard-layout-search.png` are reachable at the URLs in the registry
   entry. Run network link validation after the release commit is public.
5. In a fork of `AvengeMedia/dms-plugin-registry`, copy
   `packaging/registry/korbash-dms-keyboard-layout-search.json` to `plugins/`.
   Install its validation dependencies (`jinja2` and `requests` in a virtual
   environment). Run `python3 .github/generate.py --validate`, then check just
   our entry using the same filter as upstream CI:

   ```sh
   CHANGED_PLUGINS=plugins/korbash-dms-keyboard-layout-search.json \
     python3 .github/validate_links.py
   ```

6. Use `packaging/registry-pr.md` as the submission description. Review the AI
   assistance disclosure and the documented test limits. Submit the one-file
   PR to `AvengeMedia/dms-plugin-registry`, base branch `master`, with title
   `Add DMS Keyboard Layout Search`.

Manifest and registry IDs, names, requirements and dependency lists must match.
For subsequent releases, bump the plugin version and changelog. Verify imported
JavaScript after restarting DMS, since Qt can cache it across plugin hot reloads.

The bundled CI only runs checks. The local packaging command only writes
`dist/`; neither performs a publication step.
