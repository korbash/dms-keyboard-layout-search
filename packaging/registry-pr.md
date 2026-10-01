DMS Keyboard Layout Search 1.1.0 replaces app-index mutation with a composite
daemon/launcher plugin. Update the existing registry entry's capabilities and
description to match the published manifest; retain the other accepted metadata.

The plugin searches applications and settings across keyboard layouts with
equal weighting and combines results in its own launcher group, ordered by
DMS source priority. It also includes enabled file/clipboard sources and passes
literal queries to other visible providers. It requires no trigger prefix or
DMS source patch. All mode retains DMS's 10-result cap per plugin.

Validation: six Python tests, 24 JavaScript tests, real offscreen QML lifecycle
checks, live US/Russian searches on Niri/EndeavourOS, and extraction of 597 XKB
layouts/variants. Other desktops have not been live tested. The repository's
compatibility notes document the QML service dependencies and API limits.
Development scripts and test fixtures are excluded from the published tree.

The implementation and this submission were prepared with substantial AI
assistance. The checks and installed DMS interfaces were reviewed and exercised.
