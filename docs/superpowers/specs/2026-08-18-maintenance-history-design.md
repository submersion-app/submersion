# Maintenance history: legibility, filtering, default price, Excel log

Issue: [#829](https://github.com/submersion-app/submersion/issues/829)
Date: 2026-08-18
Status: design approved, implementation pending

## Problem

A rebreather diver defined custom maintenance tasks (Disinfect, Replace O2
sensor, Replace controller battery, Replace scrubber) and logged work against
them. The service history list on the equipment detail page shows a row per
record, but the rows do not say which task was completed. Every Disinfect
record and every scrubber repack renders as the same generic label.

The cause is a single line. `_ServiceRecordTile` titles each row with the
generic `ServiceType` enum rather than the maintenance task:

```dart
// lib/features/equipment/presentation/pages/equipment_detail_page.dart:1089
title: Text(record.serviceType.displayName),
```

Every record already carries `serviceKindId`, and the add/edit dialog already
collects it (`equipment_detail_page.dart:1287`). The history list simply never
resolves it to a name.

The reporter additionally asks for a filter over the history, a default price
carried on the maintenance task so it does not have to be retyped, and an
Excel export of the maintenance log.

## Terminology

The issue's vocabulary maps onto existing concepts:

| Issue term | Codebase concept | Table |
| --- | --- | --- |
| maintenance task ("Disinfect") | `ServiceKind` | `service_kinds` |
| maintenance type ("Cleaning") | `ServiceType` enum | column on `service_records` |
| maintenance interval | `ServiceSchedule` (per item clock) | `service_schedules` |
| maintenance history entry | `ServiceRecord` | `service_records` |

`ServiceKind` and `ServiceType` are orthogonal, and the issue asks for both to
be visible. A kind answers "which of my tasks"; a type answers "what category
of work". Kinds are user extensible (managed at `/gear/service-types` via
`ServiceKindListPage`); types are a fixed ten-value enum.

## Goals

1. A history row states which maintenance task was completed, alongside its
   type, date, price, and next due date.
2. The history can be narrowed by task, type, and year.
3. A price can be defaulted on the task catalog entry and on the per item
   interval, and prefills the cost field when a record is logged.
4. The maintenance log can be exported to Excel, both for one item and across
   all equipment.

## Non-goals

- Changing how service clocks compute due dates. `ServiceDueEngine` is
  untouched.
- Making the price binding. The resolved default is a prefill only; the user
  can always overwrite or clear it.
- Currency conversion. Totals stay grouped per currency, as `sumByCurrency`
  already does.
- Fixing the incremental sync HLC gap (issue #1144). See "Deferred work";
  main resolved it independently before this branch merged.

## Current state

| Concern | Location |
| --- | --- |
| History section | `equipment_detail_page.dart:823-1060` (`_ServiceHistorySection`) |
| History row | `equipment_detail_page.dart:1062-1163` (`_ServiceRecordTile`) |
| Add/edit dialog | `equipment_detail_page.dart:1165-1594` (`ServiceRecordDialog`) |
| Record entity | `lib/features/equipment/domain/entities/service_record.dart` |
| Records table | `lib/core/database/database.dart:1894-1918` |
| Kinds table | `lib/core/database/database.dart:1133-1159` |
| Schedules table | `lib/core/database/database.dart:1161-1189` |
| Repository | `lib/features/equipment/data/repositories/service_record_repository.dart` |
| Providers | `lib/features/equipment/presentation/providers/equipment_providers.dart:353-470` |
| Kind editor | `lib/features/equipment/presentation/pages/service_kind_list_page.dart:283` |
| Schedule editor | `lib/features/equipment/presentation/widgets/service_schedule_dialogs.dart:112` |
| Money formatting | `lib/core/utils/currency.dart` |
| Excel export | `lib/core/services/export/excel/` |

`equipment_detail_page.dart` is 1596 lines, roughly twice the 800 line ceiling
in CLAUDE.md. The history section and dialog account for about 770 of them.

## Design

### 1. Rows that name the task

`_ServiceRecordTile` resolves `record.serviceKindId` against the already
available `serviceKindsProvider` and titles the row with the kind name,
falling back to the localized service type when the record is untagged.

Target layout:

```
[icon]  Scrubber repack                          |
        Cleaning . 14 Mar 2026                   | (popup menu)
        DiveShop Bonn . 45,00 EUR                |
        Next due 14 Jun 2026
```

`notes`, when present, renders as a final single line with
`maxLines: 1, overflow: TextOverflow.ellipsis`. Both `notes` and
`nextServiceDue` are collected by the dialog today and displayed nowhere.

**Cost moves out of `trailing`.** The current tile uses
`trailing: Row(... Text(formatMoney(...)), PopupMenuButton ...)`
(`equipment_detail_page.dart:1101`). `_RenderListTile` lays `trailing` out
against the full tile width first and gives the title whatever remains,
clamped at zero, so a text bearing trailing widget starves the title. This is
the defect class swept in PR #1026 for issue #935; this tile was missed. It
degrades silently in release, because Flutter's guard is behind an `assert`,
rendering one glyph per line.

The fix matters directly here: this design replaces a short English title
("Cleaning") with a user authored kind name in the user's own language
("Sauerstoffsensor ersetzen"), which would make the starvation worse. After
the change, `trailing` holds only the fixed width `PopupMenuButton`, cost and
provider live in the subtitle column, and the title carries `maxLines: 1` plus
`TextOverflow.ellipsis` as a backstop. `isThreeLine: true` accommodates the
taller subtitle.

**`ServiceType` gets localized.** `ServiceType.displayName`
(`lib/core/constants/enums.dart:240-254`) is hardcoded English and is used in
exactly three UI places: the tile title (`:1089`), the delete confirmation
(`:1028`), and the dialog dropdown (`:1277`). A
`serviceTypeLabel(AppLocalizations)` extension supplies localized strings for
those three, while `displayName` and `.name` stay untouched for export and
persistence, where English and the stable identifier are correct. This is a
real bug in its own right: the reporter runs a German build, and the app ships
eleven locales.

### 2. Filter

A `MaintenanceHistoryFilter` value object holds three optional selections:

```dart
class MaintenanceHistoryFilter {
  final String? serviceKindId;   // null = all; sentinel for untagged
  final ServiceType? serviceType;
  final int? year;
  bool get isActive => ...;
  bool matches(ServiceRecord record) => ...;
}
```

Filtering happens in the presentation layer over the already loaded per item
record list. The repository is untouched: `getRecordsForEquipment` already
returns one item's records ordered by date descending, and these lists are
small enough that a query level filter would add complexity without benefit.

The control is a `Wrap` of three compact dropdown chips, so they sit on one
row on desktop and wrap on a phone. Each dropdown is populated only from
values actually present in that item's history, so there are no dead options,
and each shows a count. The task dropdown includes an "untagged" bucket for
records with a null `serviceKindId`. When a filter is active, a summary line
with a clear affordance appears, following
`statistics_filter_bar.dart:11-47`. When the filter matches nothing, a
distinct empty state is shown rather than the "no records yet" state.

Filter state is local `setState` in the section widget, matching
`equipment_list_content.dart:636-696`. It does not need to outlive the page.

### 3. Default price

Two new nullable columns on each of `service_kinds` and `service_schedules`:

```dart
RealColumn get defaultCost => real().nullable()();
TextColumn get defaultCurrency => text().nullable()();
```

`defaultCurrency` is nullable, deliberately diverging from
`ServiceRecords.currency` (`withDefault(Constant('USD'))`) and
`DiverSettings.defaultCurrency`. Here null carries meaning: "no opinion, fall
back to `defaultCurrencyProvider`". A non-null default would make every task
silently claim USD.

**Resolution order (most specific wins):**

```
schedule.defaultCost -> kind.defaultCost -> blank
```

The issue text lists template before interval. That is inverted relative to
specificity: a `ServiceKind` is global across every item using it, while a
`ServiceSchedule` is per equipment item, so a diver with two rebreathers
serviced at different shops could never reach the per unit price. Because the
issue also says the user "can then delete or overwrite this manually", the
whole chain is a prefill rather than a binding value, so the per item value
winning is consistent with the reporter's stated goal.

The prefill applies only when **creating** a record, including via the clock
card's "Log service" action which pre-tags `serviceKindId`. Editing an
existing record never re-prefills, so a deliberately cleared cost stays
cleared. Changing the kind selection in an open create dialog re-resolves the
prefill, but only while the cost field is untouched by the user.

Currency resolves along the same chain, falling back to
`defaultCurrencyProvider`.

**Editors.** `_ServiceKindEditDialog`
(`service_kind_list_page.dart:283`) and `_ScheduleOverrideDialog`
(`service_schedule_dialogs.dart:129`) each gain a cost field and a currency
picker. The schedule dialog shows the kind's value as a hint when its own
override is blank, reusing the existing inherit-hint idiom at
`service_schedule_dialogs.dart:196-208`.

Both dialogs must use `formatDecimalForInput` to seed and `parseUserDecimal`
to read back, as they already do for the hours interval. `toString()` would
seed "12.5" in a locale where "." is a thousands separator (issue #1091).
Both build their entity directly rather than through `copyWith`, per the
existing comments at `service_kind_list_page.dart:461` and
`service_schedule_dialogs.dart:271`; the new nullable fields need the
`_undefined` sentinel in `copyWith` so they can be cleared to null.

**Built-in kinds get no seeded price.** `kSeedBuiltInServiceKindsSql`
(`database.dart:2220-2258`) is `INSERT OR IGNORE`, so seeded values would
never reach an existing installation. Prices are also personal and regional.
Leaving the seed alone keeps its positional column list and the
characterization test in `service_ledger_schema_test.dart` intact.

**Migration v157.** A PRAGMA guarded `_assertServiceCostColumns()` helper
modeled on `_assertO2CellMillivoltColumns` (`database.dart:4718`), with the
early return on `cols.isEmpty` that minimal test fixtures require. Registered
in three places, per house convention:

1. `currentSchemaVersion = 157` (`database.dart:3072`)
2. `157,` appended to `migrationVersions` with a comment (`:3283-3293`)
3. the `if (from < 157) { ... }` plus `if (from < 157) await reportProgress();`
   pair in `onUpgrade` (`:8074-8093`), and the `beforeOpen` backstop (`:8241`)

Main was at 153 when this was written. It has since taken 154 (#1104 site
entry/exit method), 155 (#828 gas model) and 156 (#1127 travel gas), so this
migration renumbered twice and landed on **157**.

The second collision was the dangerous kind. Both sides had independently
written `currentSchemaVersion = 156`, so git auto-merged that line with **no
conflict marker** while the two 156s meant different migrations; only the
comment blocks around the ladder entries conflicted. Re-grep the scalar after
every schema merge rather than trusting the absence of markers.

The floor (`minimumCompatibleSchemaVersion`) stays at 137: these are new
nullable columns, which that constant's docstring explicitly excludes from
raising it.

**Sync requires no serializer changes.** `sync_data_serializer.dart` routes
these tables through Drift's generated `toJson()`/`fromJson()`, so
regenerating `database.g.dart` is what puts the columns on the wire.
`SyncService._overlayOntoLocal` (`sync_service.dart:2346`) merges a remote row
over the local one as `{...local, ...remote}` precisely so a column an older
peer omits keeps its local value instead of being nulled. In the other
direction, `fromJson` ignores unknown keys, so an older build drops the new
columns harmlessly.

### 4. Excel maintenance log

A new `lib/core/services/export/excel/maintenance_excel_export_service.dart`
following `pre_dive_excel_export_service.dart` exactly, including its
four-method split:

```dart
void buildSheet(xl.Excel excel, {required rows, required dateFormat});
List<int> generateBytes({...});
Future<String> exportToExcel({...});   // share
Future<String?> saveToFile({...});     // save; null means cancelled
```

That split is what lets one builder serve both entry points and also ride the
whole-library workbook, which is what the pre-dive service does today.

Sheet "Maintenance Log", one row per service record:

| Equipment | Equipment Type | Task | Category | Date | Provider | Cost | Currency | Next Due | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |

Headers stay English, matching the documented convention that the workbook is
an analysis target rather than a UI surface. "Task" is the resolved
`ServiceKind` name, blank when untagged; "Category" is the `ServiceType`.

Entry points:

- **Item level**: an action in the history section header, going through
  `showExportDestinationSheet` for the share/save pair, exporting the
  currently filtered rows.
- **Global**: a "Maintenance Log" tile in the transfer page multi-format card
  (`transfer_page.dart:361-378`), backed by `exportMaintenanceLog()` and
  `saveMaintenanceLogToFile()` in `export_providers.dart`.
- **Whole-library workbook**: the sheet is added to
  `ExcelExportService.generateExcelBytes` (`excel_export_service.dart:66`),
  next to the existing Equipment sheet.

`saveAndShareFileBytes` stays share-only and must not become platform aware;
the save path goes through `FilePicker.saveFile` and treats null as
cancellation, not success.

### 5. File extraction

The history region moves out of `equipment_detail_page.dart`:

- `lib/features/equipment/presentation/widgets/service_history_section.dart`
  (section, filter bar, row)
- `lib/features/equipment/presentation/widgets/service_record_dialog.dart`
  (the dialog, already a public class)

This drops the page to roughly 830 lines and gives the new filter and export
code a focused home. `ServiceRecordDialog` is public and referenced by
`test/features/equipment/presentation/pages/service_record_dialog_kind_test.dart`,
so imports must be updated there.

## Localization

New keys, all eleven locales in `lib/l10n/arb/`:

- Ten service type labels: `equipment_serviceType_annual` through
  `equipment_serviceType_other`
- Filter: task/type/year labels, "all", "untagged", cleared summary, and the
  no-matches empty state
- Default price: labels for the kind and schedule editors, and the schedule
  inherit hint
- Export: the history menu item, the transfer tile title and subtitle, and the
  export progress and saved messages

## Testing

| Area | Test |
| --- | --- |
| Migration | `test/core/database/migration_v157_service_cost_test.dart`, on the four-test `migration_v153_o2_cell_mv_test.dart` template: columns added preserving rows, ladder membership, idempotency when a column already exists, no-op when the table is absent |
| Entities | `copyWith` clears `defaultCost`/`defaultCurrency` to null via the `_undefined` sentinel |
| Sync | new keys round-trip in `test/core/services/sync/service_ledger_sync_test.dart` |
| Seed | `service_ledger_schema_test.dart` gains an assertion that built-in kinds have null `defaultCost` |
| Row content | the row titles with the kind name, falls back to the localized type when untagged, and renders notes and next due |
| Row layout | the #935 regression assertion below |
| Localization | each `ServiceType` renders its localized label, not `displayName` |
| Filter | each dimension narrows; combined filters intersect; no-match empty state differs from no-records |
| Prefill | schedule beats kind; kind used when schedule is null; blank when neither; edit never prefills; a user-cleared field stays cleared |
| Locale input | a comma-decimal locale round-trips the default cost |
| Export | sheet headers and row mapping, on the `pre_dive_excel_export_service_test.dart` template; item-level export honors the active filter |

The layout regression must assert rendered width, not presence.
`find.text(...)` with `findsOneWidget` passes happily while text renders one
glyph per line, which is how #935 reached users:

```dart
await tester.binding.setSurfaceSize(const Size(360, 800));
addTearDown(() => tester.binding.setSurfaceSize(null));
// pump with locale: const Locale('de') and a long kind name
expect(tester.getSize(find.text(longKindName)).width, greaterThan(150));
```

## Sequencing

One PR, four ordered commits:

1. Extract the history section and dialog into their own files; localize
   `ServiceType`; retitle the row with the kind name; move cost out of
   `trailing`; render notes and next due.
2. Add the filter.
3. Add `defaultCost`/`defaultCurrency`, migration v157, entity and repository
   plumbing, editor fields, and the prefill chain.
4. Add the Excel maintenance log and its entry points.

Commit 1 alone closes the literal complaint in the issue title, so it is
worth keeping self-contained and reviewable on its own.

## Deferred work

**RESOLVED UPSTREAM (2026-08-18).** Issue #1144 was fixed on main before this
branch merged: `sync_repository.dart` now registers `serviceKinds` and
`serviceSchedules` in `_hlcTargets`, and `_hlcBackfillTargets` stamps the
existing NULL-hlc rows (custom kinds filtered on `is_built_in = 0`, since
built-ins are reference data the export skips anyway). A default price set on
a task or interval therefore reaches a second device on the next incremental
sync, and the caveat below no longer applies to this work. The original
analysis is kept for the record.

**Incremental sync does not carry custom kinds or schedules.** Neither
`serviceKinds` nor `serviceSchedules` appears in
`SyncRepository._hlcTargets` (`sync_repository.dart:31-88`), so
`_stampHlc` returns early on every write and their `hlc` column stays NULL.
The incremental export filters `hlc > since`, and SQL `NULL > x` is false, so
these rows are excluded from every changeset. They still reach peers on a full
base republish, which is why the gap looks like working sync in manual
testing.

This is pre-existing and shared with `cylinderConfigs`,
`cylinderConfigItems`, and `equipmentSetGeofences`, and it carries a real
design choice per table (own clock versus clockless child riding the parent).
It is filed as its own issue covering all five tables rather than fixed
partially here. Consequence for this work: a default price set on a task or
interval will not reach a second device until a full base export runs. The PR
body must say so.

A fix there needs a one-time NULL-hlc backfill as well, mirroring
`backfillMediaEnrichmentHlc` (`sync_repository.dart:486`), or existing custom
kinds stay invisible until they happen to be edited. Note that a serializer
test seeding via `upsertRecord` cannot catch this class of bug, because the
remote apply path carries the peer's HLC in the payload; the test must write
through the repository and assert `SELECT hlc` is non-null.

## Risks

- **Schema number collision** with PR #1127. Mitigated by checking
  `currentSchemaVersion` on current `origin/main` immediately before writing
  the migration, and renumbering if it moved.
- **Extraction churn.** Moving roughly 770 lines makes commit 1's diff look
  larger than its behavior change. Keeping the move and the behavior change in
  one commit is deliberate, since splitting them would produce a commit that
  moves code nobody has reviewed in place yet.
- **Eleven locales.** New user-visible strings must be translated in every
  ARB file, not just English, or the German reporter sees English fallbacks in
  the very feature he reported.
