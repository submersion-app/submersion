# Water Type from Dive Site — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver set water type once on a dive site; when that site is assigned to a dive, the dive's water type auto-fills from it (still manually editable).

**Architecture:** Revive the already-existing-but-dormant `dive_sites.waterType` column (hydrate it into the entity, persist it, expose it in the site editor), then snapshot it onto the dive on site assignment. The dive keeps storing its own `waterType` (snapshot model), so every existing reader — exports, statistics, deco/buoyancy density — is untouched.

**Tech Stack:** Flutter, Drift ORM (SQLite), Riverpod, `flutter_test`. Water type is the existing `WaterType` enum (`salt`/`fresh`/`brackish`) in `lib/core/constants/enums.dart`.

## Global Constraints

- **No schema migration / no schema-version bump.** `dive_sites.waterType` already exists (`database.dart:639`) and already syncs via `toJson()`. Do not add a column or bump the version ladder.
- **Snapshot model.** The dive stores its own `waterType`; the site is only a source of defaults. Never make the dive read through to the site at display time.
- **Canonical column values are `WaterType.name`** (`'salt'`/`'fresh'`/`'brackish'`) — importers already write these; hydration must parse them and yield `null` on an unknown/absent string (never fabricate a default).
- **Localization:** any new UI string is added to all 11 ARB files (`lib/l10n/arb/app_{en,ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`) and regenerated with `flutter gen-l10n`. Generated `app_localizations*.dart` is tracked — commit it.
- **`dart format .` clean and `flutter analyze` clean** before every commit (pre-push hook enforces format + analyze + test).
- **Commit messages:** no `Co-Authored-By` trailer, no session-URL trailer.
- **Worktree paths:** all work happens in `.claude/worktrees/site-water-type-autofill`; use worktree-absolute paths for edits.

---

### Task 0: Worktree setup (codegen)

The fresh worktree has no generated code. `lib/core/database/database.g.dart` is gitignored and absent; nothing compiles or tests until codegen runs.

**Files:** none (setup only).

- [ ] **Step 1: Initialize submodules**

Run: `git submodule update --init --recursive`
Expected: libdivecomputer and other submodules populate (no error).

- [ ] **Step 2: Fetch packages**

Run: `flutter pub get`
Expected: "Got dependencies!" (or "Resolving dependencies…" then success).

- [ ] **Step 3: Run code generation**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: build completes; `lib/core/database/database.g.dart` now exists.

- [ ] **Step 4: Verify the toolchain runs a test**

Run: `flutter test test/features/dive_sites/data/repositories/site_repository_test.dart`
Expected: existing tests PASS (proves DB codegen + harness work).

No commit (generated artifacts are gitignored).

---

### Task 1: Entity + repository — revive `dive_sites.waterType`

**Deliverable:** a site's water type persists and round-trips through the repository (including rows written directly by importers). No UI yet.

**Files:**
- Modify: `lib/features/dive_sites/domain/entities/dive_site.dart`
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart`
- Modify: `lib/features/dive_sites/domain/constants/site_field.dart:459-460`
- Test: `test/features/dive_sites/data/repositories/site_repository_test.dart`
- Test: `test/features/dive_sites/domain/constants/site_field_test.dart` (fix an existing test)

**Interfaces:**
- Produces: `DiveSite.waterType` of type `WaterType?` (new named field on the entity + `copyWith` param). Later tasks read/write it.

- [ ] **Step 1: Write failing repository round-trip tests**

Add these tests inside the `group('SiteRepository', () {` block in `site_repository_test.dart` (after the `bodyOfWater` round-trip test near line 71). `WaterType` and `Value` are already imported in this file.

```dart
    test('create then read round-trips waterType', () async {
      const site = DiveSite(
        id: 'wt-1',
        name: 'Water Type Site',
        waterType: WaterType.brackish,
      );
      await repository.createSite(site);
      final loaded = await repository.getSiteById('wt-1');
      expect(loaded!.waterType, WaterType.brackish);
    });

    test('imported water_type column is read back into the entity', () async {
      // Importers write the column directly (no entity mapping).
      final now = DateTime.now().millisecondsSinceEpoch;
      await database
          .into(database.diveSites)
          .insert(
            db.DiveSitesCompanion.insert(
              id: 'wt-ghost',
              name: 'Imported Site',
              createdAt: now,
              updatedAt: now,
              waterType: const Value('salt'),
            ),
          );
      final loaded = await repository.getSiteById('wt-ghost');
      expect(loaded!.waterType, WaterType.salt);
    });

    test('unknown water_type string maps to null (no crash)', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await database
          .into(database.diveSites)
          .insert(
            db.DiveSitesCompanion.insert(
              id: 'wt-bad',
              name: 'Bad Water Type',
              createdAt: now,
              updatedAt: now,
              waterType: const Value('lava'),
            ),
          );
      final loaded = await repository.getSiteById('wt-bad');
      expect(loaded!.waterType, isNull);
    });

    test('updateSite persists a changed waterType', () async {
      const site = DiveSite(id: 'wt-up', name: 'Upd', waterType: WaterType.salt);
      await repository.createSite(site);
      await repository.updateSite(site.copyWith(waterType: WaterType.fresh));
      final loaded = await repository.getSiteById('wt-up');
      expect(loaded!.waterType, WaterType.fresh);
    });

    test('waterType survives Drift row JSON serialization (sync path)', () async {
      // Sync serializes each row with row.toJson(); this proves the column
      // rides that generic path. Key-agnostic: fromJson reads back whatever
      // key toJson wrote.
      const site = DiveSite(
        id: 'wt-json',
        name: 'JSON Site',
        waterType: WaterType.fresh,
      );
      await repository.createSite(site);
      final row = await (database.select(
        database.diveSites,
      )..where((t) => t.id.equals('wt-json'))).getSingle();
      final restored = db.DiveSite.fromJson(row.toJson());
      expect(restored.waterType, 'fresh');
    });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/dive_sites/data/repositories/site_repository_test.dart`
Expected: compile FAIL — `DiveSite` has no named parameter `waterType`.

- [ ] **Step 3: Add `waterType` to the `DiveSite` entity**

In `dive_site.dart`, add the import at the top (after the equatable import on line 1):

```dart
import 'package:submersion/core/constants/enums.dart';
```

Add the field after `difficulty` (line 41):

```dart
  final SiteDifficulty? difficulty; // Site difficulty level
  final WaterType? waterType; // Salt / fresh / brackish
```

Add the constructor param after `this.difficulty,` (line 67):

```dart
    this.difficulty,
    this.waterType,
```

Add the `copyWith` param after `SiteDifficulty? difficulty,` (line 130):

```dart
    SiteDifficulty? difficulty,
    WaterType? waterType,
```

Add to the `copyWith` body after `difficulty: difficulty ?? this.difficulty,` (line 155):

```dart
      difficulty: difficulty ?? this.difficulty,
      waterType: waterType ?? this.waterType,
```

Add to `props` after `difficulty,` (line 183):

```dart
    difficulty,
    waterType,
```

- [ ] **Step 4: Hydrate and persist `waterType` in the repository**

In `site_repository_impl.dart`, in `_mapRowToSite` (line 705), add after the `difficulty:` line:

```dart
      difficulty: domain.SiteDifficulty.fromString(row.difficulty),
      waterType: row.waterType == null
          ? null
          : WaterType.values.asNameMap()[row.waterType],
```

`WaterType` is exported from `package:submersion/core/constants/enums.dart`. If that import is not already present in this file, add it.

Add `waterType: Value(site.waterType?.name),` immediately after each `difficulty: Value(site.difficulty?.name),` line in all four `DiveSitesCompanion` builders:
- `createSite` insert (line 79)
- `updateSite` update (line 133)
- restore-insert path (line 508)
- `_updateSiteRow` (line 731)

Each edit looks like:

```dart
              difficulty: Value(site.difficulty?.name),
              waterType: Value(site.waterType?.name),
```

- [ ] **Step 5: Point the site-table read path at the new field**

In `site_field.dart`, change only the value-extraction arm (line 459-460):

```dart
      case SiteField.waterType:
        return site.waterType?.displayName;
```

(The `formatValue` arm at line 497 already handles `waterType` as a `String` passthrough — `displayName` is a `String`, so it still works.)

- [ ] **Step 6: Fix the existing `site_field_test.dart` expectation**

That test currently reads water type from the dead `conditions` object. Import `WaterType` (add `import 'package:submersion/core/constants/enums.dart';` if absent), add a top-level `waterType` to the shared `testSite` after its `difficulty:` line (near line 23):

```dart
    difficulty: SiteDifficulty.advanced,
    waterType: WaterType.salt,
```

Replace the test at lines 168-173 with:

```dart
    test('returns waterType displayName from the entity', () {
      expect(
        adapter.extractValue(SiteField.waterType, testEntity),
        equals('Salt Water'),
      );
    });
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/features/dive_sites/data/repositories/site_repository_test.dart test/features/dive_sites/domain/constants/site_field_test.dart`
Expected: PASS.

- [ ] **Step 8: Guard against entity-equality regressions**

Run: `flutter test test/features/dive_sites/`
Expected: PASS (confirms the new `props` entry didn't break equality/copyWith tests elsewhere).

- [ ] **Step 9: Format, analyze, commit**

```bash
dart format lib/features/dive_sites/domain/entities/dive_site.dart lib/features/dive_sites/data/repositories/site_repository_impl.dart lib/features/dive_sites/domain/constants/site_field.dart test/features/dive_sites/data/repositories/site_repository_test.dart test/features/dive_sites/domain/constants/site_field_test.dart
flutter analyze lib/features/dive_sites test/features/dive_sites
git add lib/features/dive_sites/domain/entities/dive_site.dart lib/features/dive_sites/data/repositories/site_repository_impl.dart lib/features/dive_sites/domain/constants/site_field.dart test/features/dive_sites/data/repositories/site_repository_test.dart test/features/dive_sites/domain/constants/site_field_test.dart
git commit -m "feat(dive-sites): persist and hydrate site water type"
```

---

### Task 2: Site editor — Water Type picker

**Deliverable:** the site editor's Dive Info section shows a Water Type chip row (Salt Water / Fresh Water / Brackish); selecting one and saving persists it.

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` + the 10 other ARB files
- Modify (generated): `lib/l10n/arb/app_localizations*.dart` (via `flutter gen-l10n`)
- Modify: `lib/features/dive_sites/presentation/widgets/edit_sections/dive_info_section.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart`
- Test: `test/features/dive_sites/presentation/pages/site_edit_page_test.dart`

**Interfaces:**
- Consumes: `DiveSite.waterType` (Task 1).
- Produces: `DiveInfoSection` gains required `WaterType? waterType`, `ValueChanged<WaterType?> onWaterTypeChanged`, and optional `MergeFieldExtras? waterTypeExtras`. `SiteEditPage` gains `WaterType? _waterType` state.

- [ ] **Step 1: Add the localized label to all 11 ARB files**

In `app_en.arb`, add after `"diveSites_edit_section_rating"` (line 4106):

```json
  "diveSites_edit_section_waterType": "Water Type",
```

Add the same key with these values to each locale file (place it near the other `diveSites_edit_section_*` keys):

- `app_de.arb`: `"diveSites_edit_section_waterType": "Gewässertyp",`
- `app_es.arb`: `"diveSites_edit_section_waterType": "Tipo de agua",`
- `app_fr.arb`: `"diveSites_edit_section_waterType": "Type d'eau",`
- `app_it.arb`: `"diveSites_edit_section_waterType": "Tipo di acqua",`
- `app_nl.arb`: `"diveSites_edit_section_waterType": "Watertype",`
- `app_pt.arb`: `"diveSites_edit_section_waterType": "Tipo de água",`
- `app_hu.arb`: `"diveSites_edit_section_waterType": "Víztípus",`
- `app_he.arb`: `"diveSites_edit_section_waterType": "סוג מים",`
- `app_ar.arb`: `"diveSites_edit_section_waterType": "نوع المياه",`
- `app_zh.arb`: `"diveSites_edit_section_waterType": "水体类型",`

- [ ] **Step 2: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: regenerates `lib/l10n/arb/app_localizations*.dart`; `AppLocalizations` now exposes `diveSites_edit_section_waterType`. (Untranslated-message warnings for unrelated keys are fine.)

- [ ] **Step 3: Write the failing widget test**

Add this test in `site_edit_page_test.dart`, right after the `'selecting a difficulty chip updates state'` test (ends line 376). It mirrors that test exactly.

```dart
    testWidgets('selecting a water type chip updates state', (tester) async {
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _buildHarness(prefs: prefs, divers: const [], shareByDefault: false),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Water Type'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      // Tap the Brackish chip.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Brackish'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Brackish'))
            .selected,
        isTrue,
      );
      // Tap again to deselect.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Brackish'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Brackish'))
            .selected,
        isFalse,
      );
    });
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/pages/site_edit_page_test.dart -n "water type chip"`
Expected: FAIL — no "Water Type" text / no such chip.

- [ ] **Step 5: Add the water-type control to `DiveInfoSection`**

In `dive_info_section.dart`, add the import after line 4:

```dart
import 'package:submersion/core/constants/enums.dart';
```

Add constructor params — after `required this.onRatingCleared,` (line 25):

```dart
    required this.onRatingCleared,
    required this.waterType,
    required this.onWaterTypeChanged,
```

and after `this.ratingExtras,` (line 28):

```dart
    this.ratingExtras,
    this.waterTypeExtras,
```

Add the fields after `final VoidCallback onRatingCleared;` (line 42) and after `final MergeFieldExtras? ratingExtras;` (line 45):

```dart
  final VoidCallback onRatingCleared;
  final WaterType? waterType;
  final ValueChanged<WaterType?> onWaterTypeChanged;
```

```dart
  final MergeFieldExtras? ratingExtras;
  final MergeFieldExtras? waterTypeExtras;
```

In `build`, insert this block into `children` immediately after the difficulty `Column(...)` block closes (after line 116, before the rating `Column`):

```dart
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (waterTypeExtras != null)
              MergeSourceRow(
                sourceLabel: waterTypeExtras!.sourceLabel,
                onCycle: waterTypeExtras!.onCycle,
              ),
            FormRow.custom(
              label: l10n.diveSites_edit_section_waterType,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 4,
                children: WaterType.values.map((value) {
                  final isSelected = waterType == value;
                  return ChoiceChip(
                    label: Text(value.displayName),
                    selected: isSelected,
                    visualDensity: VisualDensity.compact,
                    onSelected: (selected) =>
                        onWaterTypeChanged(selected ? value : null),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
```

- [ ] **Step 6: Wire state into `SiteEditPage`**

In `site_edit_page.dart`, add the import (with the other `core/constants` imports):

```dart
import 'package:submersion/core/constants/enums.dart';
```

Add the state field after `SiteDifficulty? _difficulty;` (line 83):

```dart
  SiteDifficulty? _difficulty;
  WaterType? _waterType;
```

Seed it after `_difficulty = site.difficulty;` (line 219):

```dart
    _difficulty = site.difficulty;
    _waterType = site.waterType;
```

Add it to the section summary — after the difficulty line in `_diveInfoSummary()` (line 694):

```dart
    if (_difficulty != null) _difficulty!.displayName,
    if (_waterType != null) _waterType!.displayName,
```

Wire the `DiveInfoSection` call — after the `onRatingCleared: …` closure (ends line 796), add:

```dart
            onRatingCleared: () => setState(() {
              _rating = 0;
              _hasChanges = true;
            }),
            waterType: _waterType,
            onWaterTypeChanged: (value) => setState(() {
              _waterType = value;
              _hasChanges = true;
            }),
```

Add `waterType:` to the saved `DiveSite(...)` — after `altitude: altitudeMeters,` (line 1319):

```dart
        altitude: altitudeMeters,
        waterType: _waterType,
        isShared: _isShared,
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `flutter test test/features/dive_sites/presentation/pages/site_edit_page_test.dart`
Expected: PASS (the new test and all existing site-editor tests).

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format lib/features/dive_sites/presentation/widgets/edit_sections/dive_info_section.dart lib/features/dive_sites/presentation/pages/site_edit_page.dart test/features/dive_sites/presentation/pages/site_edit_page_test.dart
flutter analyze lib/features/dive_sites lib/l10n test/features/dive_sites
git add lib/l10n/arb lib/features/dive_sites/presentation/widgets/edit_sections/dive_info_section.dart lib/features/dive_sites/presentation/pages/site_edit_page.dart test/features/dive_sites/presentation/pages/site_edit_page_test.dart
git commit -m "feat(dive-sites): edit water type in the site editor"
```

---

### Task 3: Site editor — merge parity for water type (optional, separable)

**Deliverable:** when merging sites with different water types, the editor offers a cycle affordance like difficulty/rating. Tasks 1, 2, and 4 deliver the issue without this; skip if deferring.

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart`
- Test: `test/features/dive_sites/presentation/pages/site_edit_merge_page_test.dart`

**Interfaces:**
- Consumes: `DiveInfoSection.waterTypeExtras` (Task 2), `DiveSite.waterType` (Task 1), existing private helpers `_buildDistinctCandidates<T>`, `_firstMeaningfulIndex`, `_MergeFieldCandidate<T>`, `_mergeFieldIndices`.

- [ ] **Step 1: Write the failing merge test**

Add this test in `site_edit_merge_page_test.dart`, right after the `'merge mode cycles difficulty when sites have different difficulties'` test. It mirrors that test's structure; reuse the file's existing `siteRepository`, `prefs`, and merge harness.

```dart
  testWidgets(
    'merge mode cycles water type when sites differ',
    (tester) async {
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final site1 = await siteRepository.createSite(
        const DiveSite(id: '', name: 'Salt Site', waterType: WaterType.salt),
      );
      final site2 = await siteRepository.createSite(
        const DiveSite(id: '', name: 'Fresh Site', waterType: WaterType.fresh),
      );

      await tester.pumpWidget(
        _buildMergeHarness(
          prefs: prefs,
          divers: const [],
          mergeSiteIds: [site1.id, site2.id],
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Water Type'),
        100,
        scrollable: find.byType(Scrollable).first,
      );

      // Initial value is the first non-empty candidate (Salt Water).
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Salt Water'))
            .selected,
        isTrue,
      );

      final waterTypeSection = find.ancestor(
        of: find.text('Water Type'),
        matching: find.byType(Card),
      );
      final cycleButton = find.descendant(
        of: waterTypeSection,
        matching: find.byIcon(Icons.sync_alt),
      );
      expect(cycleButton, findsOneWidget);

      await tester.tap(cycleButton);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Fresh Water'))
            .selected,
        isTrue,
      );
    },
  );
```

Ensure `WaterType` is imported in this test file (add `import 'package:submersion/core/constants/enums.dart';` if absent).

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/pages/site_edit_merge_page_test.dart -n "water type"`
Expected: FAIL — no water-type cycle button in merge mode.

- [ ] **Step 3: Add the merge candidate state**

In `site_edit_page.dart`, add the candidate list after `_difficultyCandidates` (line 96):

```dart
  List<_MergeFieldCandidate<SiteDifficulty?>> _difficultyCandidates = [];
  List<_MergeFieldCandidate<WaterType?>> _waterTypeCandidates = [];
```

- [ ] **Step 4: Build the candidates on merge load**

After the difficulty candidate block (ends line 361), add:

```dart
    _waterTypeCandidates = _buildDistinctCandidates<WaterType?>(
      data.sites,
      (site) => site.waterType,
      equals: (a, b) => a == b,
    );
    _mergeFieldIndices['waterType'] = _firstMeaningfulIndex(
      _waterTypeCandidates,
      (value) => value != null,
    );
    _waterType =
        _waterTypeCandidates[_mergeFieldIndices['waterType'] ?? 0].value;
```

- [ ] **Step 5: Add the extras + cycle methods**

After `_difficultyExtras()` (ends line 651), add:

```dart
  MergeFieldExtras? _waterTypeExtras() {
    if (!widget.isMerging || _waterTypeCandidates.length < 2) return null;
    final index = _mergeFieldIndices['waterType'] ?? 0;
    return MergeFieldExtras(
      sourceLabel: context.l10n.diveSites_edit_merge_fieldSourceLabel(
        _waterTypeCandidates[index].siteName,
        index + 1,
        _waterTypeCandidates.length,
      ),
      onCycle: _cycleWaterType,
    );
  }
```

After `_cycleDifficulty()` (ends line 1028), add:

```dart
  void _cycleWaterType() {
    if (_waterTypeCandidates.length < 2) return;
    setState(() {
      final nextIndex =
          ((_mergeFieldIndices['waterType'] ?? 0) + 1) %
          _waterTypeCandidates.length;
      _mergeFieldIndices['waterType'] = nextIndex;
      _waterType = _waterTypeCandidates[nextIndex].value;
      _hasChanges = true;
    });
  }
```

- [ ] **Step 6: Pass the extras to the section**

In the `DiveInfoSection(...)` call, add after the `onWaterTypeChanged:` closure (added in Task 2):

```dart
            waterTypeExtras: _waterTypeExtras(),
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `flutter test test/features/dive_sites/presentation/pages/site_edit_merge_page_test.dart`
Expected: PASS.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format lib/features/dive_sites/presentation/pages/site_edit_page.dart test/features/dive_sites/presentation/pages/site_edit_merge_page_test.dart
flutter analyze lib/features/dive_sites test/features/dive_sites
git add lib/features/dive_sites/presentation/pages/site_edit_page.dart test/features/dive_sites/presentation/pages/site_edit_merge_page_test.dart
git commit -m "feat(dive-sites): cycle water type when merging sites"
```

---

### Task 4: Dive form — snap water type on site assign

**Deliverable:** assigning or changing a site on a dive auto-fills the dive's water type (snap when the site has one; keep the current value otherwise, including when clearing the site). Only needs Task 1.

**Files:**
- Create: `lib/features/dive_log/presentation/utils/water_type_autofill.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- Test: `test/features/dive_log/presentation/utils/water_type_autofill_test.dart`

**Interfaces:**
- Consumes: `DiveSite.waterType` (Task 1).
- Produces: `WaterType? waterTypeAfterSiteAssign(WaterType? current, DiveSite? site)` — the pure snap rule. `_assignSite(DiveSite? site)` on the dive edit page.

- [ ] **Step 1: Write the failing unit test**

Create `test/features/dive_log/presentation/utils/water_type_autofill_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/utils/water_type_autofill.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  DiveSite site({WaterType? waterType}) =>
      DiveSite(id: 's', name: 'S', waterType: waterType);

  group('waterTypeAfterSiteAssign', () {
    test('snaps to the site water type when the site has one', () {
      expect(
        waterTypeAfterSiteAssign(null, site(waterType: WaterType.salt)),
        WaterType.salt,
      );
    });

    test('overwrites the current value when the new site has a water type', () {
      expect(
        waterTypeAfterSiteAssign(
          WaterType.fresh,
          site(waterType: WaterType.salt),
        ),
        WaterType.salt,
      );
    });

    test('keeps the current value when the site has no water type', () {
      expect(waterTypeAfterSiteAssign(WaterType.fresh, site()), WaterType.fresh);
    });

    test('keeps the current value when the site is cleared (null)', () {
      expect(
        waterTypeAfterSiteAssign(WaterType.brackish, null),
        WaterType.brackish,
      );
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/utils/water_type_autofill_test.dart`
Expected: compile FAIL — `water_type_autofill.dart` / `waterTypeAfterSiteAssign` do not exist.

- [ ] **Step 3: Create the pure snap function**

Create `lib/features/dive_log/presentation/utils/water_type_autofill.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// The dive's water type after [site] is assigned to it, given the dive's
/// [current] value.
///
/// Snap-on-assign: take the site's water type when it has one; otherwise keep
/// the current value. A site with no water type — or clearing the site
/// ([site] == null) — never wipes a value the diver already set.
WaterType? waterTypeAfterSiteAssign(WaterType? current, DiveSite? site) =>
    site?.waterType ?? current;
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/utils/water_type_autofill_test.dart`
Expected: PASS.

- [ ] **Step 5: Add `_assignSite` and route user-initiated assignments through it**

In `dive_edit_page.dart`, add the import (with the other `features/dive_log` imports):

```dart
import 'package:submersion/features/dive_log/presentation/utils/water_type_autofill.dart';
```

Add this method near the other site handlers (e.g., just above `_showSitePicker`, line 1961):

```dart
  /// Assigns [site] to the dive and snaps the water type from it (manual
  /// overrides survive when the site has none). Use for user-initiated
  /// assignments and new-dive prefill — NOT the load path, which restores the
  /// dive's own saved water type.
  void _assignSite(DiveSite? site) {
    _selectedSite = site;
    _waterType = waterTypeAfterSiteAssign(_waterType, site);
  }
```

Change these five call sites (leave line 588 load and line 1947 GPS-update untouched):

Line 453 (new-dive prefill):

```dart
    if (p.site != null) _assignSite(p.site);
```

Line 1735 (clear site):

```dart
        setState(() => _assignSite(null));
```

Line 1920 (photo-GPS create — inside the existing `setState`):

```dart
      setState(() {
        _assignSite(createdSite);
        _gpsSuggestionDismissed = true;
      });
```

Line 1978 (site picker selection):

```dart
            setState(() => _assignSite(site));
```

Line 1996 (create-new site result):

```dart
          setState(() => _assignSite(site));
```

- [ ] **Step 6: Analyze and run the dive-log tests**

Run: `flutter analyze lib/features/dive_log test/features/dive_log`
Then: `flutter test test/features/dive_log/presentation/pages/dive_edit_page_test.dart test/features/dive_log/presentation/utils/water_type_autofill_test.dart`
Expected: analyze clean; tests PASS (existing dive-edit tests still green — the load path is unchanged).

- [ ] **Step 7: Format, commit**

```bash
dart format lib/features/dive_log/presentation/utils/water_type_autofill.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/presentation/utils/water_type_autofill_test.dart
git add lib/features/dive_log/presentation/utils/water_type_autofill.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/presentation/utils/water_type_autofill_test.dart
git commit -m "feat(dive-log): auto-fill dive water type from the assigned site"
```

---

### Task 5: Full verification

**Deliverable:** confidence the whole feature works end-to-end.

- [ ] **Step 1: Run the full test suite**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 2: Format + analyze the whole project**

Run: `dart format .` then `flutter analyze`
Expected: no changes from format; analyze clean.

- [ ] **Step 3: Manual smoke test (macOS)**

Run: `flutter run -d macos`
Verify:
1. Edit a dive site → Dive Info → set Water Type = Salt Water → save.
2. New dive → assign that site → the dive's Water Type shows Salt Water.
3. Manually change the dive's Water Type to Fresh → change some other field → it stays Fresh.
4. Change the dive to a different site (with a different or no water type) → snaps to that site's value / stays put if the site has none.
5. Clear the site → water type is retained.

- [ ] **Step 4:** Note macOS smoke result in the PR description (device-verified vs not).

---

## Notes for the implementer

- **Line numbers** are from `main` at plan-writing time; if a file has shifted, anchor on the quoted code (e.g. `difficulty: Value(site.difficulty?.name),`) rather than the line number.
- **Snapshot, not derive:** never change the dive to read water type live from the site. The dive owns its value.
- **Do not touch** `SiteConditions.waterType` (the dead String field) or `dive_plans.waterType` (planner deco). Out of scope.
- **No schema/version work** — the column already exists and already syncs.
