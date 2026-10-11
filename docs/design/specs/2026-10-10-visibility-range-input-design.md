# Visibility range input: design

Date: 2026-10-10
Release: v1.8.2

## Problem

The dive edit form asks for visibility as a single number. Divers rarely
measure visibility; they judge it ("good vis today"). Forcing a number makes
them invent precision or leave the field blank. The form should offer both a
quick range (pick a band) and the existing precise number.

## Background

Since schema v144 (PR #906) a dive stores the measured distance in
`dives.visibility_meters`, and the adjective (Poor / Moderate / Good /
Excellent) is derived from the diver's visibility scale (Tropical, Temperate,
Cold water, Custom). The legacy `dives.visibility` bucket column is read-only
and survives only on dives logged before v144. The rule that governs this
design is the one v144 set: store the measurement, derive the adjective.

## Decisions

1. **Range means picking a band.** In Range mode the diver taps Poor,
   Moderate, Good or Excellent. The pick is saved as the metre range that band
   covers on the diver's scale at the moment of saving (Good on Cold water is
   6 to 12 m).
2. **The metres are the fact.** A saved range never changes when the diver
   later changes scale. The adjective is re-derived from the current scale and
   shown only when the whole range sits inside one band.
3. **Storage is two new columns,** not a reuse of `visibility_meters`, so no
   existing reader mistakes a range for a precise measurement.
4. **A new dive opens in the last-used mode,** remembered per device.

## Data model

Schema v278 adds two nullable REAL columns to `dives`:

| Column | Meaning |
| --- | --- |
| `visibility_min_meters` | Inclusive low end of a range, or null when open below |
| `visibility_max_meters` | Exclusive high end of a range, or null when open above |

A dive carries at most one visibility shape:

| Shape | Columns set |
| --- | --- |
| Precise | `visibility_meters` |
| Range | `visibility_min_meters` and/or `visibility_max_meters` (at least one) |
| Legacy | `visibility` (pre-v144 bucket) |
| None | nothing |

The repository enforces this on write: writing a precise value clears the
range columns and the legacy bucket; writing a range clears
`visibility_meters` and the legacy bucket. Writing neither leaves the legacy
bucket alone, as today.

The low end is inclusive and the high end exclusive, matching
`VisibilityScale.bandFor`, so a band's range and a precise reading agree at
the edges (12 m is Excellent on Cold water either way).

No backfill. Existing dives keep their shape.

## Domain

`VisibilityScale` gains two pure functions:

- `VisibilityRange rangeFor(VisibilityBand band)` returns the band's metres on
  this scale. Poor is `[null, moderate)`, Moderate is `[moderate, good)`, Good
  is `[good, excellent)`, Excellent is `[excellent, null)`.
- `VisibilityBand? bandForRange(VisibilityRange range)` returns the band that
  wholly contains the range, or null when the range spans bands.
- `VisibilityBand? bandMatching(VisibilityRange range)` returns the band whose
  range is exactly this one, which decides the selected chip.

`VisibilityRange` is a small immutable value object (`minM`, `maxM`, equality,
`copyWith`) in `lib/core/domain/visibility/`.

The `Dive` entity gains `visibilityMinMeters` and `visibilityMaxMeters`, with
`copyWith` support.

## Edit form

The visibility input moves out of `dive_edit_page.dart` (6,335 lines) into
its own widget under `lib/features/dive_log/presentation/widgets/`.

- A `Range | Precise` segmented control sits above the input.
- **Range:** four choice chips with the band names. A caption shows the range
  that will be saved, in the diver's depth unit ("6-12 m", "under 2 m",
  "12 m+"). Tapping the selected chip clears the pick.
- **Precise:** today's number field and band caption, unchanged, including the
  validator that blocks a save on unreadable text.
- Each mode keeps its own value while the form is open; only the active
  mode's value is saved.

Opening an existing dive:

| Stored shape | Opens in | Chip selected | Caption |
| --- | --- | --- | --- |
| Precise | Precise | n/a | band of the value |
| Range equal to a current band's range | Range | that band | the range |
| Range not equal to any current band | Range | none | the stored range |
| Legacy bucket | Range | none | the legacy range (as today) |
| None | last-used mode | none | none |

A stored range that matches no chip, and a legacy bucket, are carried through
a save untouched until the diver picks a chip or switches to Precise and
types a value. Re-saving a dive to fix its notes never rewrites its
visibility.

**Mode memory:** a per-device SharedPreferences key records the mode of the
last save that carried a visibility value. It is a convenience, not diver
data, so it is not synced.

**Bulk edit** offers the same control. Applying it writes the chosen shape to
every selected dive under the same at-most-one-shape rule.

## Display

The detail card renders a range through one formatter, the same way it
renders a precise value today (distance plus adjective):

- `6-12 m · Good` when `bandForRange` finds a band on the current scale
- `6-12 m` when the range spans bands
- `under 2 m` / `12 m+` for open ends, with the adjective under the same rule

Surfaces that show a precise value without an adjective today (the PDF
templates, the dive table column) show the range without one too.

The formatter reuses the existing `visibility_range_between`,
`visibility_range_under` and `visibility_range_atLeast` strings (the low end
is inclusive, so "12 m+" is exact where "over 12 m" would not be). New
strings are only the form's mode labels and the Insights "Spans bands" label.

Precedence in `formatDiveVisibility`: precise, then range, then legacy.

## Insights

The visibility distribution and the Focus factor bin a range dive:

- into its band when `bandForRange` finds one, the same as a precise dive;
- otherwise into a new `range_spanning` key, rendered "Spans bands".

## Filters and query language

`minVisibility` / `maxVisibility` and the `visibility` query field match a
range dive only when the whole range satisfies the bound:

- `>= X` matches when `visibility_min_meters >= X`
- `<= X` matches when `visibility_max_meters` is set and `<= X`
- an open end never satisfies a bound on that side

The query field's empty check also requires both range columns to be null.

## Export and import

- **CSV and Excel:** new columns Visibility Min and Visibility Max, in depth
  units. The Submersion CSV parser reads them back.
- **UDDF:** the standard `<visibility>` element holds a single number, so a
  range dive writes none there rather than an invented value. A per-dive
  entry in Submersion's `<applicationdata>` carries the range, and the
  Submersion UDDF importers read it back, so a Submersion backup round-trips.

## Merge, mirror, sync, conflicts

- `dive_merge_builder` takes the whole visibility shape from one source, by
  reader precedence: the first dive with a precise value, else the first with
  a range, else the first with a legacy bucket. Picking each column
  independently could produce a dive with both a precise value and a range.
- `dive_mirror_fields`, the sync conflict catalogue (`dive_log_fields.dart`)
  and planned-dive fill fields list the two new columns.
- Sync: dive rows serialize generically and both columns are nullable, so a
  payload from a pre-v278 peer hydrates them as null. A test confirms it.

## Migration

v278 adds both columns with the repo's idempotent column-assert pattern,
called from the ladder rung in `migrations/ladder/rungs_v231_onward.dart` and
from the beforeOpen backstop, so a database stranded by a version collision
self-heals. Columns go in `lib/core/database/tables/dive_tables.dart`.

## Testing

- `VisibilityScale.rangeFor` / `bandForRange` across presets, open ends and
  exact band edges.
- Repository write rule: each shape clears the others; legacy survives a
  write of neither.
- Edit form widget tests: mode toggle, chip pick saves the band's range,
  re-tap clears, off-scale range and legacy carried through untouched, mode
  memory.
- Formatter, Insights binning (fits and spans), filter bounds with open ends.
- CSV and UDDF round trips; merge takes one shape; sync payload without the
  columns hydrates.
- Migration test for v278.

## Out of scope

- Typing a free-form low and high (the diver chose band picks only).
- Changing the legacy bucket column or backfilling it.
- Syncing the mode preference.
