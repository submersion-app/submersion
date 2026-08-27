# GPS coordinate formats

Issue: [#1041](https://github.com/submersion-app/submersion/issues/1041)
Date: 2026-08-14
Status: approved for planning

## Problem

Submersion shows every latitude and longitude as bare decimal degrees. A diver
reading coordinates off a chartplotter, a dive-guide PDF, or a boat skipper's
whiteboard sees degrees and minutes; a diver working from a topographic map or
a survey sees UTM or MGRS. Today those users convert by hand in both
directions, and the app gives no way to see a site in the notation they think
in.

There is a second, quieter problem. The app has no shared coordinate formatter
at all. Roughly fifteen display sites each call `toStringAsFixed` inline, at
four, five, or six decimals depending on who wrote them. The same site shows
`25.0760` on one screen and `25.076000` on another. Adding a format preference
requires introducing the formatting seam that should already exist, and the
inconsistency disappears as a side effect.

## Scope

Five display formats, selectable in Settings, applied to every user-facing
coordinate and to coordinate entry:

| Format | Example | Who uses it |
| --- | --- | --- |
| Decimal degrees (DD) | `20.361944° N, 87.029722° W` | Current behavior; web maps, APIs |
| Degrees decimal minutes (DDM) | `20° 21.717' N, 87° 01.783' W` | Marine GPS, chartplotters, most dive boats |
| Degrees minutes seconds (DMS) | `20° 21' 43.0" N, 87° 01' 47.0" W` | Charts, cartographic convention |
| UTM | `16Q 496898E 2251535N` | Land survey, topographic maps |
| MGRS | `16Q DH 96898 51535` | Military, search and rescue |

All five rows describe the same point (Palancar reef, Cozumel) and were
generated from the NGA GEOTRANS library, not written by hand.

DD remains the default, so no diver has to choose anything to keep working the
way they do now. Two small changes do reach a diver who never opens the
setting: DD gains a degree symbol and a hemisphere letter (`20.361944° N`
rather than the current signed `20.361944`), and the display sites that
currently round to four or five decimals become consistent at six.

### Out of scope

- **Exports keep decimal degrees.** CSV, Excel, UDDF, and GPX are interchange
  formats read by other software. A user's display preference must not change
  what a machine-readable file contains.
- **Cache keys and logs keep fixed-precision DD.** The reef, bathymetry,
  weather, and dashboard layers build cache and dedup keys out of rounded
  coordinates. Reformatting those would silently invalidate every cached tile
  and every dedup match.
- **UPS (polar) is not implemented.** UTM and MGRS are undefined beyond
  84° N / 80° S, where the standard switches to the Universal Polar
  Stereographic projection. Outside that band the app falls back to DD. The
  northernmost genuine dive destinations — Svalbard at roughly 80° N — sit
  inside the UTM band, so UPS is unbuilt complexity.
- **No datum selection.** Everything is WGS84, which is what the GPS receivers,
  the map tiles, and the stored data already are.

## Architecture

### Stored data does not change

A coordinate is stored as it always has been: two `double` columns in decimal
degrees. Format is a rendering preference, in the same spirit as
`visibility_scale.dart` — the measurement is the truth, the presentation is a
per-diver choice, and changing the choice re-labels the logbook without
altering a single record. Every new module converts to and from DD doubles at
its boundary.

### New module: `lib/core/utils/coordinates/`

| File | Responsibility |
| --- | --- |
| `coordinate_format.dart` | `enum CoordinateFormat { decimalDegrees, degreesDecimalMinutes, degreesMinutesSeconds, utm, mgrs }`, each with a display name and a worked example for the settings picker |
| `coordinate_formatter.dart` | Pure `String format(double lat, double lng, CoordinateFormat)` plus single-axis variants for DD/DDM/DMS |
| `coordinate_parser.dart` | Tolerant `ParsedCoordinates? parse(String)` accepting **all five** formats regardless of the active preference |
| `utm_converter.dart` | WGS84 transverse Mercator forward and inverse, zone and latitude band, including the Norway and Svalbard zone exceptions |
| `mgrs_converter.dart` | 100 km square lettering over UTM, 10-digit (1 m) precision |

The enum mirrors the existing `units.dart` pattern (`DepthUnit`,
`VisibilityScalePreset`): a plain Dart enum carrying its own display metadata,
persisted by `.name`.

#### Precision

| Format | Precision | Ground resolution |
| --- | --- | --- |
| DD | 6 decimal places | ~0.11 m |
| DDM | 3 decimal places on minutes | ~1.85 m |
| DMS | 1 decimal place on seconds | ~3.1 m |
| UTM | 1 m | 1 m |
| MGRS | 10-digit | 1 m |

The worked examples in the format table above are the authoritative rendering,
spacing included: MGRS is grouped (`16Q DH 96898 51535`) rather than run
together, because grouped digits are what a person reads a grid reference from
aloud.

One convention difference between the two grid formats matters and is easy to
get wrong: **UTM rounds to the nearest metre, MGRS truncates.** A UTM
coordinate names a point, but an MGRS reference names a square and is
identified by its south-west corner, so rounding would name the wrong square
for any position in the upper half of one.

These are display precisions only, chosen so that no format loses meaningful
precision relative to a consumer GPS fix (roughly 3-5 m). Round-tripping a
displayed string back through the parser must land within the format's own
ground resolution.

#### No new dependency

`latlong2` and `flutter_map` are already in `pubspec.yaml`; neither performs
UTM or MGRS conversion. The maintained alternatives pull in a general
projection engine to use one projection. The transverse Mercator series for a
single known datum is about 150 lines of fully specified math, and it is
verifiable against published reference points, so it is implemented directly.

### Settings plumbing

Follows the v144 `visibilityScalePreset` path end to end, which is the most
recent worked example of adding an enum setting:

1. `AppSettings.coordinateFormat` field, constructor argument, and `copyWith`
   (`lib/features/settings/presentation/providers/settings_providers.dart`)
2. `SettingsNotifier.setCoordinateFormat`, matching the existing
   `setVisibilityScale` shape
3. `coordinateFormatProvider` selector alongside `depthUnitProvider` and
   friends
4. Drift `TextColumn get coordinateFormat` on `DiverSettings`
   (`lib/core/database/database.dart`), `withDefault(const
   Constant('decimalDegrees'))`, persisted as `enum.name`
5. `DiverSettingsRepository`: insert defaults, update, row-to-entity mapping,
   and a `_parseCoordinateFormat` with an `orElse` fallback to
   `decimalDegrees`
6. `_applyDiverSettingDefaults` in `sync_data_serializer.dart` gains
   `'coordinateFormat': 'decimalDegrees'`, so a peer running an older schema
   does not null the column out

### Migration

Schema version goes from 149 to **150**. Note that the ladder comments in
`database.dart` record two prior renumberings (v145 and v147) caused by
parallel branches claiming the same step; the version must be re-verified
against `origin/main` immediately before opening the PR.

The migration adds one nullable-safe column using the established idempotent
DDL helper pattern, a sibling of `_assertVisibilityScaleColumns`:

```dart
Future<void> _assertCoordinateFormatColumn() async {
  final cols = await customSelect("PRAGMA table_info('diver_settings')").get();
  if (cols.isEmpty) return;
  final names = cols.map((c) => c.read<String>('name')).toSet();
  if (!names.contains('coordinate_format')) {
    await customStatement(
      'ALTER TABLE diver_settings ADD COLUMN coordinate_format '
      "TEXT NOT NULL DEFAULT 'decimalDegrees'",
    );
  }
}
```

Called from three places, matching the codebase's dual-call contract: the
`onUpgrade` step guarded by `if (from < 150)`, the `beforeOpen` backstop, and
the migration progress-step list with an explanatory comment.

### Display integration

`UnitFormatter` gains `formatCoordinates(double lat, double lng)`, joining
`formatDepth`, `formatDistance`, and the rest of the family, reading
`settings.coordinateFormat`. The roughly fifteen user-facing display sites
switch to it, which also unifies their inconsistent precision.

`GeoPoint.toString()` in `dive_site.dart` stays decimal degrees. It is a domain
entity with no access to settings, and it is used in contexts where a stable
machine-ish representation is correct. The site detail page, which currently
leans on it for both display and clipboard, moves to `UnitFormatter` — and
copying to the clipboard copies the string the user is actually looking at.

### Input integration

One `CoordinateInput` widget in `lib/core/widgets/`, consumed by both
`site_edit_page` (via `location_section.dart`) and `dive_center_edit_page`.

The two-independent-fields contract that both forms use today cannot express
UTM or MGRS: an MGRS reference is a single token encoding both axes, and UTM
needs a zone shared between them. So the widget owns the whole coordinate pair
and renders whatever sub-fields the active format requires:

- DD, DDM, DMS: two rows, one per axis, with per-component sub-fields and a
  hemisphere selector
- UTM: zone, band, easting, northing
- MGRS: a single grid reference field

Its public interface stays in decimal degrees — it takes `double? latitude,
double? longitude` and reports changes as the same — so the form, the
validators, and the database contract are unchanged by which format is active.

Pasting a full coordinate string into any sub-field runs the tolerant parser
and populates the whole group. A DMS string pasted while the app is set to UTM
still works; the parser is deliberately independent of the display preference,
because text arrives from the outside world in whatever format its author used.

### Settings UI

A "Coordinate format" tile in `_UnitsSectionContent` in `settings_page.dart`,
placed with the other unit rows, opening a picker in the same style as the
depth and temperature pickers. Each option shows the same worked example
rendered in that format, so the choice is legible without prior knowledge of
the notations. New strings are translated across all supported locales.

## Error handling

- **Parse failure** returns null rather than throwing; forms surface the
  existing validation message. Partially typed input is a normal state during
  editing, not an error.
- **Out-of-range values** — |lat| > 90, |lng| > 180, minutes or seconds ≥ 60 —
  fail parsing rather than silently normalizing, since they almost always mean
  a typo or a misread format.
- **Polar coordinates** beyond the UTM band render as DD with no error; the
  input widget likewise falls back to its DD layout.
- **Unparseable stored data** cannot occur: storage is always two doubles.

## Testing

Test-first throughout.

| Area | Coverage |
| --- | --- |
| Formatter | Golden vectors for each of the five formats, including both hemispheres, the equator, the prime meridian, and the poles |
| UTM/MGRS | Published reference points (NGA / GeographicLib), plus round-trip error bounds across a spread of latitudes and both hemispheres, and the Norway/Svalbard zone exceptions |
| Parser | Every format accepted; symbol variants (`°`, `'`, `"`, `′`, `″`); hemisphere as prefix and suffix; negative-sign forms; junk input rejected; out-of-range rejected |
| Round-trip | Format then parse returns the original within the format's ground resolution |
| Migration | A v149 database upgrades to v150 with the column present and defaulted |
| Repository | Round-trip of every enum value through Drift |
| Widget | Settings picker changes the setting; `CoordinateInput` renders and parses correctly in each of the five formats; paste-any-format into any sub-field |

Formatter tests must pin `Intl.defaultLocale`, following the existing unit-test
convention, so decimal separators do not vary by host locale.

## Sequencing

1. `coordinate_format.dart` and `coordinate_formatter.dart` for DD, DDM, DMS,
   with tests
2. `utm_converter.dart` and `mgrs_converter.dart` against reference vectors
3. `coordinate_parser.dart` for all five formats
4. Settings plumbing, schema v150, sync defaults
5. `UnitFormatter.formatCoordinates` and the display-site migration
6. `CoordinateInput` and its two consuming forms
7. Settings UI and localization

Steps 1-3 are pure Dart with no Flutter or database dependency, so they are
fully testable before any integration work begins.
