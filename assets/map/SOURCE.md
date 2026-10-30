# AITU map source

The local floor plans in `svg/` were exported from the published `gh-pages`
build of [Yuujiso/aitumap](https://github.com/Yuujiso/aitumap), commit
`31127fd`. The `assets/map_site` directory contains that build for provenance
and regeneration; the app does not load it at runtime. `aitu_rooms.json` maps
numbered SVG areas to their room addresses. Both the plans and the search data
are bundled as Flutter assets, so the map needs no network or WebView.
Copyright (c) 2023 Yuujiso. The source is available under the MIT license;
the license text is included in `LICENSE-aitumap.md`.

Only numbered room shapes from the source are searchable. The source has plans
for building C1, blocks 1–3, floors 1–3, plus combined views. It has no room C1.2.345: the
neighboring rooms C1.2.344 and C1.2.346 are present. The application therefore
reports C1.2.345 as missing instead of highlighting an unrelated room.

Run `python3 tool/export_aitu_svg.py` and then
`python3 tool/build_aitu_map_data.py` to regenerate the assets.
