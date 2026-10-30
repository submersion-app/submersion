# Dive center gear places Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans
> to implement this plan task-by-task, inline in this session. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Dive center place type that can link to a saved dive center, and
show the diver's gear left there on the center's page.

**Architecture:** A new `EquipmentLocationKind.diveCenter` and a nullable
`equipment_locations.dive_center_id` column. The edit dialog sets the link, the
center page and place page read it, and every center delete path clears it and
queues the place for sync.

**Tech Stack:** Flutter, Riverpod, Drift, ARB localization.

**Spec:** `docs/design/specs/2026-10-30-dive-center-gear-places-design.md`

## Global Constraints

- Schema v328, renumbered if another PR ships that version first.
- Never add a table or rung to `database.dart`; rungs go in
  `migrations/ladder/rungs_v231_onward.dart`.
- Strings go in all 11 ARB files, translated, keyed next to a neighbouring key of
  the same group. Regenerate with `flutter gen-l10n`.
- No em dashes anywhere. No mention of any AI tool in commits or PR text.
- `dart format .`, `flutter analyze` and the affected tests before each commit;
  `test/architecture/` and `test/shared/` after adding files under `lib/`.
- Paths in tests are built with `p.join`, never a literal `/`.

## Review Focus

1. Editing a linked place on a device where its center is not in the current
   diver's list, or has not synced yet: saving must keep the link, not clear it.
   Pinned in Task 5.
2. Retired, sold or wishlist gear whose last move is to a linked place: it must
   not appear on the center page. Pinned in Task 6.
3. Gear at an archived linked place: it must still appear on the center page.
   Pinned in Task 6.
4. Archiving, or renaming with an unchanged type, must leave the link alone.
   Pinned in Task 2.
5. A batch from an older build mixed with records from a current build: each
   record decides by its own keys, so one older record does not unlink the
   others. Pinned in Task 3.

---

### Task 1: Dive center kind and status offer

**Files:**
- Modify: `lib/features/equipment/domain/entities/equipment_location.dart`
- Modify: `lib/features/equipment/presentation/utils/equipment_location_display.dart`
- Modify: `lib/features/equipment/domain/services/location_status_offer.dart`
- Modify: `lib/l10n/arb/app_*.arb` (11 files)
- Test: `test/features/equipment/domain/entities/equipment_location_test.dart`
- Test: `test/features/equipment/domain/services/location_status_offer_test.dart`
- Test: `test/features/equipment/domain/services/equipment_location_arranger_test.dart`

**Interfaces:**
- Produces: `EquipmentLocationKind.diveCenter`, declared right after `storage`.
- Produces these ARB keys, all in `equipment_location_*` or `diveCenters_*`
  groups, used by later tasks:
  `equipment_location_kind_diveCenter` ("Dive center"),
  `equipment_locations_savedCenterLabel` ("Saved dive center"),
  `equipment_locations_savedCenterNone` ("None"),
  `equipment_locations_savedCenterClear` ("Remove saved dive center"),
  `diveCenters_gearHere_title` ("Your gear here").

- [ ] **Step 1: Write the failing tests**

```dart
test('diveCenter comes right after storage', () {
  expect(EquipmentLocationKind.values.take(2), [
    EquipmentLocationKind.storage,
    EquipmentLocationKind.diveCenter,
  ]);
});
```

In `location_status_offer_test.dart`, a group for `diveCenter`: `active`, `spare`
and `needsService` give null; `inService`, `loaned` and `lost` give `active`;
`retired`, `sold` and `wanted` give null.

In `equipment_location_arranger_test.dart`, add a dive center place and assert
headings run Storage, Dive center, Service shop.

- [ ] **Step 2: Run to confirm they fail**

Run: `flutter test test/features/equipment/domain`
Expected: FAIL, `diveCenter` is not defined.

- [ ] **Step 3: Add the kind**

Add `diveCenter` to the enum after `storage`. Add its `localizedName` and
`Icons.store_outlined` arms to `equipment_location_display.dart`. In
`offeredStatusAfterMove`, add `case EquipmentLocationKind.diveCenter:` above the
storage case so both share it, and widen the comment: gear back at either place
is no longer away. Update the kind list comment in
`tables/equipment_location_tables.dart` and the doc comment on the enum.

- [ ] **Step 4: Add the strings**

Add the five keys, with `@` descriptions in `app_en.arb`, to all 11 ARB files.
Translate each. Run `flutter gen-l10n`.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/equipment/domain`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/equipment lib/core/database/tables/equipment_location_tables.dart lib/l10n test/features/equipment/domain
git commit -m "feat(equipment): add a Dive center place type"
```

### Task 2: Link column, entity and repository

**Files:**
- Modify: `lib/core/database/tables/equipment_location_tables.dart`
- Modify: `lib/core/database/migrations/helpers/equipment_location_migrations.dart`
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart`
- Modify: `lib/core/database/migrations/before_open_child_columns.dart`
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion` only)
- Modify: `lib/features/equipment/domain/entities/equipment_location.dart`
- Modify: `lib/features/equipment/data/repositories/equipment_location_repository.dart`
- Test: `test/core/database/migration_v328_equipment_location_center_test.dart`
- Test: `test/features/equipment/data/repositories/equipment_location_repository_test.dart`
- Test: `test/features/equipment/domain/entities/equipment_location_test.dart`

**Interfaces:**
- Produces: `EquipmentLocation.diveCenterId` (`String?`), and
  `copyWith({..., String? diveCenterId, bool clearDiveCenterId = false})`.
- Produces: `createLocation({..., String? diveCenterId})`. `updateLocation` writes
  `location.diveCenterId`.

- [ ] **Step 1: Write the failing tests**

Migration test, following `migration_v325_trip_parent_test.dart`: a v327 database
with a Service shop place gains a null `dive_center_id`, keeps `kind`, and running
the assert twice changes nothing. Assert the foreign key with
`PRAGMA foreign_key_list('equipment_locations')`: table `dive_centers`,
`on_delete` `SET NULL`.

Repository tests:

```dart
test('createLocation stores the link', ...);
test('updateLocation can set and clear the link', ...);
test('setArchived keeps the link', ...);
test('renaming keeps the link', ...);
test('deleting the center row sets the link to null, place stays', ...);
```

Entity test: `copyWith(clearDiveCenterId: true)` gives null, plain `copyWith()`
keeps the value, and two places differing only in link are not equal.

- [ ] **Step 2: Run to confirm they fail**

Run: `flutter test test/core/database/migration_v328_equipment_location_center_test.dart test/features/equipment/data/repositories/equipment_location_repository_test.dart`
Expected: FAIL.

- [ ] **Step 3: Add the column**

```dart
/// The saved center a Dive center place stands for (v328, issue #3623).
/// Optional. SET NULL so deleting a center leaves the place; the delete
/// paths also clear this by hand, because a SET NULL reaches no peer.
TextColumn get diveCenterId => text().nullable().references(
  DiveCenters,
  #id,
  onDelete: KeyAction.setNull,
)();
```

Add `_assertEquipmentLocationCenterColumn()` to the migrations extension using
`_addColumnIfMissing('equipment_locations', 'dive_center_id',
'TEXT REFERENCES dive_centers(id) ON DELETE SET NULL')`, returning early when the
table is absent if `_addColumnIfMissing` does not already. Add `dive_centers` to
the parent list in `_assertEquipmentLocationSchema`, since the table now has that
foreign key. Add the v328 rung with a comment, the `reportProgress` line, the
`beforeOpen` assert in `before_open_child_columns.dart`, and bump
`currentSchemaVersion`. Run build_runner.

- [ ] **Step 4: Add it to the entity and repository**

Add the field, `copyWith` and `props`. `_toDomain` reads it. `createLocation` and
`updateLocation` write it.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/core/database test/features/equipment`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/database lib/features/equipment test/core/database/migration_v328_equipment_location_center_test.dart test/features/equipment
git commit -m "feat(equipment): link a place to a saved dive center"
```

### Task 3: Sync the link

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart:5667,7253`
- Modify: `lib/core/services/sync/sync_service.dart` (parent refs, near line 3431)
- Modify: `lib/features/settings/presentation/conflicts/catalogue/equipment_fields.dart` (only if a guard requires it)
- Test: `test/core/services/sync/equipment_location_sync_test.dart`

**Interfaces:**
- Consumes: `EquipmentLocationsCompanion.diveCenterId` from Task 2.

- [ ] **Step 1: Write the failing tests**

In `equipment_location_sync_test.dart`, seed a center and a linked place, then:

```dart
test('upsertRecord applies a new link', ...);
test('upsertRecord applies a null link as an unlink', ...);
test('upsertRecord with no diveCenterId key keeps the local link', ...);
test('a record with no key on a new place inserts with no link', ...);
test('batch: an older record keeps its link, a current record in the same batch applies its own', ...);
test('a place naming a center that is gone arrives with the link cleared', ...);
```

Find the batch entry point from `sync_data_serializer_batch_coverage_test.dart`.

- [ ] **Step 2: Run to confirm they fail**

Run: `flutter test test/core/services/sync/equipment_location_sync_test.dart`
Expected: the no-key tests FAIL, showing the link overwritten with null.

- [ ] **Step 3: Implement the companion helper**

> Dropped during the build. `_withLocalForOmitted` (#2553) already keeps the local
> value for an omitted key on both upsert paths, so only the parent reference
> below was needed. The tests above pin the behaviour.

```dart
/// An incoming place as a companion. A build before v328 sends no
/// `diveCenterId` key at all, which must not read as an unlink: an absent
/// value leaves the local column alone, a null one clears it.
EquipmentLocationsCompanion _equipmentLocationCompanion(
  Map<String, dynamic> data,
) {
  final companion = EquipmentLocationRow.fromJson(
    _withTimestampDefaults(data),
  ).toCompanion(false);
  return data.containsKey('diveCenterId')
      ? companion
      : companion.copyWith(diveCenterId: const Value.absent());
}
```

Use it at both apply sites. Add to the parent refs:

```dart
// v328: the saved center behind a Dive center place. Cleared, not skipped:
// the place outlives its center.
'equipmentLocations': [
  (field: 'diveCenterId', parent: 'diveCenters', nullable: true),
],
```

- [ ] **Step 4: Run the sync guards**

Run: `flutter test test/core/services/sync test/features/settings/presentation`
Expected: PASS. If a catalogue guard names `equipmentLocations.diveCenterId`, add
the field to `equipmentOverrides` with a reference kind, as other center links do.

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/sync lib/features/settings test/core/services/sync
git commit -m "feat(sync): carry a place's saved dive center between devices"
```

### Task 4: Unlink when a center is deleted

**Files:**
- Create: `lib/features/equipment/data/repositories/equipment_location_center_links.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_parent_links.dart`
- Modify: `lib/features/divers/data/repositories/diver_repository.dart:924`
- Test: `test/features/dive_centers/data/repositories/dive_center_repository_reference_links_test.dart`
- Test: `test/features/divers/data/repositories/diver_location_retirement_test.dart`

**Interfaces:**
- Produces:

```dart
Future<void> clearEquipmentLocationCenterLinks(
  AppDatabase db,
  SyncRepository syncRepository,
  List<String> centerIds, {
  required int now,
});
```

- [ ] **Step 1: Write the failing tests**

```dart
test('deleting a center keeps its place, clears the link, marks it pending', ...);
test('the place keeps its name, kind, notes and moves', ...);
test('a place at another center is untouched', ...);
test('diver deletion clears the link on a place that survives its diver', ...);
```

The last one follows the fixture in `diver_location_retirement_test.dart`: gear of
a surviving diver has a move to a place of the deleted diver, linked to the
deleted diver's center. Assert on the pending sync record with `updatedAt` stamped.

- [ ] **Step 2: Run to confirm they fail**

Run: `flutter test test/features/dive_centers/data/repositories/dive_center_repository_reference_links_test.dart test/features/divers/data/repositories/diver_location_retirement_test.dart`
Expected: FAIL, the place is not marked pending.

- [ ] **Step 3: Implement the helper**

Follow `clearTripCylinderEventCenterLinks` in `trip_cylinder_links.dart`: select the
ids, `UPDATE equipment_locations SET dive_center_id = NULL, updated_at = ?`, mark
each `equipmentLocations` record pending. Return early on empty input.

Call it from `clearDiveCenterLinks`, and from `diver_repository.dart` beside the
existing `clearTripCylinderEventCenterLinks` call, before
`retireDiverEquipmentLocations`. Share the center id list there.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/dive_centers test/features/divers`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/equipment/data/repositories/equipment_location_center_links.dart lib/features/dive_log/data/repositories/dive_parent_links.dart lib/features/divers/data/repositories/diver_repository.dart test/features/dive_centers test/features/divers
git commit -m "feat(equipment): keep a place when its dive center is deleted"
```

### Task 5: Saved dive center in the place dialog

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/equipment_location_edit_dialog.dart`
- Modify: `lib/features/dive_centers/presentation/widgets/dive_center_picker.dart`
- Test: `test/features/equipment/presentation/widgets/equipment_location_edit_dialog_test.dart` (create)
- Test: `test/features/dive_centers/presentation/widgets/dive_center_picker_test.dart`

**Interfaces:**
- Consumes: `createLocation(diveCenterId:)`, `copyWith(clearDiveCenterId:)`,
  `diveCenterByIdProvider`, `allDiveCentersProvider`.
- Produces: `DiveCenterPickerSheet.onCreateNewCenter` becomes `VoidCallback?`;
  null hides both add buttons.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('the center field shows only for Dive center', ...);
testWidgets('picking a center fills a blank name', ...);
testWidgets('picking a center leaves a typed name alone', ...);
testWidgets('saving with no center works', ...);
testWidgets('changing the type away clears the link on save', ...);
testWidgets('the clear button removes the link', ...);
testWidgets('a link to a center not in the list is kept on save', ...);
```

The last test is Review Focus 1: `diveCenterByIdProvider` returns null for the id,
the diver edits only the notes, and `updateLocation` receives the same
`diveCenterId`. In `dive_center_picker_test.dart`: a null callback shows no add
buttons, in both the list and the empty state.

- [ ] **Step 2: Run to confirm they fail**

Run: `flutter test test/features/equipment/presentation/widgets/equipment_location_edit_dialog_test.dart test/features/dive_centers/presentation/widgets/dive_center_picker_test.dart`
Expected: FAIL.

- [ ] **Step 3: Make the create callback optional**

`final VoidCallback? onCreateNewCenter;`, no longer `required`. Wrap both add
buttons in `if (onCreateNewCenter != null)`.

- [ ] **Step 4: Add the field to the dialog**

State: `String? _centerId`, seeded from `widget.existing?.diveCenterId`. Under the
kind dropdown, when `_kind == EquipmentLocationKind.diveCenter`, an `InkWell` over
an `InputDecorator` labelled `equipment_locations_savedCenterLabel`, key
`equipment_location_center`, showing the name from
`diveCenterByIdProvider(_centerId)` or `equipment_locations_savedCenterNone`, with
a suffix clear `IconButton` (key `equipment_location_center_clear`, tooltip
`equipment_locations_savedCenterClear`) when `_centerId` is set.

Tapping opens `DiveCenterPickerSheet` the way `trip_cylinder_fill_sheet.dart` does,
with `onCreateNewCenter` omitted. On select: set `_centerId`, and when
`_name.text.trim()` is empty, set the name to the center's.

On save, the link is `_kind == EquipmentLocationKind.diveCenter ? _centerId : null`.
For an existing place, use `copyWith(diveCenterId: link, clearDiveCenterId: link == null)`.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/equipment/presentation test/features/dive_centers/presentation test/features/trips`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/equipment/presentation/widgets/equipment_location_edit_dialog.dart lib/features/dive_centers/presentation/widgets/dive_center_picker.dart test/features/equipment/presentation/widgets/equipment_location_edit_dialog_test.dart test/features/dive_centers/presentation/widgets/dive_center_picker_test.dart
git commit -m "feat(equipment): choose a saved dive center for a place"
```

### Task 6: Your gear here on the center page

**Files:**
- Create: `lib/features/equipment/domain/services/gear_at_dive_center.dart`
- Create: `lib/features/dive_centers/presentation/widgets/gear_here_section.dart`
- Modify: `lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart`
- Test: `test/features/equipment/domain/services/gear_at_dive_center_test.dart`
- Test: `test/features/dive_centers/presentation/widgets/gear_here_section_test.dart`

**Interfaces:**
- Produces:

```dart
typedef GearAtCenter = ({EquipmentItem item, EquipmentLocation place});

/// [items] whose current place links to [centerId], by item name.
List<GearAtCenter> gearAtDiveCenter(
  String centerId,
  List<EquipmentItem> items,
  Map<String, EquipmentLocation> currentPlaces,
);
```

- Produces: `GearHereSection({required String centerId})`, a `ConsumerWidget`
  that returns `SizedBox.shrink()` when empty and otherwise includes its own
  leading `Divider(height: 32)`, so the page's layout has no stray rule.

- [ ] **Step 1: Write the failing tests**

Pure tests:

```dart
test('lists items whose current place links to the center, by name', ...);
test('leaves out items at unlinked places and other centers', ...);
test('includes items at an archived place', ...);
```

Widget tests:

```dart
testWidgets('builds nothing when no gear is there', ...);
testWidgets('leaves out retired, sold and wishlist gear', ...);
testWidgets('shows the place name only when several places link to the center', ...);
testWidgets('tapping a row opens the item', ...);
```

- [ ] **Step 2: Run to confirm they fail**

Run: `flutter test test/features/equipment/domain/services/gear_at_dive_center_test.dart test/features/dive_centers/presentation/widgets/gear_here_section_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`gearAtDiveCenter` sorts with `sortedByText`. The section reads items from
`itemsAtPlaces(ref)`, which already drops retired, sold and wanted gear, and
`currentEquipmentLocationsProvider`. "Several places" is the count of places in
`allEquipmentLocationsByIdProvider` with this `diveCenterId`, more than one. Rows
are `ListTile`s, key `dive_center_gear_${item.id}`, title the item name, subtitle
`item.type.localizedName(l10n)` plus ` · ${place.name}` when several, trailing a
chevron, and `context.push('/equipment/${item.id}')`. Title style and gutter match
`RentalGearSection`.

Put `GearHereSection(centerId: widget.centerId)` above the divider before
`RentalGearSection` in the page.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/dive_centers test/features/equipment/domain`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/equipment/domain/services/gear_at_dive_center.dart lib/features/dive_centers/presentation test/features/equipment/domain/services/gear_at_dive_center_test.dart test/features/dive_centers/presentation/widgets/gear_here_section_test.dart
git commit -m "feat(dive-centers): show the diver's gear on a center's page"
```

### Task 7: Saved center row on the place page, and docs

**Files:**
- Modify: `lib/features/equipment/presentation/pages/equipment_location_detail_page.dart`
- Modify: `docs/user/equipment.md`
- Test: `test/features/equipment/presentation/pages/equipment_location_detail_page_test.dart`

**Interfaces:**
- Consumes: `EquipmentLocation.diveCenterId`, `diveCenterByIdProvider`,
  `equipment_locations_savedCenterLabel`.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('a linked place shows its center and opens it', ...);
testWidgets('an unlinked place shows no row', ...);
testWidgets('a center missing on this device shows no row', ...);
```

- [ ] **Step 2: Run to confirm they fail**

Run: `flutter test test/features/equipment/presentation/pages/equipment_location_detail_page_test.dart`
Expected: FAIL.

- [ ] **Step 3: Add the row and the docs**

Under the kind `ListTile`, when `diveCenterByIdProvider(place.diveCenterId)` has a
value: a `ListTile`, key `equipment_location_center_row`, leading `Icons.link`,
title the label, subtitle the center's name, chevron,
`context.push('/dive-centers/${center.id}')`.

In `docs/user/equipment.md`, Locations: add dive centers to the first sentence, say
a place can link to a saved center, and that the center's page lists gear there.
Note that moving gear to a dive center offers **Active** the same way storage does.

- [ ] **Step 4: Run everything affected**

```bash
dart format .
flutter analyze
flutter test test/architecture test/shared test/features/equipment test/features/dive_centers test/features/divers test/core/services/sync test/core/database
```

Expected: no analyzer issues, all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/equipment/presentation/pages/equipment_location_detail_page.dart docs/user/equipment.md test/features/equipment/presentation/pages/equipment_location_detail_page_test.dart
git commit -m "feat(equipment): open a place's saved dive center"
```
