# Visibility Scale Calibration - Design

Date: 2026-08-07
Status: Approved
Schema version: v144

## Problem

`Visibility` (`lib/core/constants/enums.dart:31`) is a four-value enum whose
labels weld a judgment to a measurement:

| Value | Label |
| ------- | ------- |
| `excellent` | `Excellent (>30m / >100ft)` |
| `good` | `Good (15-30m / 50-100ft)` |
| `moderate` | `Moderate (5-15m / 15-50ft)` |
| `poor` | `Poor (<5m / <15ft)` |

Only the judgment is persisted. `dives.visibility` is a `TEXT` column holding
the enum `.name`, so a dive with 6 m of visibility is stored forever as the
string `moderate`.

The thresholds are calibrated for tropical diving. A 30 m "excellent" is a Red
Sea or Cozumel number. In Puget Sound, Monterey, the Great Lakes or UK coastal
water, 6 m is an exceptional day, and the app files it at the bottom of
`moderate` - the second-worst of four buckets. Cold-water and inland divers
cannot record a good day as a good day.

Discarding the measurement also corrupts data the app already receives:

- `uddf_import_service.dart:731` and `uddf_full_import_service.dart:1992` take a
  real measured distance from a UDDF file and collapse it into a bucket.
- `subsurface_xml_parser.dart:246` parses an integer and does the same.
- `uddf_export_service.dart:555` then invents a distance back out of the bucket
  (excellent -> 30, good -> 20, moderate -> 10, poor -> 5).

A number entered in another logbook does not survive a round trip through
Submersion.

The app is also internally inconsistent: dive **sites** already store
`typicalVisibility` as free text (`dive_site.dart:227`), so there are two
incompatible visibility models in the same codebase.

## Decisions

| Question | Decision |
| ---------- | ---------- |
| Fix shape | Store the measurement; derive the adjective from a per-diver calibration |
| Legacy data | Keep both columns, never fabricate a number for an existing dive |
| Calibration source | Preset picker plus custom override, per diver |
| Entry UX | Units-aware numeric field with the adjective shown live |

The decisive argument for storing the measurement is that recalibration must be
lossless. If the stored fact is `6.0`, changing presets only changes an
adjective. If the stored fact is `moderate`, changing presets silently
reinterprets every dive already logged.

## Data model

### `dives` (schema v144)

```dart
// NEW - canonical measurement, always metric, nullable.
RealColumn get visibilityMeters => real().nullable()();

// RETAINED - legacy bucket. Read-only from v144 onward. Never written by new
// code paths; cleared when a dive gains a numeric value.
TextColumn get visibility => text().nullable()();
```

The migration adds the column and performs **no backfill**. Existing rows keep
their bucket word and `visibilityMeters` stays `null`.

### Migration mechanics

This codebase does not use plain `m.addColumn()` in the version ladder. Every
column addition is an idempotent `_assert<Thing>Column()` helper that inspects
`PRAGMA table_info` first, and is called from **two** places: the version gate in
`onUpgrade`, and the `beforeOpen` backstop. See `_assertDefaultCurrencyColumn`
(`database.dart:4093`) and `_assertTripReturnFlightColumn` (`database.dart:4111`).

The reason is documented at `database.dart:7353-7355`: versions are reserved by
parallel branches (v138 by #603, v140 by the media section, v143 by the media
integration branch). A database that upgraded on one branch can arrive at
another already past the version gate and would never run a ladder-only
`addColumn`. The `beforeOpen` backstop is its only path to the column.

Each helper must return early when `PRAGMA table_info` is empty, so minimal
migration-test fixtures that lack the table do not fail.

### Version selection

`currentSchemaVersion` is `142` on `origin/main` (`database.dart:2935`). v143 is
claimed by the unmerged media integration branch (PR #894), so this work takes
**v144**. Re-check the ladder against `origin/main` before pushing - version
claims move.

### Precedence and clearing

Numeric wins. Reads resolve in this order:

1. `visibilityMeters != null` -> format the distance, derive the adjective.
2. `visibility != null` -> render the legacy band (see Display).
3. Both null -> field is absent.

When a save supplies `visibilityMeters`, the write must also clear the legacy
bucket so a stale second answer cannot survive. The clear must be an explicit
`Value(null)`. `Value.absent()` preserves the existing value on a `toCompanion`
write and would leave both columns populated.

### `diver_settings` (schema v144)

```dart
TextColumn get visibilityScalePreset =>
    text().withDefault(const Constant('tropical'))();
// Used only when the preset is 'custom'.
RealColumn get visibilityScaleExcellentM => real().nullable()();
RealColumn get visibilityScaleGoodM => real().nullable()();
RealColumn get visibilityScaleModerateM => real().nullable()();
```

## Calibration

A pure value object with no I/O, so it is trivially testable and safe to call
from build methods.

```dart
enum VisibilityScalePreset { tropical, temperate, coldWater, custom }

class VisibilityScale {
  final double excellentAtOrAboveM;
  final double goodAtOrAboveM;
  final double moderateAtOrAboveM;
}
```

Three boundaries produce four bands. Boundaries are inclusive at the lower edge:
a value `>= excellentAtOrAboveM` is excellent.

| Preset | Excellent | Good | Moderate | Poor |
| -------- | ----------- | ------ | ---------- | ------ |
| Tropical | >= 30 m | 15-30 m | 5-15 m | < 5 m |
| Temperate | >= 20 m | 10-20 m | 4-10 m | < 4 m |
| Cold-water / Inland | >= 12 m | 6-12 m | 2-6 m | < 2 m |
| Custom | user-entered | | | |

Thresholds are canonical metric. The settings UI converts for display, so an
imperial diver sees approximately 40 ft / 20 ft / 6.5 ft on the cold-water
preset. Custom values are entered in the diver's own units and converted to
metric for storage.

Custom validation: the three values must be strictly descending and greater than
zero. A violated constraint blocks the save with an inline error rather than
silently reordering.

On the cold-water preset a 6 m day reads **Good** and a 12 m day reads
**Excellent**, which is the reported problem resolved.

### Default preset

The default is `tropical`, which reproduces today's exact thresholds. Upgrading
to v144 therefore re-labels nobody's logbook. The fix is that the scale becomes
changeable, not that it silently changes. Discoverability is handled by placing
the setting next to the existing unit preferences.

## Display

A single pure function is the only place the mapping lives:

```dart
VisibilityBand? bandFor(double meters, VisibilityScale scale);
```

Consumers: dive detail, compact and dense dive list tiles, the dive table
column, `DiveFieldExtractor` (`dive_field_extractor.dart:50`), and the CSV and
Excel exporters.

Two further consumers surfaced during implementation and are covered:
`dive_merge_builder.dart` (multi-computer consolidation would otherwise drop
the measurement when merging two records of the same dive) and the three PDF
logbook templates (which would otherwise print nothing for measured dives).

The bulk-edit form is converted too. It is a second entry surface
(`BulkScalarInputs`, applied via `buildScalarCompanion`), and leaving it on the
enum would have kept the tropical-only bucket list in a live surface and let
bulk edits write the legacy column onto new dives. It now carries
`visibilityMeters` and clears the legacy bucket when applied.

Rendered form for a numeric dive, in the diver's units:

```
Visibility   20 ft . Excellent
```

### Legacy rows

Legacy rows render as the distance band they actually mean, never as a
calibrated adjective:

```
Visibility   15-50 ft
```

We know only that the dive fell somewhere in that band; asserting an adjective
would be a guess.

The `Visibility` enum is **retained** - it still decodes the legacy column, and
the UDDF and Subsurface importers still need it for files carrying a bucket
rather than a number.

`Visibility.displayName` is also **retained, unchanged**.
`environment_enum_display.dart:6-10` documents a deliberate decision: enum
`displayName` stays English because it feeds data interchange (CSV/Excel export,
the field extractor) where a stable, locale-independent value is wanted. The
sibling enums follow this and it is not this change's business to overturn it.

What is **added** is metric band bounds on each enum value plus a localized,
unit-aware band renderer, following the existing
`localizedName(AppLocalizations l10n)` extension pattern in
`environment_enum_display.dart`. Statistics legacy segment labels use the same
renderer, so they are unit-aware too.

This incidentally fixes a live bug. The keys `enum_visibility_excellent`
through `enum_visibility_poor` exist in all twelve locale ARB files but are
referenced by zero lines of Dart - the hardcoded English `displayName` is what
actually renders. Visibility was missed when its sibling enums were localized
for issue #622, so non-English users currently see English visibility labels.
Wiring the renderer through `localizedName` resolves it.

## Statistics

`getVisibilityDistribution` (`statistics_repository.dart:971`) currently does
`GROUP BY visibility` on the text column. SQL cannot see the diver's
calibration, so binning moves into Dart: the query selects both `visibility` and
`visibility_meters` (retaining the existing `DiveFilterSql` predicate), and the
repository bins the rows.

- Numeric dives bin by calibrated adjective.
- Legacy-only dives form their own segments, labelled with their band
  (for example `5-15 m (legacy)`).

This is the one place the dual model stays visible to users. It is honest -
legacy dives genuinely are a coarser measurement - and the legacy segments
shrink naturally as dives are edited.

## Import and export

| Path | Change |
| ------ | -------- |
| UDDF import | Store the parsed distance in `visibilityMeters` instead of bucketing it |
| UDDF full import | Same |
| Subsurface XML import | **No change** - see below |
| CSV import | **No change** - see below |
| UDDF export | Emit the true value for numeric dives; fall back to today's representative mapping only for legacy dives |
| CSV / Excel export | Replace the single `Visibility` column with `Visibility` (numeric, diver's units) and `Visibility Rating` (adjective) |

The existing single `Visibility` column currently emits `displayName`, so its
content changes either way. Splitting it keeps the numeric column
machine-readable for spreadsheet use while preserving the human-readable rating.
Legacy dives emit an empty numeric cell and their band text in the rating
column.

The UDDF changes are a strict improvement: they remove an existing lossy
round trip rather than adding behaviour.

### Why Subsurface and CSV import are unchanged

UDDF's `<visibility>` is a distance in meters per the spec, so carrying the
number through is simply not losing data. Subsurface is different:
`subsurface_xml_parser.dart:973` maps its `visibility` attribute as a
subjective **1-5 star rating** (`1 || 2 -> poor`, `3 -> moderate`, ...), not a
distance. Converting a 3-star rating into "10 m" would invent a measurement
nobody took, which is exactly the failure this design exists to avoid, so
Subsurface keeps writing the legacy bucket.

CSV import is left alone for the same reason: a column headed "visibility"
could be either a distance or a rating, and there is no way to tell from the
header. Guessing would fabricate.

## Settings UI

A new section beside the existing unit preferences: a preset selector, and, when
`custom` is selected, three numeric fields in the diver's units. A live preview
row shows how a sample distance is labelled under the current selection.

## Sync

`sync_data_serializer.dart` wraps Drift's generated `toJson` / `fromJson` rather
than a hand-maintained column list, so the new columns propagate automatically
once codegen runs. Required work is the schema version bump to v144 and
confirming that a peer on an older schema hydrates the new columns to their
defaults rather than erroring.

`visibilityScalePreset` is a `diver_settings` column and therefore syncs with the
diver's other preferences, so the calibration follows the diver across devices.

## Testing

Written test-first, per CLAUDE.md.

- `VisibilityScale` band boundaries, explicitly covering the inclusive lower
  edge of each band and the exact preset threshold values.
- Custom scale validation: rejects non-descending and non-positive values.
- Migration v143 -> v144: existing rows keep their legacy text untouched and
  `visibilityMeters` is null; no rows are backfilled.
- Precedence: a dive with both columns populated renders the numeric value; a
  save carrying a number clears the legacy bucket via `Value(null)`.
- Widget test: entering a number updates the adjective live, and switching units
  reformats without changing the stored metric value.
- Statistics binning across a mixed legacy and numeric dataset.
- UDDF round trip: a measured distance survives export and re-import. This is
  the regression test for the data loss that exists today.

## Out of scope

- Dive site `typicalVisibility` stays free text. Unifying it with the numeric
  model is a real follow-up, but a separate change.
- No per-region or per-site automatic calibration.
- No range entry (`visibilityMeters` is a single value, not a min/max pair).

## Accepted trade-offs

1. **Default preset is tropical.** No existing logbook re-labels on upgrade, but
   cold-water divers must set the preference once; they are not fixed by
   default.
2. **Legacy dives render as a band, never an adjective.** Honest, but old and
   new dives look different in the same list until the old ones are edited.
3. **Single value, not a range.** A diver who thinks in ranges ("15 to 20 feet")
   must pick one number.
