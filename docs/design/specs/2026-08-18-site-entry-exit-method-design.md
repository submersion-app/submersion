# Site-Level Entry and Exit Method

Issue: [#1104](https://github.com/submersion-app/submersion/issues/1104)
Date: 2026-08-18
Status: Approved

## Problem

Entry method is currently a per-dive field only. In practice it is a property
of the place: some sites can only be reached by boat, others can only be dived
from shore. Divers re-enter the same value on every dive at a site they visit
regularly.

Storing entry and exit method on the dive site and applying them when the site
is assigned to a dive removes that repetition.

## Background: two existing precedents

**Water type from site (#624).** `dive_sites.water_type` snaps onto a dive when
the diver assigns a site. The rule is a pure function,
`waterTypeAfterSiteAssign(current, site) => site?.waterType ?? current`
(`lib/features/dive_log/presentation/utils/water_type_autofill.dart:10`), called
from `_assignSite()` (`lib/features/dive_log/presentation/pages/dive_edit_page.dart:2096`).
This design copies that shape.

**A dead entry-type field.** `SiteConditions.entryType`
(`lib/features/dive_sites/domain/entities/dive_site.dart:232`),
`SiteField.entryType` (`lib/features/dive_sites/domain/constants/site_field.dart:41`),
and an "Entry Type" column in the CSV, Excel, and KML site exports all exist
today and are all permanently blank: there is no column behind them and
`_mapRowToSite` never hydrates `DiveSite.conditions`. `SiteConditions` is never
constructed anywhere in `lib`. Water type was in this same state before #624.
Repairing this is in scope.

## Decisions

| Decision | Choice | Rationale |
| --- | --- | --- |
| Default vs constraint | Default only | A site's value seeds the dive and is freely overridable. A hard "boat only" constraint creates edge cases (a boat-only site shore-dived at low tide; imported dives that contradict the site) for a rule the diver can honor by leaving the default alone. |
| One column or two | Two: `entry_method` and `exit_method` | Entry and exit genuinely differ (giant stride in, ladder out). |
| Backfill of existing sites | Opt-in suggestion in the site editor | Writing inferred values into every `dive_sites` row during migration would bump every row's HLC and push the whole site table through sync for guessed data, with no way to tell inferred values from entered ones. |
| Editor placement | Access and Safety section | The site detail page has no water-type display to copy; the natural display home is `_buildAccessSection`, alongside access notes, mooring number, and parking info. The write surface should agree with the read surface. |
| Control idiom | `EnumPickerRow` | The site editor renders enums as `ChoiceChip` wraps, which suits 3-value enums. `EntryMethod` has 9 values, so two fields would be roughly six rows of chips. `EnumPickerRow` is already in `lib/shared/widgets/forms/`, is what the dive form uses for these same two fields, and offers an explicit "Not specified" option. |
| Manual exit override | Sticky | An explicit site exit method must not overwrite an exit method the diver set by hand. The site knows the place; it does not know how the diver got out that day. |

## Data model

Two nullable TEXT columns on `dive_sites`, storing `EntryMethod.name`, matching
how `dives.entry_method` and `dives.exit_method` already store it:

```dart
TextColumn get entryMethod => text().nullable()();
TextColumn get exitMethod  => text().nullable()();
```

`EntryMethod` (`lib/core/constants/enums.dart:273-287`) is reused unchanged. It
already serves both entry and exit on the dive side.

`DiveSite` gains two `EntryMethod?` fields across the usual five places: field
declarations, constructor, `copyWith`, `props`, and row mapping
(`lib/features/dive_sites/domain/entities/dive_site.dart`).

`site_repository_impl.dart` gains them in its four `DiveSitesCompanion`
builders (`createSite`, `_writeSiteUpdate`, the restore/undo-merge insert, and
`_updateSiteRow`) plus `_mapRowToSite`.

### Migration

`currentSchemaVersion` goes 153 to 154. Following house style
(`_assertO2CellMillivoltColumns`, `database.dart:4716`), add a PRAGMA-guarded,
idempotent, self-guarding `_assertSiteEntryExitMethodColumns()` helper, called
twice: once from an `if (from < 154)` block in `onUpgrade`, once from the
`beforeOpen` backstop. The double call is the project's protection against
parallel branches colliding on a schema number.

Append `154` with a comment to `migrationVersions` so the migration progress
bar counts it.

### Sync

No sync work is required. `sync_data_serializer.dart` serializes whole Drift
rows via `row.toJson()` and HLC is per-row rather than per-field, so new
columns ride along automatically. A round-trip test asserting
`DiveSite.fromJson(row.toJson())` carries both fields guards this, mirroring
what #624 added.

## The snap rule

A pure function beside `waterTypeAfterSiteAssign`. It returns all three pieces
of form state together so the linked flag cannot drift out of sync with the
values:

```dart
class EntryExitSelection {
  final EntryMethod? entry;
  final EntryMethod? exit;
  final bool linked;
}

EntryExitSelection entryExitAfterSiteAssign({
  required EntryMethod? currentEntry,
  required EntryMethod? currentExit,
  required bool currentLinked,
  required DiveSite? site,
}) {
  final entry = site?.entryMethod ?? currentEntry;
  final entryChanged = entry != currentEntry;

  final EntryMethod? exit;
  if (!currentLinked) {
    exit = currentExit;                // manual override is sticky
  } else if (site?.exitMethod != null) {
    exit = site!.exitMethod;
  } else if (entryChanged) {
    exit = entry;                      // still linked, follow the new entry
  } else {
    exit = currentExit;
  }

  return EntryExitSelection(
    entry: entry,
    exit: exit,
    linked: exit == null || exit == entry,
  );
}
```

Called from `_assignSite()` (`dive_edit_page.dart:2096`), the single funnel for
user-initiated site assignment. The load path at `:664` stays untouched, so
reopening a saved dive never re-snaps it.

### Behavior table

| Site has | Dive had | Result |
| --- | --- | --- |
| nothing, or site cleared | anything | unchanged |
| boat, no exit | shore / shore, linked | boat / boat, still linked |
| boat, no exit | shore / ladder, unlinked | boat / ladder, stays unlinked |
| giant stride + ladder | shore / shore, linked | giant stride / ladder, link breaks |
| boat + boat | shore / ladder, unlinked | boat / ladder, stays unlinked |
| giant stride + ladder | nothing set (new dive) | giant stride / ladder, unlinked |

The `entryChanged` guard is load-bearing. Without it, clearing the site
(`_assignSite(null)`, reached from `onClearSite`) or assigning a site with no
entry method would still take the mirror branch and write `exit = entry`,
materializing an exit method on a dive that had none. The water-type rule gets
this for free because `site?.waterType ?? current` is inherently a no-op on
null; a two-field rule with a mirror branch must earn it explicitly.

### Known limitation

`_exitMethodLinked` is reconstructed on load as `exit == null || exit == entry`
(`dive_edit_page.dart:684`) rather than persisted. A diver who deliberately set
exit equal to entry is therefore indistinguishable from one who never touched
the field, and their override will not be sticky across a reopen. Persisting
the flag would mean adding a schema column to record a UI state, which is not
worth it. Recorded here so it is not rediscovered as a bug.

## Site editor

Both fields render as `EnumPickerRow<EntryMethod>` in
`lib/features/dive_sites/presentation/widgets/edit_sections/access_safety_section.dart`.

They take **dedicated** `entryMethodExtras` / `exitMethodExtras` parameters,
mirroring `DiveInfoSection.waterTypeExtras`. They must not reuse the section's
generic `mergeExtras: (String key)` callback: that callback resolves through
`_mergeTextCandidates[key]` and cycles via `_cycleTextField(key)`
(`site_edit_page.dart:678-691`), both of which are backed by
`TextEditingController`s and would return null for an enum field.

`_accessSummary()` (`site_edit_page.dart:779-789`) and its `isEmpty` gate at
`:900` must include the new values, or the section collapses as empty when
entry method is the only field set.

There is no link toggle on the site. Leaving a site's exit method unset already
means "same as entry" by virtue of the snap rule's mirror branch; a link
control would be a second way to express what the null already expresses.

### Merge mode

Sites are mergeable, and each mergeable field needs five coordinated pieces:

1. A `List<_MergeFieldCandidate<EntryMethod?>>` state field.
2. A `_buildDistinctCandidates` call in `_initializeFromMerge`.
3. A `_mergeFieldIndices['<key>']` string key, used in four places.
4. An `_xExtras()` builder returning `MergeFieldExtras` when there are two or
   more candidates.
5. A `_cycleX()` method.

Ten pieces total for two fields.

Enum fields must **not** be added to `_selectTextFieldCandidate`'s
`switch (key)` (`site_edit_page.dart:1064`), which handles
`TextEditingController`s only. Add a comment there noting the omission is
deliberate.

## Site detail page

Two rows in `_buildAccessSection` (`site_detail_page.dart:1422`) via the
existing `_buildDetailRow` helper.

`_hasAccessInfo()` (`:983`) currently checks only access notes, mooring number,
and parking info. It must include the new fields, or a site whose entry method
is the only populated field renders no access card at all.

## Suggestion from dive history

### Derivation

A new pair-wise query on the statistics repository, where this SQL idiom
already lives (`getEntryMethodDistribution`,
`lib/features/statistics/data/repositories/statistics_repository.dart:1186`):

```sql
SELECT entry_method, exit_method, COUNT(*) AS count
FROM dives
WHERE site_id = ? AND diver_id = ?
  AND entry_method IS NOT NULL AND entry_method != ''
GROUP BY entry_method, exit_method
ORDER BY count DESC
```

Grouping on the **pair** is required, not incidental. The dive form defaults
exit method to mirror entry (`_exitMethodLinked = true`), so in most logged
dives `exit_method == entry_method` because the diver never touched the field,
not because they observed it. Taking the most common `exit_method`
independently would systematically over-report "in and out the same way".
Grouping jointly reports what the logs actually say.

Rows where `entry_method` is null carry no information and are excluded. A null
`exit_method` in the winning pair is meaningful and is carried through as "not
set".

### Exposure

A `FutureProvider.family<EntryExitSuggestion?, String>` keyed by site id in
`lib/features/dive_sites/presentation/providers/site_providers.dart`, with
`ref.invalidateSelfWhen(diveRepository.watchDivesChanges())` so site merges,
bulk edits, and sync pulls refresh it. That subscription is needed for the same
reason `mediaFromDivesAtSiteProvider`
(`lib/features/media/presentation/providers/site_media_providers.dart:36-47`)
needs it: those operations change site-to-dive membership without touching the
site row.

Returns null when there are no qualifying dives.

### Presentation

An `ActionChip` inside a nested `Consumer`, copying the outlier-suggestion
pattern at `dive_edit_page.dart:2480-2508`: `.when(loading/error =>
SizedBox.shrink(), data => ...)`, and `SizedBox.shrink()` when the suggestion
is null. Tapping it fills both fields and sets `_hasChanges = true`.

The chip appears **only when both site fields are empty**. This is the guard
against circularity: once site values start snapping onto new dives, those
dives become evidence that would otherwise "confirm" the value the site itself
produced. A site whose entry method is already set is never second-guessed.

## Repairing the dead field

- `SiteField.entryType`'s extractor (`site_field.dart:522`) points at the real
  column. A sibling `SiteField` member is added for exit method.
- The enum member keeps the name `entryType`. It must **not** be renamed to
  `entryMethod` for consistency: renaming an entity-field enum value throws
  when a user's saved table layout still references the old name, a bug this
  project has hit before. Add a comment explaining why the member name no
  longer matches the column name.
- The blank "Entry Type" column in the CSV, Excel, and KML site exports is
  repointed at the real field, and an exit column is added alongside.
- **UDDF is deliberately left alone.** This was planned and then dropped
  during implementation: `entrytype` is a *dive-level* element in UDDF, living
  under `<informationbeforedive>`, and both of this project's exporters emit it
  there (`uddf_export_builders.dart:274`, `uddf_export_service.dart:243`).
  UDDF defines no site-level entry type, so adding one would mean inventing a
  non-standard element that no other tool reads and that other parsers might
  reject. The dive-level import path already maps `entrytype` onto
  `Dive.entryMethod` and is unaffected. Nothing is lost for this project's own
  round trip, since backups copy the SQLite file and sync serializes whole
  rows.
- Retiring `SiteConditions` (`dive_site.dart:225-254`) is a **separate,
  independently rejectable final task**, because the class has three more dead
  readers beyond `entryType`: `SiteField.typicalVisibility`,
  `SiteField.typicalCurrent`, and `SiteField.bestSeason`
  (`site_field.dart:517-525`). Those three enum members must be **kept** (saved
  layouts reference them by name) with their extractors returning `null` and a
  comment, before `DiveSite.conditions` and the class can be removed. The
  feature does not depend on this task.

### Bonus defect found while tracing

The CSV and Excel site exporters read `site.conditions?.waterType` and
`site.conditions?.typicalCurrent` (`csv_export_service.dart:230-231`,
`excel_export_service.dart:315-316`), and the KML exporter does the same behind
a null check (`kml_export_service.dart:227-243`). So the **Water Type** column
in the CSV and Excel site exports is blank today as well: #624 repointed
`site_field.dart` but not the exporters. `site.waterType` is real and populated.
Repointing water type and typical current alongside entry method is a one-line
change per exporter and is in scope.

## Localization

New ARB keys across all 11 locales (`lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`):
two site-editor row labels, two site-detail row labels, and the suggestion chip
string. The `enum_entryMethod_*` value keys
already exist and are reused. The existing `diveSites_detail_diveCount_*`
plural keys inform the chip's phrasing.

The site editor's existing enum controls use the unlocalized
`value.displayName`; the new controls use the localized
`EntryMethodDisplay.localizedName`
(`lib/features/dive_log/presentation/widgets/environment_enum_display.dart:60-73`),
matching the dive form. This is a deliberate deviation from the neighboring
code and costs nothing, since the value keys already exist.

## Testing

**Unit**

- `entryExitAfterSiteAssign` across every row of the behavior table, plus the
  two no-op cases (site cleared, site with neither value set).
- Pair derivation, including a fixture where exit mirrors entry on most dives,
  asserting the joint pair is reported rather than an inflated independent
  mode.
- `DiveSite` `copyWith` and `props` covering the new fields.

**Database**

- v153 to v154 migration test.
- Idempotency: the assert helper runs twice without error.
- Sync round-trip through `row.toJson()` / `DiveSite.fromJson`.

**Widget**

- Site editor: both rows render, save, and round-trip through reload.
- Site editor merge mode: candidate cycling for both fields.
- Suggestion chip: appears when both fields are empty and dives exist; absent
  when either field is set; fills both fields on tap.
- Site detail: access card renders when entry method is the only populated
  field.
- Dive edit: assigning a site snaps the pair; the sticky-override case does not
  overwrite a manual exit method.

## Out of scope

- Constraining a dive's entry method to a site's allowed set ("boat only"
  sites). Deferred; a site can express this today by setting the default.
- Bulk backfill of existing sites. The per-site suggestion covers the sites a
  diver actually revisits.
- Persisting `_exitMethodLinked`.
