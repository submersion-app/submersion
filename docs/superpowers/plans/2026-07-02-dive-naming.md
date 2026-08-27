# Dive Naming (#400) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Optional user-defined dive name, selectable as the list-tile title with site-name fallback, shown in the detail header, searchable, and exported to CSV/UDDF.

**Architecture:** Nullable `name` TEXT column on `dives` (schema 93 → 94; sync is automatic via Drift `toJson()`). Fallback `name ?? siteName` lives in the display layer only: the `DiveField` extractor for tiles/table, and the detail-page headers. A new `DiveField.diveName` enum value plugs into the existing configurable-title mechanism.

**Tech Stack:** Flutter 3.x, Drift ORM (codegen via build_runner), Riverpod, flutter_localizations (gen-l10n), Equatable entities.

**Spec:** `docs/superpowers/specs/2026-07-02-dive-naming-design.md`

## Global Constraints

- Working directory is the worktree: `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/issue-400-dive-naming`. All paths below are relative to it.
- The enum value is `DiveField.diveName` (NOT `name` — Dart's implicit `Enum.name` getter is used to persist field selections; a member named `name` would collide confusingly).
- Empty or whitespace-only name is stored as SQL NULL, never `''`.
- Exports write the raw stored name (blank when unset), never the site fallback.
- No emojis anywhere. Run `dart format .` (whole repo) before every commit.
- Run only the specific test files named in each task (broad `flutter test` runs time out in this environment; CI runs the full suite).
- Commits: plain message, no Co-Authored-By lines.
- After adding the enum value, `flutter analyze` MUST pass — it is the tool that finds every exhaustive `switch (this)` over `DiveField` that needs a new case. Task 3 enumerates the expected ones.

---

### Task 1: Schema v94 — `name` column on dives

**Files:**
- Modify: `lib/core/database/database.dart` (Dives table ~line 133; `currentSchemaVersion` ~line 1710; `migrationVersions` list ~line 1806; `onUpgrade` tail ~line 4320)
- Create: `test/core/database/migration_v94_dive_name_test.dart`

**Interfaces:**
- Produces: generated Drift getters `Dive.name` (row class) and `DivesCompanion.name` (`Value<String?>`), used by Task 2. SQL column `dives.name TEXT NULL`.

- [ ] **Step 1: Write the failing migration test**

Create `test/core/database/migration_v94_dive_name_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('v94 adds name column to dives, null for existing rows', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 93');
        // Minimal pre-v94 dives shape: just enough columns to insert a row.
        // The v94 migration adds the name column.
        rawDb.execute('''
        CREATE TABLE dives (
          id TEXT NOT NULL PRIMARY KEY,
          dive_date_time INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
        rawDb.execute(
          "INSERT INTO dives (id, dive_date_time, created_at, updated_at) "
          "VALUES ('d1', 1, 1, 1)",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    // Touch the DB so the migration runs.
    final cols = await db.customSelect("PRAGMA table_info('dives')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('name'));

    // Existing rows read the new column as NULL.
    final row = await db
        .customSelect("SELECT name FROM dives WHERE id = 'd1'")
        .getSingle();
    expect(row.data['name'], isNull);
  });

  test('v94 is the current version and in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, 94);
    expect(AppDatabase.migrationVersions, contains(94));
    expect(AppDatabase.migrationVersions.last, 94);
  });

  test('v94 migration is idempotent when the column already exists', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 93');
        rawDb.execute('''
        CREATE TABLE dives (
          id TEXT NOT NULL PRIMARY KEY,
          dive_date_time INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          name TEXT
        )
      ''');
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    // Must not fail on a duplicate ALTER.
    final cols = await db.customSelect("PRAGMA table_info('dives')").get();
    final names = cols.map((c) => c.read<String>('name')).toList();
    expect(names.where((n) => n == 'name').length, 1);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/database/migration_v94_dive_name_test.dart`
Expected: FAIL — `currentSchemaVersion` is 93, no `name` column is added.

- [ ] **Step 3: Add the column, version bump, and migration**

In `lib/core/database/database.dart`:

a) In `class Dives extends Table`, immediately after `IntColumn get diveNumber => integer().nullable()();`:

```dart
  // User-defined dive name (#400). Null = never named; display falls back
  // to the site name.
  TextColumn get name => text().nullable()();
```

b) Change `static const int currentSchemaVersion = 93;` to `= 94;`.

c) In the `migrationVersions` list, after the final `93,` add `94,`.

d) In `onUpgrade`, immediately after the final `if (from < 93) await reportProgress();` (before the closing `},` of onUpgrade):

```dart
        if (from < 94) {
          // Dive naming (#400): optional user-defined dive name. Guarded by a
          // PRAGMA check so an interrupted upgrade that already added the
          // column does not fail on a duplicate ALTER.
          final diveCols = await customSelect(
            "PRAGMA table_info('dives')",
          ).get();
          final hasName = diveCols.any(
            (c) => c.read<String>('name') == 'name',
          );
          if (!hasName) {
            await customStatement('ALTER TABLE dives ADD COLUMN name TEXT');
          }
        }
        if (from < 94) await reportProgress();
```

- [ ] **Step 4: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: exits 0; `lib/core/database/database.g.dart` regenerated (the generated `Dive` row class and `DivesCompanion` now include `name`). Sync serialization picks the column up automatically via the generated `toJson()`.

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/core/database/migration_v94_dive_name_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(db): add nullable name column to dives (v94) (#400)"
```

---

### Task 2: Entity, summary, and repository round-trip

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart`
- Modify: `lib/features/dive_log/domain/entities/dive_summary.dart`
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`
- Create: `test/features/dive_log/data/repositories/dive_name_test.dart`

**Interfaces:**
- Consumes: generated `DivesCompanion.name` / row `name` from Task 1.
- Produces: `Dive.name` (`String?`, constructor param `this.name`, in `copyWith` and `props`); `DiveSummary.name` (`String?`); repository persists and hydrates it; `getDiveSummaries()` rows carry `name`. Tasks 3–6 rely on `dive.name` and `summary.name` exactly.

**Placement rule used throughout: `name` goes immediately after `diveNumber` in every field list, constructor, copyWith, and props.** In `Dive.copyWith` use the plain `name ?? this.name` pattern — this entity uses no clear-sentinels; clearing happens because the edit page constructs a fresh `Dive` (Task 4).

- [ ] **Step 1: Write the failing round-trip test**

Create `test/features/dive_log/data/repositories/dive_name_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart' as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  // ignore: unused_local_variable
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  domain.Dive makeDive({String? name, String id = ''}) => domain.Dive(
    id: id,
    dateTime: DateTime.utc(2026, 7, 1, 10, 0),
    name: name,
  );

  group('dive name persistence', () {
    test('createDive and getDiveById round-trip a name', () async {
      final created = await repository.createDive(
        makeDive(name: 'Wreck penetration dive'),
      );
      final loaded = await repository.getDiveById(created.id);
      expect(loaded!.name, 'Wreck penetration dive');
    });

    test('name is null when never set', () async {
      final created = await repository.createDive(makeDive());
      final loaded = await repository.getDiveById(created.id);
      expect(loaded!.name, isNull);
    });

    test('updateDive can set and clear the name', () async {
      final created = await repository.createDive(makeDive());
      await repository.updateDive(
        created.copyWith(name: 'Training dive 1'),
      );
      var loaded = await repository.getDiveById(created.id);
      expect(loaded!.name, 'Training dive 1');

      // Clearing: copyWith cannot null a field (plain ?? pattern), so build
      // the cleared dive the way the edit form does — a fresh entity.
      await repository.updateDive(makeDive(id: created.id));
      loaded = await repository.getDiveById(created.id);
      expect(loaded!.name, isNull);
    });

    test('getDiveSummaries carries the name', () async {
      await repository.createDive(makeDive(name: 'Night dive'));
      final summaries = await repository.getDiveSummaries(limit: 10);
      expect(summaries, hasLength(1));
      expect(summaries.first.name, 'Night dive');
    });

    test('copyWith preserves name and props includes it', () {
      final a = makeDive(name: 'A');
      final b = makeDive(name: 'B');
      expect(a.copyWith(rating: 5).name, 'A');
      expect(a == b, isFalse); // props must include name
      expect(a == makeDive(name: 'A'), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_name_test.dart`
Expected: FAIL to compile — `Dive` has no `name` parameter.

- [ ] **Step 3: Add `name` to the Dive entity**

In `lib/features/dive_log/domain/entities/dive.dart`, four edits, each immediately after the `diveNumber` entry:

a) Field (after `final int? diveNumber;`):

```dart
  // User-defined dive name (#400). Null = never named.
  final String? name;
```

b) Constructor (after `this.diveNumber,`): add `this.name,`

c) `copyWith` parameter list (after `int? diveNumber,`): add `String? name,`
   `copyWith` body (after `diveNumber: diveNumber ?? this.diveNumber,`): add `name: name ?? this.name,`

d) `props` list (after `diveNumber,`): add `name,`

- [ ] **Step 4: Add `name` to DiveSummary**

In `lib/features/dive_log/domain/entities/dive_summary.dart`, five edits, each immediately after the `diveNumber` entry:

a) Field (after `final int? diveNumber;`): add `final String? name;`
b) Constructor (after `this.diveNumber,`): add `this.name,`
c) `DiveSummary.fromDive` (after `diveNumber: dive.diveNumber,`): add `name: dive.name,`
d) `copyWith` params (after `int? diveNumber,`): add `String? name,`; body (after `diveNumber: diveNumber ?? this.diveNumber,`): add `name: name ?? this.name,`
e) `props` (after `diveNumber,`): add `name,`

- [ ] **Step 5: Wire the repository**

In `lib/features/dive_log/data/repositories/dive_repository_impl.dart`:

a) Both companion writes — after each of the two `notes: Value(dive.notes),` lines (createDive path ~line 718, updateDive path ~line 959), add:

```dart
              name: Value(dive.name),
```

(Indentation: match the surrounding lines — the two sites differ by one level.)

b) Both dive row→entity reads — after each of the two `notes: row.notes,` lines that sit inside a `domain.Dive(` construction (~lines 2258 and 2608), add `name: row.name,`.
   CAUTION: there is a third `notes: row.notes,` (~line 3050) inside a `domain.DiveWeight(` construction — do NOT touch that one.

c) Summary SQL (~line 1364): in the SELECT column list, change

```dart
            'SELECT '
            'd.id, d.dive_number, d.dive_date_time, d.entry_time, '
```

to

```dart
            'SELECT '
            'd.id, d.dive_number, d.name AS dive_name, '
            'd.dive_date_time, d.entry_time, '
```

d) Summary construction (~line 1400): after `diveNumber: row.readNullable<int>('dive_number'),` add:

```dart
            name: row.readNullable<String>('dive_name'),
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/data/repositories/dive_name_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 7: Run neighboring regression tests**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_coverage_test.dart test/features/dive_log/domain/entities/`
Expected: PASS — no existing entity/repository behavior changed.

- [ ] **Step 8: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(dive): add name to Dive entity, DiveSummary, and repository (#400)"
```

---

### Task 3: `DiveField.diveName` — opt-in title with site fallback

**Files:**
- Modify: `lib/core/constants/dive_field.dart`
- Modify: `lib/core/constants/dive_field_extractor.dart`
- Modify: `lib/core/constants/dive_field_column_sizing.dart`
- Test: `test/core/constants/dive_field_extractor_test.dart` (extend)

**Interfaces:**
- Consumes: `Dive.name`, `DiveSummary.name`, `dive.site?.name`, `summary.siteName` from Task 2.
- Produces: `DiveField.diveName` enum value; `extractFromSummary(summary)` returns `summary.name ?? summary.siteName`; `extractFromDive(dive)` returns `dive.name ?? dive.site?.name`. List tiles and table need no widget changes — they consume the enum. `formatValue` needs no case (default `'$value'` / `'--'` handles strings).

- [ ] **Step 1: Write the failing extractor tests**

In `test/core/constants/dive_field_extractor_test.dart`, add inside `main()` (it already has fixtures `testSite` named `'Blue Hole'` and a `now` DateTime — reuse them; place the group at the end of `main()`):

```dart
  group('DiveField.diveName', () {
    test('extractFromSummary returns the name when set', () {
      final summary = DiveSummary(
        id: 'd1',
        dateTime: now,
        name: 'Wreck penetration dive',
        siteName: 'Blue Hole',
        sortTimestamp: 0,
      );
      expect(
        DiveField.diveName.extractFromSummary(summary),
        'Wreck penetration dive',
      );
    });

    test('extractFromSummary falls back to the site name when unnamed', () {
      final summary = DiveSummary(
        id: 'd1',
        dateTime: now,
        siteName: 'Blue Hole',
        sortTimestamp: 0,
      );
      expect(DiveField.diveName.extractFromSummary(summary), 'Blue Hole');
    });

    test('extractFromSummary returns null when name and site are absent', () {
      final summary = DiveSummary(id: 'd1', dateTime: now, sortTimestamp: 0);
      expect(DiveField.diveName.extractFromSummary(summary), isNull);
    });

    test('extractFromDive falls back to site name', () {
      final named = Dive(id: 'd1', dateTime: now, name: 'Training 1');
      final unnamed = Dive(id: 'd2', dateTime: now, site: testSite);
      expect(DiveField.diveName.extractFromDive(named), 'Training 1');
      expect(DiveField.diveName.extractFromDive(unnamed), 'Blue Hole');
    });

    test('diveName is a summary field in the core category', () {
      expect(DiveField.summaryFields, contains(DiveField.diveName));
      expect(DiveField.diveName.category, DiveFieldCategory.core);
      expect(DiveField.diveName.displayName, 'Dive Name');
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/constants/dive_field_extractor_test.dart`
Expected: FAIL to compile — `DiveField.diveName` does not exist.

- [ ] **Step 3: Add the enum value and metadata cases**

In `lib/core/constants/dive_field.dart`:

a) Enum member — after `siteName,` in the `// Core` block, add `diveName,`

b) `summaryFields` set — after `DiveField.siteName,` add `DiveField.diveName,`

c) `category` switch — add `case DiveField.diveName:` alongside the other core cases (insert after `case DiveField.siteName:` in the group returning `DiveFieldCategory.core`).

d) `displayName` switch — after the `siteName` case:

```dart
      case DiveField.diveName:
        return 'Dive Name';
```

e) `shortLabel` switch — after the `siteName` case:

```dart
      case DiveField.diveName:
        return 'Name';
```

f) `icon` switch — after the `siteName` case:

```dart
      case DiveField.diveName:
        return Icons.drive_file_rename_outline;
```

g) `sortable` switch — add `case DiveField.diveName:` to the group returning `false` (there is no SQL sort mapping for it).

- [ ] **Step 4: Add the extractor cases**

In `lib/core/constants/dive_field_extractor.dart`:

a) `extractFromDive` — after the `case DiveField.siteName:` case:

```dart
      case DiveField.diveName:
        return dive.name ?? dive.site?.name;
```

b) `extractFromSummary` — after the `case DiveField.siteName:` case:

```dart
      case DiveField.diveName:
        return summary.name ?? summary.siteName;
```

- [ ] **Step 5: Add the column-sizing cases**

In `lib/core/constants/dive_field_column_sizing.dart`:

a) `defaultWidth` switch — after the `siteName` case (which returns 160):

```dart
      case DiveField.diveName:
        return 160;
```

b) `minWidth` switch — after the `siteName` case (which returns 60):

```dart
      case DiveField.diveName:
        return 60;
```

- [ ] **Step 6: Analyze to catch any remaining exhaustive switches**

Run: `flutter analyze`
Expected: 0 issues. If it reports a non-exhaustive `switch` anywhere else (candidates: `lib/features/dive_log/domain/constants/dive_field_adapter.dart`, `lib/features/dive_log/presentation/pages/dive_list_page.dart`, `lib/features/dive_log/presentation/widgets/dive_table_view.dart` — these are believed to have defaults/wildcards), add a `case DiveField.diveName:` behaving exactly like the adjacent `DiveField.siteName` case, then re-run until clean.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/core/constants/dive_field_extractor_test.dart test/core/constants/dive_field_test.dart test/core/constants/dive_field_formatter_test.dart test/features/dive_log/domain/constants/dive_field_adapter_test.dart`
Expected: PASS.

- [ ] **Step 8: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(dive): DiveField.diveName opt-in title with site fallback (#400)"
```

---

### Task 4: Edit form — Name row in The Dive section

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (+ regenerate localizations)
- Modify: `lib/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
- Create: `test/features/dive_log/presentation/widgets/the_dive_section_name_test.dart`

**Interfaces:**
- Consumes: `Dive.name` from Task 2; l10n keys added here.
- Produces: `TheDiveSection` gains `required TextEditingController nameController`; the edit page saves `name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null`. New l10n getters `diveLog_edit_label_diveName` ("Name") and `diveLog_edit_diveNamePlaceholder` ("Optional name for this dive") — Task 7 translates them.

- [ ] **Step 1: Add the English ARB keys and regenerate**

In `lib/l10n/arb/app_en.arb`, immediately after the `"diveLog_edit_label_diveNumber"` key and its `"@diveLog_edit_label_diveNumber"` metadata entry, insert:

```json
  "diveLog_edit_label_diveName": "Name",
  "@diveLog_edit_label_diveName": {
    "description": "Label for the optional dive name field in the dive edit form"
  },
  "diveLog_edit_diveNamePlaceholder": "Optional name for this dive",
  "@diveLog_edit_diveNamePlaceholder": {
    "description": "Placeholder shown in the empty dive name field"
  },
```

Then run: `flutter gen-l10n`
Expected: exits 0; `lib/l10n/arb/app_localizations*.dart` regenerated (non-English locales fall back to English until Task 7).

- [ ] **Step 2: Write the failing widget test**

Create `test/features/dive_log/presentation/widgets/the_dive_section_name_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  testWidgets('TheDiveSection renders a Name row bound to its controller', (
    tester,
  ) async {
    final nameController = TextEditingController();
    addTearDown(nameController.dispose);
    final controllers = List.generate(5, (_) => TextEditingController());
    for (final c in controllers) {
      addTearDown(c.dispose);
    }

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: TheDiveSection(
              depthSymbol: 'm',
              nameController: nameController,
              maxDepthController: controllers[0],
              avgDepthController: controllers[1],
              bottomTimeController: controllers[2],
              runtimeController: controllers[3],
              diveNumberController: controllers[4],
              entryText: 'Jul 1, 2026',
              onEditEntry: () {},
              exitText: null,
              onEditExit: () {},
              siteName: null,
              onPickSite: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Name'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Optional name for this dive'),
      'Wreck penetration dive',
    );
    expect(nameController.text, 'Wreck penetration dive');
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/the_dive_section_name_test.dart`
Expected: FAIL to compile — `TheDiveSection` has no `nameController` parameter.

Note: if `FormRow.text` renders the placeholder differently than a `TextField` hint and the `find.widgetWithText(TextField, ...)` finder fails after Step 4, adjust the finder to `find.byType(TextField).first` (the Name row is the first row in the section) — the assertion on `nameController.text` is the point of the test.

- [ ] **Step 4: Add the Name row to TheDiveSection**

In `lib/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart`:

a) Constructor — after `required this.depthSymbol,` add `required this.nameController,`
b) Fields — after `final String depthSymbol;` add `final TextEditingController nameController;`
c) In `build`, as the FIRST child of the `FormSection` `children:` list (before the dive-number `FormRow.text`):

```dart
        FormRow.text(
          label: l10n.diveLog_edit_label_diveName,
          controller: nameController,
          placeholder: l10n.diveLog_edit_diveNamePlaceholder,
        ),
```

- [ ] **Step 5: Wire the controller through the edit page**

In `lib/features/dive_log/presentation/pages/dive_edit_page.dart`, five edits mirroring `_notesController`:

a) Declaration — after `final _notesController = TextEditingController();` (~line 138):

```dart
  final _nameController = TextEditingController();
```

b) Dirty-tracking list (~line 319) — after `_notesController,` add `_nameController,`

c) Load from entity (~line 461) — after `_notesController.text = dive.notes;`:

```dart
          _nameController.text = dive.name ?? '';
```

d) `dispose()` (~line 620) — after `_notesController.dispose();` add `_nameController.dispose();`

e) `_buildTheDiveSection` (~line 1535) — in the `TheDiveSection(` constructor call, after `depthSymbol: units.depthSymbol,`:

```dart
      nameController: _nameController,
```

f) Save path — in the single-dive save `Dive(` construction (~line 3934), after `diveNumber: ...` (the `diveNumber:` argument ends with `: null,`):

```dart
        name: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : null,
```

CAUTION: this file also builds a bulk-edit values object around line 885 (`notes: _notesController.text,` near `scrubberType:`) — that is the bulk-edit path, deliberately out of scope. Do NOT add `name` there.

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/the_dive_section_name_test.dart`
Expected: PASS.

- [ ] **Step 7: Analyze and format, then commit**

Run: `flutter analyze` — expected 0 issues (catches any missed `TheDiveSection(` call sites; `_buildTheDiveSection` is believed to be the only one).

```bash
dart format .
git add -A
git commit -m "feat(dive): dive name field in the edit form (#400)"
```

---

### Task 5: Detail-page header and search

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (two headers, ~lines 658 and ~821)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (searchDives, ~line 1806)
- Test: `test/features/dive_log/data/repositories/dive_name_test.dart` (extend)

**Interfaces:**
- Consumes: `Dive.name` from Task 2; `repository.searchDives(query)` existing signature.
- Produces: named dives match dive-list search; detail header shows the name as title with site beneath.

- [ ] **Step 1: Write the failing search test**

In `test/features/dive_log/data/repositories/dive_name_test.dart`, add inside `main()` after the existing group:

```dart
  group('searchDives by name', () {
    test('matches a dive by its custom name', () async {
      await repository.createDive(makeDive(name: 'Wreck penetration dive'));
      await repository.createDive(makeDive(name: 'Reef checkout'));

      final results = await repository.searchDives('penetration');
      expect(results, hasLength(1));
      expect(results.first.name, 'Wreck penetration dive');
    });

    test('does not match unnamed dives', () async {
      await repository.createDive(makeDive());
      final results = await repository.searchDives('penetration');
      expect(results, isEmpty);
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_name_test.dart`
Expected: the two new tests FAIL (name not in the LIKE clause); the Task 2 tests still pass.

- [ ] **Step 3: Add name to the search SQL**

In `lib/features/dive_log/data/repositories/dive_repository_impl.dart`, in `searchDives`:

a) In the WHERE block, after the line `d.notes LIKE ?` add a new line:

```
              OR d.name LIKE ?
```

b) In the `variables:` list for that query (currently 11 `Variable(likeTerm)` entries before `...diverArgs`), add one more `Variable(likeTerm),` so the count matches the 12 placeholders.

c) Update the doc comment above the method to mention the name field.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/data/repositories/dive_name_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Update the two detail-page headers**

In `lib/features/dive_log/presentation/pages/dive_detail_page.dart`:

a) Compact header (~line 658). Replace:

```dart
                Text(
                  dive.site?.name ?? context.l10n.diveLog_listPage_unknownSite,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
```

with:

```dart
                Text(
                  dive.name ??
                      dive.site?.name ??
                      context.l10n.diveLog_listPage_unknownSite,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                if (dive.name != null && dive.site != null)
                  Text(
                    dive.site!.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
```

b) Large header (~line 821). Replace:

```dart
                    Text(
                      dive.site?.name ??
                          context.l10n.diveLog_listPage_unknownSite,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
```

with:

```dart
                    Text(
                      dive.name ??
                          dive.site?.name ??
                          context.l10n.diveLog_listPage_unknownSite,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (dive.name != null && dive.site != null)
                      Text(
                        dive.site!.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
```

(Unnamed dives render exactly as before in both headers.)

- [ ] **Step 6: Analyze, format, commit**

Run: `flutter analyze` — expected 0 issues.

```bash
dart format .
git add -A
git commit -m "feat(dive): show dive name in detail header and search (#400)"
```

---

### Task 6: CSV and UDDF export

**Files:**
- Modify: `lib/core/services/export/csv/csv_export_service.dart` (headers ~line 116, row cells ~line 152)
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart` (informationbeforedive, after `divenumber` ~line 138)
- Test: `test/core/services/export/uddf/uddf_export_builders_test.dart` (extend)
- Create: `test/core/services/export/csv/csv_export_name_test.dart`

**Interfaces:**
- Consumes: `Dive.name` from Task 2.
- Produces: CSV column `Name` (raw name, empty when unset) right after `Dive Number`; UDDF custom element `<divename>` inside `<informationbeforedive>`, omitted when unset.

- [ ] **Step 1: Write the failing UDDF test**

In `test/core/services/export/uddf/uddf_export_builders_test.dart`, add inside the `'UddfExportBuilders.buildDiveElement'` group (mirroring the existing fixture style in that file):

```dart
    test('includes divename in informationbeforedive when the dive is named', () {
      final dive = Dive(
        id: 'dive-named',
        diveNumber: 60,
        dateTime: DateTime(2026, 3, 28, 10, 0),
        name: 'Wreck penetration dive',
      );

      final builder = XmlBuilder();
      builder.element(
        'root',
        nest: () {
          UddfExportBuilders.buildDiveElement(
            builder,
            dive,
            null,
            const [],
            const [],
            const [],
            const [],
            null,
            const [],
          );
        },
      );
      final xml = builder.buildDocument().toXmlString();

      expect(
        xml,
        contains('<divename>Wreck penetration dive</divename>'),
      );
    });

    test('omits divename when the dive is unnamed', () {
      final dive = Dive(id: 'dive-unnamed', dateTime: DateTime(2026, 3, 28));

      final builder = XmlBuilder();
      builder.element(
        'root',
        nest: () {
          UddfExportBuilders.buildDiveElement(
            builder,
            dive,
            null,
            const [],
            const [],
            const [],
            const [],
            null,
            const [],
          );
        },
      );

      expect(
        builder.buildDocument().toXmlString(),
        isNot(contains('<divename>')),
      );
    });
```

- [ ] **Step 2: Write the failing CSV test**

Create `test/core/services/export/csv/csv_export_name_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/csv_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  test('dive CSV export includes a Name column with the raw name', () {
    final dives = [
      Dive(
        id: 'd1',
        diveNumber: 60,
        dateTime: DateTime(2026, 3, 28, 10, 0),
        name: 'Wreck penetration dive',
      ),
      Dive(id: 'd2', diveNumber: 61, dateTime: DateTime(2026, 3, 29, 10, 0)),
    ];

    final csv = CsvExportService().generateDivesCsvContent(dives);
    final lines = csv.trim().split('\n');

    final headers = lines.first.split(',');
    final nameIdx = headers.indexOf('Name');
    expect(nameIdx, 1, reason: 'Name column sits right after Dive Number');

    expect(lines[1], contains('Wreck penetration dive'));
    // Unnamed dive exports an empty cell, never a site fallback.
    expect(lines[2].split(',')[nameIdx], isEmpty);
  });
}
```

- [ ] **Step 3: Run both tests to verify they fail**

Run: `flutter test test/core/services/export/uddf/uddf_export_builders_test.dart test/core/services/export/csv/csv_export_name_test.dart`
Expected: the new tests FAIL (no `<divename>` element; no `Name` header). Pre-existing UDDF tests still pass.

- [ ] **Step 4: Implement the CSV column**

In `lib/core/services/export/csv/csv_export_service.dart`:

a) In the `headers` list, after `'Dive Number',` add `'Name',`
b) In the per-dive row list, after `dive.diveNumber ?? '',` add `dive.name ?? '',`

- [ ] **Step 5: Implement the UDDF element**

In `lib/core/services/export/uddf/uddf_export_builders.dart`, inside the `informationbeforedive` `nest:` block, immediately after the `divenumber` if-block:

```dart
            if (dive.name != null && dive.name!.isNotEmpty) {
              // Custom dive-name extension (not UDDF standard, consistent
              // with the existing custom elements in informationbeforedive).
              builder.element('divename', nest: dive.name);
            }
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/core/services/export/uddf/uddf_export_builders_test.dart test/core/services/export/csv/csv_export_name_test.dart test/core/services/export_service_test.dart`
Expected: PASS.

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add -A
git commit -m "feat(export): dive name in CSV and UDDF exports (#400)"
```

---

### Task 7: Translations and full verification

**Files:**
- Modify: `lib/l10n/arb/app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb` (+ regenerate)

**Interfaces:**
- Consumes: the two l10n keys from Task 4.
- Produces: translated strings in all 10 non-English locales; fully verified branch.

- [ ] **Step 1: Add the translated keys**

In each locale ARB, insert the two keys adjacent to that file's existing `diveLog_edit_label_diveNumber` entry (translation files carry no `@` metadata — plain key/value only):

| File | `diveLog_edit_label_diveName` | `diveLog_edit_diveNamePlaceholder` |
| --- | --- | --- |
| app_ar.arb | "الاسم" | "اسم اختياري لهذه الغطسة" |
| app_de.arb | "Name" | "Optionaler Name für diesen Tauchgang" |
| app_es.arb | "Nombre" | "Nombre opcional para esta inmersión" |
| app_fr.arb | "Nom" | "Nom facultatif pour cette plongée" |
| app_he.arb | "שם" | "שם אופציונלי לצלילה זו" |
| app_hu.arb | "Név" | "Opcionális név ehhez a merüléshez" |
| app_it.arb | "Nome" | "Nome facoltativo per questa immersione" |
| app_nl.arb | "Naam" | "Optionele naam voor deze duik" |
| app_pt.arb | "Nome" | "Nome opcional para este mergulho" |
| app_zh.arb | "名称" | "此次潜水的可选名称" |

Then run: `flutter gen-l10n`
Expected: exits 0, localization classes regenerated.

- [ ] **Step 2: Run the localization test**

Run: `flutter test test/l10n/localization_test.dart`
Expected: PASS (this suite catches missing/extra keys across locales).

- [ ] **Step 3: Full verification sweep**

```bash
dart format .
flutter analyze
```
Expected: format changes nothing new; analyze reports 0 issues.

Then run every test file this feature touched:

```bash
flutter test \
  test/core/database/migration_v94_dive_name_test.dart \
  test/features/dive_log/data/repositories/dive_name_test.dart \
  test/core/constants/dive_field_extractor_test.dart \
  test/core/constants/dive_field_test.dart \
  test/core/constants/dive_field_formatter_test.dart \
  test/features/dive_log/presentation/widgets/the_dive_section_name_test.dart \
  test/core/services/export/uddf/uddf_export_builders_test.dart \
  test/core/services/export/csv/csv_export_name_test.dart \
  test/features/dive_log/presentation/widgets/compact_dive_list_tile_test.dart \
  test/l10n/localization_test.dart
```
Expected: all PASS.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(l10n): translate dive name strings into all locales (#400)"
```

---

## Out of scope (do not implement)

- Bulk edit of names (the bulk-edit values object in `dive_edit_page.dart` stays untouched).
- UDDF/dive-computer import of names (imported dives keep `name` null).
- SQL sorting by name (`DiveField.diveName` is `sortable: false`).
- Auto-generating names from dive type.
