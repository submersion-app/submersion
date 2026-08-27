# Highlight Last-Visited Item in Phone-Mode Lists — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the existing `highlighted<X>IdProvider` StateProviders into the phone-mode card lists for 8 entity types so users can see which item they just visited after returning from detail.

**Architecture:** Per-feature, the list-content widget's phone-mode `ListView.builder` adds one `ref.watch(highlighted<X>IdProvider)` read and ORs the match into the tile's `isSelected` prop. For 7 of the 8 features, the phone-mode `_handleItemTap` also needs one line added to write to the provider on tap (Dives already does this).

**Tech Stack:** Flutter, Riverpod, go_router, Drift (unused here), existing `EntityTableConfig` / `testApp` / `MockSettingsNotifier` test helpers.

**Spec:** See [2026-04-14-list-highlight-last-visited-design.md](../specs/2026-04-14-list-highlight-last-visited-design.md).

---

## Task Order

Eight per-feature tasks, each a single commit. Dives is first because its tap handler is already wired, so it is the smallest patch and a good template.

1. Dives
2. Trips
3. Sites
4. Buddies
5. Equipment
6. Dive Centers
7. Certifications
8. Courses
9. Manual smoke test + push

Each feature task follows the same 5-step shape: write failing test → confirm fails → implement → confirm passes → commit.

---

## Shared Test Pattern

Every feature test uses an existing `testApp` harness plus provider overrides. The test renders the list-content widget with `ListViewMode.detailed`, seeds the feature's `highlighted<X>IdProvider` with an item's id, pumps, and asserts the corresponding tile received `isSelected: true`.

Pattern reference (to be adapted per feature):

```dart
testWidgets('highlights item when highlighted<X>IdProvider is set in phone mode', (tester) async {
  final items = [
    _makeItem(id: 'a', name: 'Alpha'),
    _makeItem(id: 'b', name: 'Bravo'),
  ];

  final overrides = await _buildOverrides(
    items: items,
    viewMode: ListViewMode.detailed,
    highlightedId: 'b',
  );

  await tester.pumpWidget(
    testApp(
      overrides: overrides,
      child: const <X>ListContent(showAppBar: false),
    ),
  );
  await tester.pumpAndSettle();

  final tiles = tester.widgetList<<X>ListTile>(find.byType(<X>ListTile)).toList();
  final alpha = tiles.firstWhere((t) => t.<idAccessor> == 'a');
  final bravo = tiles.firstWhere((t) => t.<idAccessor> == 'b');

  expect(alpha.isSelected, isFalse);
  expect(bravo.isSelected, isTrue);
});
```

Each task specifies the exact `<X>ListTile`, id accessor, and additional provider overrides needed.

---

## Task 1: Dives

**Files:**

- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (lines ~1357, ~1391, ~1435)
- Test: `test/features/dive_log/presentation/widgets/dive_list_content_test.dart`

Dives already writes to `highlightedDiveIdProvider` in `_handleItemTap` at line 808. Only the read side is missing.

- [ ] **Step 1: Write failing test**

Add this test to `test/features/dive_log/presentation/widgets/dive_list_content_test.dart` (inside an existing `group` or a new `group('phone-mode highlight', ...)`). Reuse the file's existing `_buildOverrides` helper, extending it to accept a `highlightedId` parameter and a `viewMode` defaulting to `ListViewMode.detailed`. If the helper does not yet support that, add a new helper `_buildPhoneOverrides` in the same file — do not touch the existing table-mode helpers.

```dart
testWidgets('phone detailed view highlights dive when highlightedDiveIdProvider is set', (tester) async {
  final dives = [
    _makeDive(id: 'd1', diveNumber: 1, siteName: 'Site One'),
    _makeDive(id: 'd2', diveNumber: 2, siteName: 'Site Two'),
  ];

  final overrides = await _buildPhoneOverrides(
    dives: dives,
    viewMode: ListViewMode.detailed,
    highlightedDiveId: 'd2',
  );

  await tester.pumpWidget(
    testApp(
      overrides: overrides,
      child: const DiveListContent(showAppBar: false),
    ),
  );
  await tester.pumpAndSettle();

  final tiles = tester.widgetList<DiveListTile>(find.byType(DiveListTile)).toList();
  final tileOne = tiles.firstWhere((t) => t.diveId == 'd1');
  final tileTwo = tiles.firstWhere((t) => t.diveId == 'd2');

  expect(tileOne.isSelected, isFalse);
  expect(tileTwo.isSelected, isTrue);
});
```

`_makeDive` is the existing helper in the file. If `_buildPhoneOverrides` needs to be created, model it on the existing table-mode `_buildOverrides` but with `diveListViewModeProvider.overrideWith((ref) => viewMode)` and `highlightedDiveIdProvider.overrideWith((ref) => highlightedDiveId)`.

- [ ] **Step 2: Run test and confirm it fails**

```bash
flutter test test/features/dive_log/presentation/widgets/dive_list_content_test.dart --name "phone detailed view highlights dive"
```

Expected: test fails with `Expected: true, Actual: false` on the final expectation — the tile's `isSelected` is false because the phone-mode builder doesn't observe `highlightedDiveIdProvider` yet.

- [ ] **Step 3: Implement**

In `lib/features/dive_log/presentation/widgets/dive_list_content.dart`, inside `_buildDiveList` (the phone-mode branch, around line 1293), add the provider watch once at the top of the `ListView.builder`'s `itemBuilder`, then OR it into each tile's `isSelected`:

Before (line 1357–1358):

```dart
final isSelected = _selectedIds.contains(dive.id);
final isMasterSelected = widget.selectedId == dive.id;
```

After:

```dart
final isSelected = _selectedIds.contains(dive.id);
final isMasterSelected = widget.selectedId == dive.id;
final isHighlighted = ref.watch(highlightedDiveIdProvider) == dive.id;
```

Update the three tile `isSelected:` expressions (lines 1374–1376, 1399–1401, 1448–1450):

```dart
isSelected: _isSelectionMode
    ? isSelected
    : (isSelected || isMasterSelected || isHighlighted),
```

Apply the change identically to the `ListViewMode.detailed`, `ListViewMode.compact`, and `ListViewMode.dense || ListViewMode.table` branches so all three tile types observe the highlight.

Note: watching the provider inside `itemBuilder` is correct here — Flutter re-runs the builder on provider change, and this matches how `diveListViewModeProvider` is already watched in the same closure (line 1359).

- [ ] **Step 4: Run test and confirm it passes**

```bash
flutter test test/features/dive_log/presentation/widgets/dive_list_content_test.dart
```

Expected: all tests in the file pass, including the new one.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_list_content.dart test/features/dive_log/presentation/widgets/dive_list_content_test.dart
git commit -m "feat(dives): highlight last-visited dive on phone-mode list return"
```

---

## Task 2: Trips

**Files:**

- Modify: `lib/features/trips/presentation/widgets/trip_list_content.dart` (lines 106–113 and ~407)
- Test: `test/features/trips/presentation/widgets/trip_list_content_test.dart`

Trips has no bulk-selection mode, making it the simplest "full-pattern" feature (both write and read sides).

- [ ] **Step 1: Write failing test**

Add to `test/features/trips/presentation/widgets/trip_list_content_test.dart`. Extend the existing `_buildOverrides` helper or add `_buildPhoneOverrides` that takes `viewMode` and `highlightedId`. Include `highlightedTripIdProvider.overrideWith((ref) => highlightedId)` in the returned list.

```dart
testWidgets('phone detailed view highlights trip when highlightedTripIdProvider is set', (tester) async {
  final trips = [
    _makeTrip(id: 't1', name: 'Alpha Trip'),
    _makeTrip(id: 't2', name: 'Bravo Trip'),
  ];

  final overrides = await _buildPhoneOverrides(
    trips: trips,
    viewMode: ListViewMode.detailed,
    highlightedTripId: 't2',
  );

  await tester.pumpWidget(
    testApp(
      overrides: overrides,
      child: const TripListContent(showAppBar: false),
    ),
  );
  await tester.pumpAndSettle();

  final tiles = tester.widgetList<TripListTile>(find.byType(TripListTile)).toList();
  final alpha = tiles.firstWhere((t) => t.tripWithStats.trip.id == 't1');
  final bravo = tiles.firstWhere((t) => t.tripWithStats.trip.id == 't2');

  expect(alpha.isSelected, isFalse);
  expect(bravo.isSelected, isTrue);
});
```

- [ ] **Step 2: Run test and confirm it fails**

```bash
flutter test test/features/trips/presentation/widgets/trip_list_content_test.dart --name "phone detailed view highlights trip"
```

Expected: final expectation fails with `Expected: true, Actual: false`.

- [ ] **Step 3: Implement**

In `lib/features/trips/presentation/widgets/trip_list_content.dart`:

**Write side** — patch `_handleItemTap` (lines 106–113):

```dart
void _handleItemTap(Trip trip) {
  ref.read(highlightedTripIdProvider.notifier).state = trip.id;
  if (widget.onItemSelected != null) {
    _selectionFromList = true;
    widget.onItemSelected!(trip.id);
  } else {
    context.push('/trips/${trip.id}');
  }
}
```

**Read side** — patch the phone-mode `ListView.builder` around line 407:

Before:

```dart
final tripWithStats = trips[index];
final isSelected = widget.selectedId == tripWithStats.trip.id;
```

After:

```dart
final tripWithStats = trips[index];
final isSelected = widget.selectedId == tripWithStats.trip.id
    || ref.watch(highlightedTripIdProvider) == tripWithStats.trip.id;
```

No change to tile invocations — `isSelected: isSelected` already flows.

- [ ] **Step 4: Run test and confirm it passes**

```bash
flutter test test/features/trips/presentation/widgets/trip_list_content_test.dart
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/trips/presentation/widgets/trip_list_content.dart test/features/trips/presentation/widgets/trip_list_content_test.dart
git commit -m "feat(trips): highlight last-visited trip on phone-mode list return"
```

---

## Task 3: Sites

**Files:**

- Modify: `lib/features/dive_sites/presentation/widgets/site_list_content.dart` (lines 136–159 and ~781)
- Test: `test/features/dive_sites/presentation/widgets/site_list_content_test.dart`

Sites has bulk-selection and map modes. The provider write must be skipped in both to match the existing early-return pattern.

- [ ] **Step 1: Write failing test**

Add to `test/features/dive_sites/presentation/widgets/site_list_content_test.dart`. Extend overrides with `highlightedSiteIdProvider.overrideWith((ref) => highlightedId)`.

```dart
testWidgets('phone detailed view highlights site when highlightedSiteIdProvider is set', (tester) async {
  final sites = [
    _makeSite(id: 's1', name: 'Alpha Site'),
    _makeSite(id: 's2', name: 'Bravo Site'),
  ];

  final overrides = await _buildPhoneOverrides(
    sites: sites,
    viewMode: ListViewMode.detailed,
    highlightedSiteId: 's2',
  );

  await tester.pumpWidget(
    testApp(
      overrides: overrides,
      child: const SiteListContent(showAppBar: false),
    ),
  );
  await tester.pumpAndSettle();

  final tiles = tester.widgetList<SiteListTile>(find.byType(SiteListTile)).toList();
  final alpha = tiles.firstWhere((t) => t.site.id == 's1');
  final bravo = tiles.firstWhere((t) => t.site.id == 's2');

  expect(alpha.isSelected, isFalse);
  expect(bravo.isSelected, isTrue);
});
```

- [ ] **Step 2: Run test and confirm it fails**

```bash
flutter test test/features/dive_sites/presentation/widgets/site_list_content_test.dart --name "phone detailed view highlights site"
```

Expected: final expectation fails.

- [ ] **Step 3: Implement**

In `lib/features/dive_sites/presentation/widgets/site_list_content.dart`:

**Write side** — patch `_handleItemTap` (lines 136–159). Add the provider write after the early-return guards but before the navigation branches:

```dart
void _handleItemTap(DiveSite site) {
  if (_isSelectionMode) {
    _toggleSelection(site.id);
    return;
  }

  if (widget.isMapMode && widget.onItemTapForMap != null) {
    if (widget.onItemSelected != null) {
      _selectionFromList = true;
      widget.onItemSelected!(site.id);
    }
    widget.onItemTapForMap!(site);
    return;
  }

  ref.read(highlightedSiteIdProvider.notifier).state = site.id;

  if (widget.onItemSelected != null) {
    _selectionFromList = true;
    widget.onItemSelected!(site.id);
  } else {
    context.push('/sites/${site.id}');
  }
}
```

**Read side** — patch the phone-mode `ListView.builder` around line 781:

Before:

```dart
final isSelected = widget.selectedId == site.id;
```

After:

```dart
final isSelected = widget.selectedId == site.id
    || ref.watch(highlightedSiteIdProvider) == site.id;
```

Leave the `isChecked` variable (bulk-select state) alone — the existing switch on view mode already uses `isChecked` for compact/dense and `isSelected` for detailed; preserving that pattern.

- [ ] **Step 4: Run test and confirm it passes**

```bash
flutter test test/features/dive_sites/presentation/widgets/site_list_content_test.dart
```

Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_sites/presentation/widgets/site_list_content.dart test/features/dive_sites/presentation/widgets/site_list_content_test.dart
git commit -m "feat(sites): highlight last-visited site on phone-mode list return"
```

---

## Task 4: Buddies

**Files:**

- Modify: `lib/features/buddies/presentation/widgets/buddy_list_content.dart` (lines 129–141 and ~757)
- Test: `test/features/buddies/presentation/widgets/buddy_list_content_test.dart` (create if missing)

Buddies has bulk-selection.

- [ ] **Step 1: Write failing test**

Either extend `test/features/buddies/presentation/widgets/buddy_list_content_test.dart` (if present) or model after the Sites test. Test skeleton:

```dart
testWidgets('phone detailed view highlights buddy when highlightedBuddyIdProvider is set', (tester) async {
  final buddies = [
    _makeBuddy(id: 'b1', name: 'Alice'),
    _makeBuddy(id: 'b2', name: 'Bob'),
  ];

  final overrides = await _buildPhoneOverrides(
    buddies: buddies,
    viewMode: ListViewMode.detailed,
    highlightedBuddyId: 'b2',
  );

  await tester.pumpWidget(
    testApp(
      overrides: overrides,
      child: const BuddyListContent(showAppBar: false),
    ),
  );
  await tester.pumpAndSettle();

  final tiles = tester.widgetList<BuddyListTile>(find.byType(BuddyListTile)).toList();
  final alice = tiles.firstWhere((t) => t.buddy.id == 'b1');
  final bob = tiles.firstWhere((t) => t.buddy.id == 'b2');

  expect(alice.isSelected, isFalse);
  expect(bob.isSelected, isTrue);
});
```

If no existing test file: create one modeled exactly on `test/features/trips/presentation/widgets/trip_list_content_test.dart`, adapting mock providers (`buddyListNotifierProvider`, `sortedFilteredBuddiesProvider`, `buddyListViewModeProvider`, `buddyTableConfigProvider`) and builder (`_makeBuddy`). The actual Buddy domain type is `Buddy` (see `lib/features/buddies/domain/entities/buddy.dart`).

- [ ] **Step 2: Run test and confirm it fails**

```bash
flutter test test/features/buddies/presentation/widgets/buddy_list_content_test.dart --name "phone detailed view highlights buddy"
```

- [ ] **Step 3: Implement**

In `lib/features/buddies/presentation/widgets/buddy_list_content.dart`:

**Write side** — patch `_handleItemTap` (lines 129–141):

```dart
void _handleItemTap(Buddy buddy) {
  if (_isSelectionMode) {
    _toggleSelection(buddy.id);
    return;
  }

  ref.read(highlightedBuddyIdProvider.notifier).state = buddy.id;

  if (widget.onItemSelected != null) {
    _selectionFromList = true;
    widget.onItemSelected!(buddy.id);
  } else {
    context.push('/buddies/${buddy.id}');
  }
}
```

**Read side** — patch the phone-mode `ListView.builder` around line 757:

Before:

```dart
final isSelected = widget.selectedId == buddy.id;
```

After:

```dart
final isSelected = widget.selectedId == buddy.id
    || ref.watch(highlightedBuddyIdProvider) == buddy.id;
```

- [ ] **Step 4: Run test and confirm it passes**

```bash
flutter test test/features/buddies/presentation/widgets/buddy_list_content_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/buddies/presentation/widgets/buddy_list_content.dart test/features/buddies/presentation/widgets/buddy_list_content_test.dart
git commit -m "feat(buddies): highlight last-visited buddy on phone-mode list return"
```

---

## Task 5: Equipment

**Files:**

- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (lines 96–101 and ~443)
- Test: `test/features/equipment/presentation/widgets/equipment_list_content_test.dart` (check existence; may need to create)

No bulk selection in the main list.

- [ ] **Step 1: Write failing test**

Model after the Trips test. The tile type is `EquipmentListTile` (see line 542 in the source).

```dart
testWidgets('phone detailed view highlights equipment when highlightedEquipmentIdProvider is set', (tester) async {
  final items = [
    _makeEquipment(id: 'e1', name: 'Alpha Reg'),
    _makeEquipment(id: 'e2', name: 'Bravo BCD'),
  ];

  final overrides = await _buildPhoneOverrides(
    items: items,
    viewMode: ListViewMode.detailed,
    highlightedEquipmentId: 'e2',
  );

  await tester.pumpWidget(
    testApp(
      overrides: overrides,
      child: const EquipmentListContent(showAppBar: false),
    ),
  );
  await tester.pumpAndSettle();

  final tiles = tester.widgetList<EquipmentListTile>(find.byType(EquipmentListTile)).toList();
  final alpha = tiles.firstWhere((t) => t.equipment.id == 'e1');
  final bravo = tiles.firstWhere((t) => t.equipment.id == 'e2');

  expect(alpha.isSelected, isFalse);
  expect(bravo.isSelected, isTrue);
});
```

- [ ] **Step 2: Run test and confirm it fails**

```bash
flutter test test/features/equipment/presentation/widgets/equipment_list_content_test.dart --name "phone detailed view highlights equipment"
```

- [ ] **Step 3: Implement**

In `lib/features/equipment/presentation/widgets/equipment_list_content.dart`:

**Write side** — patch `_handleItemTap` (lines 96–101):

```dart
void _handleItemTap(EquipmentItem equipment) {
  ref.read(highlightedEquipmentIdProvider.notifier).state = equipment.id;
  if (widget.onItemSelected != null) {
    _selectionFromList = true;
    widget.onItemSelected!(equipment.id);
  } else {
    context.push('/equipment/${equipment.id}');
  }
}
```

**Read side** — patch the phone-mode `ListView.builder` around line 443:

Before:

```dart
final isSelected = widget.selectedId == item.id;
```

After:

```dart
final isSelected = widget.selectedId == item.id
    || ref.watch(highlightedEquipmentIdProvider) == item.id;
```

- [ ] **Step 4: Run test and confirm it passes**

```bash
flutter test test/features/equipment/presentation/widgets/equipment_list_content_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/equipment/presentation/widgets/equipment_list_content.dart test/features/equipment/presentation/widgets/equipment_list_content_test.dart
git commit -m "feat(equipment): highlight last-visited equipment on phone-mode list return"
```

---

## Task 6: Dive Centers

**Files:**

- Modify: `lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart` (lines 129–147 and ~443)
- Test: `test/features/dive_centers/presentation/widgets/dive_center_list_content_test.dart`

Dive Centers has a map mode similar to Sites. No bulk selection.

- [ ] **Step 1: Write failing test**

Model after Sites test. Tile type is `DiveCenterListTile` (see line ~443 branch `ListViewMode.detailed`).

```dart
testWidgets('phone detailed view highlights dive center when highlightedDiveCenterIdProvider is set', (tester) async {
  final centers = [
    _makeDiveCenter(id: 'c1', name: 'Alpha Dive'),
    _makeDiveCenter(id: 'c2', name: 'Bravo Dive'),
  ];

  final overrides = await _buildPhoneOverrides(
    centers: centers,
    viewMode: ListViewMode.detailed,
    highlightedDiveCenterId: 'c2',
  );

  await tester.pumpWidget(
    testApp(
      overrides: overrides,
      child: const DiveCenterListContent(showAppBar: false),
    ),
  );
  await tester.pumpAndSettle();

  final tiles = tester.widgetList<DiveCenterListTile>(find.byType(DiveCenterListTile)).toList();
  final alpha = tiles.firstWhere((t) => t.center.id == 'c1');
  final bravo = tiles.firstWhere((t) => t.center.id == 'c2');

  expect(alpha.isSelected, isFalse);
  expect(bravo.isSelected, isTrue);
});
```

- [ ] **Step 2: Run test and confirm it fails**

```bash
flutter test test/features/dive_centers/presentation/widgets/dive_center_list_content_test.dart --name "phone detailed view highlights dive center"
```

- [ ] **Step 3: Implement**

In `lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart`:

**Write side** — patch `_handleItemTap` (lines 129–147):

```dart
void _handleItemTap(DiveCenter center) {
  if (widget.isMapMode && widget.onItemTapForMap != null) {
    if (widget.onItemSelected != null) {
      _selectionFromList = true;
      widget.onItemSelected!(center.id);
    }
    widget.onItemTapForMap!(center);
    return;
  }

  ref.read(highlightedDiveCenterIdProvider.notifier).state = center.id;

  if (widget.onItemSelected != null) {
    _selectionFromList = true;
    widget.onItemSelected!(center.id);
  } else {
    context.push('/dive-centers/${center.id}');
  }
}
```

**Read side** — patch the phone-mode `ListView.builder` around line 443. Find the line that computes `isSelected` from `widget.selectedId` inside the itemBuilder and OR in the provider watch:

Before:

```dart
final isSelected = widget.selectedId == center.id;
```

After:

```dart
final isSelected = widget.selectedId == center.id
    || ref.watch(highlightedDiveCenterIdProvider) == center.id;
```

- [ ] **Step 4: Run test and confirm it passes**

```bash
flutter test test/features/dive_centers/presentation/widgets/dive_center_list_content_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart test/features/dive_centers/presentation/widgets/dive_center_list_content_test.dart
git commit -m "feat(dive-centers): highlight last-visited dive center on phone-mode list return"
```

---

## Task 7: Certifications

**Files:**

- Modify: `lib/features/certifications/presentation/widgets/certification_list_content.dart` (lines 105–109, 377, 391, 405)
- Test: `test/features/certifications/presentation/widgets/certification_list_content_test.dart`

Certifications is structurally different — the phone-mode layout is a `Column` with `.map` over three sections (expired, expiringSoon, valid), not a single `ListView.builder`. Each section constructs `CertificationListTile(... isSelected: widget.selectedId == cert.id ...)`. So the read-side change is applied three times, once per section.

No bulk selection. No map mode.

- [ ] **Step 1: Write failing test**

Create at least one expired (or expiring / valid) certification and assert the tile receives the highlight. Due to the three-section layout, the test also benefits from one assertion per section if setup allows — but a single-section test is sufficient for coverage.

```dart
testWidgets('phone view highlights certification when highlightedCertificationIdProvider is set', (tester) async {
  final certs = [
    _makeCertification(id: 'c1', name: 'Open Water'),
    _makeCertification(id: 'c2', name: 'Rescue Diver'),
  ];

  final overrides = await _buildPhoneOverrides(
    certs: certs,
    viewMode: ListViewMode.detailed,
    highlightedCertificationId: 'c2',
  );

  await tester.pumpWidget(
    testApp(
      overrides: overrides,
      child: const CertificationListContent(showAppBar: false),
    ),
  );
  await tester.pumpAndSettle();

  final tiles = tester.widgetList<CertificationListTile>(find.byType(CertificationListTile)).toList();
  final ow = tiles.firstWhere((t) => t.certification.id == 'c1');
  final rescue = tiles.firstWhere((t) => t.certification.id == 'c2');

  expect(ow.isSelected, isFalse);
  expect(rescue.isSelected, isTrue);
});
```

- [ ] **Step 2: Run test and confirm it fails**

```bash
flutter test test/features/certifications/presentation/widgets/certification_list_content_test.dart --name "phone view highlights certification"
```

- [ ] **Step 3: Implement**

In `lib/features/certifications/presentation/widgets/certification_list_content.dart`:

**Write side** — patch `_handleItemTap` (lines 105–109):

```dart
void _handleItemTap(Certification cert) {
  ref.read(highlightedCertificationIdProvider.notifier).state = cert.id;
  if (widget.onItemSelected != null) {
    _selectionFromList = true;
    widget.onItemSelected!(cert.id);
  } else {
    context.push('/certifications/${cert.id}');
  }
}
```

**Read side** — three identical edits. Above the Column of sections (inside the `build` method where the phone-mode body is constructed), pull the highlighted id into a local once:

```dart
final highlightedId = ref.watch(highlightedCertificationIdProvider);
```

Then replace each of the three `isSelected:` expressions at lines 377, 391, 405:

Before (3 occurrences):

```dart
isSelected: widget.selectedId == cert.id,
```

After (3 occurrences):

```dart
isSelected: widget.selectedId == cert.id || highlightedId == cert.id,
```

- [ ] **Step 4: Run test and confirm it passes**

```bash
flutter test test/features/certifications/presentation/widgets/certification_list_content_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/certifications/presentation/widgets/certification_list_content.dart test/features/certifications/presentation/widgets/certification_list_content_test.dart
git commit -m "feat(certifications): highlight last-visited certification on phone-mode list return"
```

---

## Task 8: Courses

**Files:**

- Modify: `lib/features/courses/presentation/widgets/course_list_content.dart` (lines 49–55 and ~315)
- Test: `test/features/courses/presentation/widgets/course_list_content_test.dart`

No bulk selection. Phone-mode renders `CourseCard` wrapped in `Padding` inside a `ListView.builder`.

- [ ] **Step 1: Write failing test**

```dart
testWidgets('phone view highlights course when highlightedCourseIdProvider is set', (tester) async {
  final courses = [
    _makeCourse(id: 'co1', name: 'Alpha Course'),
    _makeCourse(id: 'co2', name: 'Bravo Course'),
  ];

  final overrides = await _buildPhoneOverrides(
    courses: courses,
    viewMode: ListViewMode.detailed,
    highlightedCourseId: 'co2',
  );

  await tester.pumpWidget(
    testApp(
      overrides: overrides,
      child: const CourseListContent(showAppBar: false),
    ),
  );
  await tester.pumpAndSettle();

  final tiles = tester.widgetList<CourseCard>(find.byType(CourseCard)).toList();
  final alpha = tiles.firstWhere((t) => t.course.id == 'co1');
  final bravo = tiles.firstWhere((t) => t.course.id == 'co2');

  expect(alpha.isSelected, isFalse);
  expect(bravo.isSelected, isTrue);
});
```

- [ ] **Step 2: Run test and confirm it fails**

```bash
flutter test test/features/courses/presentation/widgets/course_list_content_test.dart --name "phone view highlights course"
```

- [ ] **Step 3: Implement**

In `lib/features/courses/presentation/widgets/course_list_content.dart`:

**Write side** — patch `_handleItemTap` (lines 49–55):

```dart
void _handleItemTap(Course course) {
  ref.read(highlightedCourseIdProvider.notifier).state = course.id;
  if (widget.onItemSelected != null) {
    widget.onItemSelected!(course.id);
  } else {
    context.push('/courses/${course.id}');
  }
}
```

**Read side** — patch the phone-mode `ListView.builder` around line 315:

Before:

```dart
child: CourseCard(
  course: course,
  isSelected: widget.selectedId == course.id,
  onTap: () => _handleItemTap(course),
),
```

After:

```dart
child: CourseCard(
  course: course,
  isSelected: widget.selectedId == course.id
      || ref.watch(highlightedCourseIdProvider) == course.id,
  onTap: () => _handleItemTap(course),
),
```

- [ ] **Step 4: Run test and confirm it passes**

```bash
flutter test test/features/courses/presentation/widgets/course_list_content_test.dart
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/courses/presentation/widgets/course_list_content.dart test/features/courses/presentation/widgets/course_list_content_test.dart
git commit -m "feat(courses): highlight last-visited course on phone-mode list return"
```

---

## Task 9: Full Test Suite + Smoke Test + Push

- [ ] **Step 1: Full analyze + tests**

```bash
flutter analyze
flutter test
```

Expected: no analyzer issues; all tests pass (8 new ones, ~6,500 existing).

- [ ] **Step 2: Format check**

```bash
dart format --set-exit-if-changed lib/ test/
```

Expected: no formatting changes required. If any, run `dart format lib/ test/` and re-stage.

- [ ] **Step 3: Manual phone-mode smoke test**

Launch the app on a phone-sized window:

```bash
flutter run -d macos
# Resize the window to a phone-width aspect ratio (narrower than master-detail breakpoint).
```

For each of the 8 features (Dives, Sites, Trips, Equipment, Buddies, Dive Centers, Certifications, Courses):

1. Open the list page in both **detailed** and **compact** view modes (where both exist).
2. Tap an item, navigate into detail, tap back.
3. Verify the previously-tapped card is tinted on return (using `primaryContainer` tint at 0.3 alpha).
4. Tap a different item, go back, verify only the new item is highlighted.
5. For Sites and Buddies: enter bulk-selection mode and confirm the highlight does not interfere with checkbox selection styling.

- [ ] **Step 4: Push**

```bash
git push
```

Expected: pre-push hook runs format / analyze / test, all pass, push succeeds.

---

## Self-Review Notes

- **Spec coverage.** Every per-feature touch point listed in the spec has a corresponding task. The "audit findings" section (7 tap handlers needing writes) is implemented in Tasks 2–8. The Dives-only task covers the "already wires the write" case.
- **Type consistency.** The provider names (`highlighted<X>IdProvider`) and tile class names (`<X>ListTile`, `CourseCard`) were verified by grep prior to writing this plan.
- **Placeholder scan.** All code blocks are complete. No "TBD" / "fill in later". Test setup may require creating a `_buildPhoneOverrides` helper per test file modeled on the existing `_buildOverrides` — this is a mechanical copy of the existing helper with three additions: `ListViewMode` override, `highlighted<X>IdProvider` override, and the feature-specific list/filter provider overrides that already exist in the file.
- **Scope.** Eight features, one shared pattern, one commit each — focused enough for a single plan.
