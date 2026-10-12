# Keep the Suunto route quality fields with an imported route

Issue: #3047. Follows #1445 / PR #3019, which imports the Suunto `DiveRoute`
as an underwater route but drops the export's route quality fields.

## Problem

A Suunto app export that carries a `DiveRoute` also carries two fields whose
meaning is undocumented:

- `DiveRouteQuality`: a single number. It was 1 on the three Nautic S dives
  shared on #1445 and 0 on a later dive (Dahab, 2026-10-09), so it varies.
- `QualityFeatures`: an array of 12 numbers. On the Dahab dive:
  `[16, 0.1, 0.654, 3.998, 1.149, 21.37, 10.32, 3505.7, 20.44, 0.780, 30.59, 0.181]`.
  The first value looks like an integer count; the rest are floats.

Both arrive once per export, on the first sample, next to `DiveRouteOrigin`.
They are not per route point. Today the import discards them.

## Goal

Store both fields as-is with the imported route, so they are available for
analysis once their meaning is known (for example, to flag a low-quality route
or weight it on the alignment page).

## Non-goals

- No UI for the fields, and nothing reads them yet. The one new string is
  the sync-conflict dialog's label for the new column, which the conflict
  catalogue requires for every synced column (see Sync).
- No interpretation: the values are kept exactly as parsed.
- No backfill. Routes imported before this change stay without the fields.
  Skip on a duplicate behaves as today (it links a route only when the dive
  has no Suunto route). Replace source still replaces the route row, and the
  new row carries the fields.
- `DiveRouteDistance` is not stored. It equals the 3D length of the route
  polyline, so it can be derived; it could later join the same column without
  a schema change.

## Design

### Schema (v285)

One nullable column, `nav_tracks.source_metadata TEXT`: a JSON object of
source-specific fields, keyed by the export's own names. Null means the
source carried none. For a Suunto route:

```json
{"DiveRouteQuality": 0, "QualityFeatures": [16, 0.1, 0.654, ...]}
```

The column is generic rather than Suunto-named: any route source can keep its
undocumented extras there without another schema rung.

- `NavTracks` gains `TextColumn get sourceMetadata => text().nullable()();`.
- `_assertNavTrackSourceMetadataColumn()` in
  `lib/core/database/migrations/helpers/track_migrations.dart` adds the column
  when missing (idempotent, guarded on the table existing).
- The v285 rung in `rungs_v231_onward.dart` calls it, and
  `_assertNavTracksSchema()` calls it too, so the existing beforeOpen
  backstop re-asserts it. `before_open.dart` is not touched.
- `currentSchemaVersion` goes to 285. No backfill. (Planned as 282, which
  PR #3133 holds; main shipped 283 and 284 first.)

### Parsing

`SuuntoDiveRouteParser.parse` reads the two fields from the samples it already
walks and returns them as `SuuntoDiveRoute.sourceMetadata`
(`Map<String, Object?>?`, unmodifiable):

- The first well-formed value of each key wins.
- `DiveRouteQuality` is kept only when it is a finite number.
- `QualityFeatures` is kept only when it is a list whose every element is a
  finite number. Its length is not enforced (12 so far).
- Non-finite numbers count as malformed: JSON has no form for them, so they
  could not be stored.
- A missing or malformed key is left out. When neither is present the map is
  null.
- When the parser returns no route, nothing is stored.

Both Suunto imports reach this parser with flat sample maps: the JSON file
import through `SuuntoJsonFileReader`, and the Suunto Cloud import through
`SuuntoSmlNormalizer`, which copies every key of each `Sample`. So both carry
the fields with no further change.

### Storage

- A new `lib/features/nav_track/domain/nav_track_source_metadata_codec.dart`
  encodes a map to a JSON string (null for a null or empty map) and decodes a
  stored string back. A string that is not a JSON object decodes to null and
  never throws. It is its own file because `nav_track_repository.dart` is
  already over the 800-line limit.
- `NavTrackRepository.insertImportedRoute` gains
  `Map<String, Object?>? sourceMetadata`, stored through the codec.
- The `NavTrack` entity gains `Map<String, Object?>? sourceMetadata`, decoded
  on read, with `copyWith` and `props` support.
- `SuuntoRouteWriter.attach` passes `route.sourceMetadata` through.

### Sync

The column rides the existing `navTracks` Drift JSON (`NavTrackRow.toJson` /
`fromJson`): no serializer arm and no change to the sync floor.

The sync-conflict dialog labels every synced column, and a coverage guard
fails on a column without one. `sourceMetadata` joins the conflict catalogue
(`site_trip_fields.dart`) as an opaque field, like `points`, so a conflict
shows the label "Extra data from the source" and "changed" rather than raw
JSON. The label (`settings_conflict_field_sourceMetadata`) is translated in
every locale.

A peer on an older build does not know the column. Its rows arrive without the
key, and two existing layers keep the local value: `upsertRecord` first fills
omitted keys from the local row (`overlayOntoLocal`, #2553), and the
`insertOnConflictUpdate(NavTrackRow.fromJson(...))` upsert then leaves null
columns out (`nullToAbsent`). Either alone is enough.
The older peer itself never holds the value, which is acceptable for opaque
fields with no UI.

### Error handling

Nothing about these fields can fail an import. Malformed input is dropped
field by field at parse time, and a malformed stored value reads as null. The
route writer already logs and swallows any write failure.

## Testing

Test inputs are inline samples. The reporter's trimmed fixture
(`test/fixtures/suunto/nautic_s_dive_route.json`) stays unchanged: adding
values from another dive would misrepresent it.

- Parser: the Dahab values are kept verbatim; absent fields give null;
  a non-numeric quality, a non-list features value and a list holding a
  non-number are each dropped while the other field is kept; no route means
  no metadata.
- Codec: a map round-trips; null and an empty map encode to null; a stored
  string that is not a JSON object decodes to null.
- Repository: `insertImportedRoute` with metadata reads it back through
  `getForDive`; without it, the field is null.
- Writer: against a real database, an attached Suunto route carries the
  parsed metadata.
- Migration v285: the column is added to an existing table, and existing rows
  read null.
- Sync apply: an incoming `navTracks` row without `sourceMetadata` keeps the
  local value; a row with it overwrites.
