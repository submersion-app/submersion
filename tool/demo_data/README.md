# Demo mode sample logbook

Demo mode (issue #3708) downloads a complete sample logbook from the
`demo-data` release of this repository. These tools build it. They run only on
a maintainer's machine, and nothing they read or write in between is ever
committed.

## 1. Harvest dive shapes from real logs

```bash
scripts/demo_data/harvest.sh <out_dir> <source_path>...
```

Sources are files, folders or zips in any format the app imports, plus
Submersion databases. Each one goes through the app's own parser and importer
into a scratch database, and only the shape of each dive is kept: depth,
temperature, heart rate, ppO2 and cell readings, setpoints, and each tank's
gas, size and pressure trace. Dates, places, names, notes, serial numbers and
source ids are never read into a shape. The same dive exported in two formats
becomes one shape.

Computer-generated logbooks are refused by name: `Synthetic dives 1000.uddf`,
`submersion_multitank_500dives.uddf` and anything under `scrubber-1500-dives`.

`<out_dir>` must be outside the repository. It receives:

- `shapes.jsonl.gz`: the shapes;
- `source_strings.txt`: a salted SHA-256 of every text value in the sources,
  for the privacy check (never the text itself);
- `salt.txt`: the salt.

Shearwater Cloud databases decode their profiles through a platform plugin
that `flutter test` does not have, so they yield no shapes here. Harvest them
inside the macOS app afterwards, into the same directory:

```bash
scripts/demo_data/harvest_in_app.sh <out_dir> <shearwater_db>...
```

It stages the files in the app's sandbox container, runs the same harvester
as an integration test (scratch in-memory databases and mocked preferences
only, never the app's own logbook), and merges the new shapes and hashes into
`<out_dir>`.

## 2. Build and check the logbook

```bash
scripts/demo_data/pack.sh <harvest_dir> <photos_dir> <out_dir> [seed]
```

`<photos_dir>` holds the photos and a `credits.json` listing each one:

```json
[{"fileName": "reef.jpg", "credit": "Author, CC0", "subject": "reef", "sourceUrl": "https://..."}]
```

Only openly licensed photos (CC0 or public domain) go in, never a photo from a
donated logbook. `tool/demo_data/photos/credits.json` records the photos in
the published package; fetch each from its `sourceUrl` to rebuild it. The
photos themselves are not kept in the repository. `subject` is a species name from `assets/data/species.json`
or a word like `reef` or `wreck`; it decides which dive the photo goes on.

The build plans a six-year story for a fictional diver (recreational, then
technical open circuit, then a rebreather), seeds every part of the app
through the app's own repositories, and refuses to write a file when either
check fails:

- **Coverage.** Every table holding user data has rows, except those listed
  with a reason in `src/checks/coverage_check.dart`. CI runs the same check on
  synthetic shapes (`test/tool/demo_data/coverage_test.dart`).
- **Privacy.** No demo dive may be closer than 0.04 to any harvested shape.
  The distance between two dives is the depth RMSE over 200 points of
  normalised time, divided by the larger maximum depth, plus half the
  relative difference in duration, plus half the relative difference in
  maximum depth. A copy is at 0; the reshaper's smallest change lands near
  0.06. No personal text (names, notes, serials, contact details) may equal a
  source value. The app's own vocabulary is allowed, because every real
  logbook carries it too: the site, centre and species catalogues, tank
  presets and roles, built-in list layouts, the rows a new empty logbook
  seeds, real product names, and the seeders' fixed labels
  (`src/checks/public_vocabulary.dart`). A refusal names the demo's value.

Limits: the database 5 MB compressed, the whole package 15 MB.

The output is `submersion-demo-s<schema>.zip`, `manifest-entry.json`, and
`demo-manifest.json` with this entry merged in (a package for the same schema
is replaced; older schemas stay so older apps keep a file they can open).

## 3. Publish (manual, with the maintainer's go-ahead)

```bash
gh release create demo-data --title "Demo mode sample logbook" \
  --notes "Sample logbook for demo mode. Not an app release." --latest=false
gh release upload demo-data <out_dir>/submersion-demo-s<schema>.zip \
  <out_dir>/demo-manifest.json --clobber
```

The release must never be marked latest: the in-app updater and the beta
appcast read `releases/latest`. Upload the current `demo-manifest.json` from
the release first if it already exists, so the merge keeps its older entries.
