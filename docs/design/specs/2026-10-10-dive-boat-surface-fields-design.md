# Dive Boat and Surface Condition Fields: Design

Status: approved in design review, 2026-10-10. Target release: v1.8.2.

## Problem

Migration 71 added four free-text columns to `dives` for MacDive and UDDF
imports: `dive_operator`, `boat_name`, `boat_captain` and
`surface_conditions`. The importers write them straight into a
`DivesCompanion`, but the `Dive` domain entity never carried them, so they are
invisible: no editor field, no detail row, no export. A diver who imported
from MacDive has the data in the database and cannot see it, and a diver who
wants to record the boat they dived from has nowhere to type it.

The columns are already half-integrated: sync encodes `dives` rows generically
(`row.toJson()`), the sync conflict catalogue labels all four, and the query
language knows `boatName`, `diveOperator` and `surfaceConditions`.

## Scope

All four orphaned columns are surfaced, not only the three originally named,
so no imported value stays hidden. No schema change: the columns exist.

| Field | Entity name | Editor group | Detail page |
| --- | --- | --- | --- |
| Operator | `diveOperator` | Trip & dive center | Details card |
| Boat | `boatName` | Trip & dive center | Details card |
| Captain | `boatCaptain` | Trip & dive center | Details card |
| Surface conditions | `surfaceConditions` | Conditions | Environment > Dive conditions |

All four stay free text. MacDive stores surface conditions as text ("Calm",
"Choppy"), so an enum would lose imported values.

## Data model and persistence

- `Dive` gains the four `String?` fields: constructor, `copyWith`, `props`.
  They are flat fields beside `weatherDescription`, whose path through the
  codebase each one follows.
- Both row-to-`Dive` mappers in `dive_repository_impl.dart` read the four
  columns. A mapper that forgot one would turn every later save into a silent
  eraser of imported data, because the update path writes the fields
  unconditionally.
- Create and update write `Value(dive.<field>)`, as `diveMaster` is written,
  so clearing a field stores NULL.
- The editor trims input and stores empty text as NULL.
- Merge/combine (`dive_merge_builder.dart`): first non-null value per field.
- Uncombine (`dive_uncombine_service.dart`): unchanged. It already nulls
  operator, boat and captain on restored dives; surface conditions describe
  the water and carry, consistent with that service's rule.
- Mirror dive (`dive_mirror_fields.dart`): all four are mirrored. The boat,
  captain, operator and sea state are facts both divers share.
- Planned-dive fill (`planned_dive_fill_fields.dart`): all four are
  `kHumanDiveFields`, so a computer download never overwrites them.
- Query language: `boatCaptain` is added beside the existing three text
  fields, with an l10n label.
- Sync and the conflict catalogue need no change.

## Editor

- Trip & dive center group (`trip_section.dart`): Operator, Boat, Captain
  rows below Dive center, each a `SuggestionFormRow` with word
  capitalization. The collapsed summary adds the boat name; `isEmpty` also
  checks the three fields.
- Conditions group (`conditions_section.dart`): Surface conditions in the
  environment rows beside current and swell, a `SuggestionFormRow` with
  sentence capitalization. Summary and `isEmpty` include it.
- Suggestions: a repository query returns the active diver's distinct
  non-blank values of one column, most recently used first, capped at 50,
  exposed as a provider family keyed by field. Scoped to the active diver, so
  a diver switch never offers another diver's boats.

## Detail page

- Details card: Operator, Boat, Captain rows right after the Dive center row,
  each only when non-empty. Plain text, not links.
- Environment > Dive conditions: Surface conditions after Swell.
  `hasDiveConditions` counts it, so a dive whose only condition is "Choppy"
  gets the subsection.

## Export and import

- UDDF: both writers (`uddf_export_builders.dart`, `uddf_export_service.dart`)
  emit `<surfaceconditions>`, `<boatname>`, `<boatcaptain>` and
  `<diveoperator>` inside `<informationafterdive>`, the element names
  `uddf_full_import_service.dart` already reads. A round-trip keeps them.
- CSV: columns `Dive Operator`, `Boat Name`, `Boat Captain`,
  `Surface Conditions` in `DiveCsvColumns` and `csv_dives_writer.dart`,
  sanitized like other text. The Submersion CSV parser reads them back under
  the keys `IncomingDiveData` already declares.
- Excel: the same four columns beside Weather Description.

## List and table columns

Four new `DiveField` values with name, short name, extractor and text-width
column sizing. Operator, Boat and Captain are in the `location` category
beside Dive Center; Surface Conditions is in `environment` beside Weather.
None is enabled by default.

## Bulk edit

Four new `BulkField` gates. Operator, Boat and Captain sit in the bulk form's
dive center and trip group; Surface Conditions in the bulk Conditions group.
Each is wired like `weatherDescription`: an enabled gate with a value sets it
on every selected dive, an enabled gate with empty text clears it.

## PDF logbook

The detailed template prints Operator, Boat and Captain beside Dive Master,
and Surface Conditions with the environment fields, each only when present.
Compact templates are unchanged.

## Strings

New l10n keys for edit labels, detail labels, `DiveField` names (long and
short), the query label for `boatCaptain`, and PDF labels, in all 11 locales.
Translations reuse the wording of the existing `settings_conflict_field_*`
keys so terminology matches the sync conflict screen.

## Testing

- Repository: create with all four, read back through both mappers, update an
  unrelated field and confirm all four survive. Clearing stores NULL. An
  import-shaped row written straight to `DivesCompanion` is visible on the
  entity and survives an editor save.
- Census: the mirror and planned-fill census tests fail until the fields are
  classified; assertions that mirror copies them and planned fill keeps them.
- Merge: first non-null wins per field.
- Suggestions query: distinct, most recent first, scoped to the diver, blank
  and NULL excluded, capped at 50.
- Widgets: editor rows, summaries and a suggestion offered on a typed prefix;
  detail rows only when non-empty; the conditions subsection appears for
  surface conditions alone.
- Export: UDDF round-trip through both writers; CSV export then Submersion CSV
  import; Excel columns present.
- `DiveField`: categories; the existing exhaustive tests cover the rest.
- Bulk edit: set on all selected dives; empty text clears.
- Guards: `test/architecture/`, `test/shared/` and the l10n staleness check.
