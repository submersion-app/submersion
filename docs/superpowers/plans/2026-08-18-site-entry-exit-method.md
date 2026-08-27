# Site-Level Entry and Exit Method Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Store entry and exit method on a dive site and apply them to a dive when that site is assigned, so divers stop re-entering the same value at sites they visit repeatedly.

**Architecture:** Two nullable TEXT columns on `dive_sites` storing `EntryMethod.name`, edited via `EnumPickerRow` in the site editor's Access and Safety section. A pure function decides the dive form's entry/exit/linked triple when a site is assigned, called only from `_assignSite()`. A history-derived suggestion chip offers to fill empty site fields from the dives already logged there. Sync needs no work because Drift rows serialize wholesale.

**Tech Stack:** Flutter, Drift ORM (SQLite), Riverpod, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-18-site-entry-exit-method-design.md`

## Global Constraints

- **No em-dashes** (U+2014) in any code, comment, doc, or commit message. This is absolute. Use commas, colons, semicolons, or two sentences.
- **No emojis** in code, comments, or documentation.
- `dart format .` must pass with no changes before every commit.
- `flutter analyze` must be clean. Infos are fatal in CI.
- Immutability: never mutate entities in place; use `copyWith`.
- The enum member `SiteField.entryType` must **keep its name**. Renaming an entity-field enum value throws on users' saved table layouts.
- All new user-facing strings need keys in all 11 ARB files: `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`.
- After editing `lib/core/database/database.dart`, run `dart run build_runner build --delete-conflicting-outputs`.
- After editing any ARB file, run `flutter gen-l10n`. The generated `app_localizations*.dart` files are tracked in git and must be committed.
- Do not run overlapping `flutter test` invocations; a concurrent run can produce a phantom lone failure.

---

### Task 1: Database columns and migration

Adds `entry_method` and `exit_method` to `dive_sites` and takes the schema from v153 to v154.

**Files:**
- Modify: `lib/core/database/database.dart` (table at `:828-870`, version at `:3072`, `migrationVersions` tail at `:3292`, helper near `:4716`, `onUpgrade` tail at `:8088`, `beforeOpen` backstop near `:8240`)
- Test: `test/core/database/migration_v154_site_entry_exit_method_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `AppDatabase.currentSchemaVersion == 154`; `dive_sites.entry_method TEXT` and `dive_sites.exit_method TEXT`; `DiveSitesCompanion` gains `entryMethod` and `exitMethod` `Value<String?>` fields via codegen.

- [ ] **Step 1: Write the failing test**

Create `test/core/database/migration_v154_site_entry_exit_method_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('v154 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(154));
    expect(AppDatabase.migrationVersions, contains(154));
  });

  test('a fresh database has the dive_sites entry/exit method columns', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await db.customSelect("PRAGMA table_info('dive_sites')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('entry_method'));
    expect(names, contains('exit_method'));
  });

  test(
    'a database stranded before v154 gains both columns via beforeOpen',
    () async {
      // Only the columns this migration touches are modelled. The beforeOpen
      // backstop must add them even when onUpgrade never ran, which happens
      // when a parallel branch already stamped this version number.
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('''
          CREATE TABLE dive_sites (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            water_type TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        },
      );
      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final cols =
          await db.customSelect("PRAGMA table_info('dive_sites')").get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, contains('entry_method'));
      expect(names, contains('exit_method'));
    },
  );

  test('the assert is a no-op when the dive_sites table is absent', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('CREATE TABLE unrelated (id TEXT)');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    // Opening must not throw on a minimal fixture.
    await db.customSelect('SELECT 1').get();
  });

  test('the assert is idempotent on an already-migrated database', () async {
    // beforeOpen re-runs the helper on every open, so a healthy database must
    // survive the second pass rather than failing on a duplicate column.
    final nativeDb = NativeDatabase.memory();
    final first = AppDatabase(nativeDb);
    await first.customSelect('SELECT 1').get();
    await first.close();

    final second = AppDatabase(NativeDatabase.memory());
    addTearDown(second.close);
    await second.customSelect('SELECT 1').get();

    final cols =
        await second.customSelect("PRAGMA table_info('dive_sites')").get();
    final names = cols.map((c) => c.read<String>('name')).toList();
    expect(names.where((n) => n == 'entry_method').length, 1);
    expect(names.where((n) => n == 'exit_method').length, 1);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/database/migration_v154_site_entry_exit_method_test.dart`
Expected: FAIL. The ladder test fails because `currentSchemaVersion` is 153, and the column tests fail because the columns do not exist.

- [ ] **Step 3: Add the columns to the table definition**

In `lib/core/database/database.dart`, in `class DiveSites extends Table`, immediately after the `altitude` column and before `isShared`:

```dart
  /// Typical entry and exit method at this site, stored as EntryMethod.name
  /// (issue #1104). Snapped onto a dive when the site is assigned.
  TextColumn get entryMethod => text().nullable()();
  TextColumn get exitMethod => text().nullable()();
```

- [ ] **Step 4: Bump the schema version and the ladder**

Change `static const int currentSchemaVersion = 153;` to `154`.

Append to the end of the `migrationVersions` list, after the `153,` entry:

```dart
    // v154 (issue #1104): dive_sites.entry_method / exit_method, the site's
    // typical way in and out of the water.
    154,
```

- [ ] **Step 5: Add the idempotent assert helper**

In `lib/core/database/database.dart`, directly after `_assertO2CellMillivoltColumns()`:

```dart
  /// Site-level entry/exit method columns on dive_sites (issue #1104).
  /// PRAGMA-guarded so a healthy database no-ops and a partial schema does
  /// not throw.
  Future<void> _assertSiteEntryExitMethodColumns() async {
    final cols = await customSelect("PRAGMA table_info('dive_sites')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('entry_method')) {
      await customStatement(
        'ALTER TABLE dive_sites ADD COLUMN entry_method TEXT',
      );
    }
    if (!names.contains('exit_method')) {
      await customStatement(
        'ALTER TABLE dive_sites ADD COLUMN exit_method TEXT',
      );
    }
  }
```

- [ ] **Step 6: Call it from onUpgrade and from the beforeOpen backstop**

In `onUpgrade`, after the `if (from < 153) await reportProgress();` line:

```dart
        // v154: site-level entry/exit method (issue #1104).
        if (from < 154) {
          await _assertSiteEntryExitMethodColumns();
        }
        if (from < 154) await reportProgress();
```

In `beforeOpen`, after the `_assertO2CellMillivoltColumns();` backstop call:

```dart
        // v154 backstop: re-assert the site entry/exit method columns (issue
        // #1104; same parallel-branch version-collision self-heal).
        await _assertSiteEntryExitMethodColumns();
```

- [ ] **Step 7: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `database.g.dart` regenerates with `entryMethod` and `exitMethod` on `DiveSite` (the Drift row class) and `DiveSitesCompanion`.

- [ ] **Step 8: Run the test to verify it passes**

Run: `flutter test test/core/database/migration_v154_site_entry_exit_method_test.dart`
Expected: PASS, all four tests.

- [ ] **Step 9: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/database/database.dart lib/core/database/database.g.dart test/core/database/migration_v154_site_entry_exit_method_test.dart
git commit -m "feat(db): add dive_sites entry_method and exit_method (v154, #1104)"
```

---

### Task 2: Domain entity and repository mapping

Carries the two columns through `DiveSite` and every read/write path in the site repository.

**Files:**
- Modify: `lib/features/dive_sites/domain/entities/dive_site.dart` (fields `:44`, ctor `:71`, `copyWith` `:135`/`:161`, `props` `:190`)
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart` (companions at `:106`, `:179`, `:611`, `:855`; `_mapRowToSite` at `:826`)
- Test: `test/features/dive_sites/domain/entities/dive_site_entry_exit_test.dart`

**Interfaces:**
- Consumes: `dive_sites.entry_method` / `exit_method` columns from Task 1.
- Produces: `DiveSite.entryMethod` and `DiveSite.exitMethod`, both `EntryMethod?`, settable through the constructor and `copyWith`, persisted and hydrated by `SiteRepositoryImpl`.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_sites/domain/entities/dive_site_entry_exit_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  group('DiveSite entry/exit method', () {
    test('defaults to null', () {
      const site = DiveSite(id: 's', name: 'S');
      expect(site.entryMethod, isNull);
      expect(site.exitMethod, isNull);
    });

    test('round-trips through the constructor', () {
      const site = DiveSite(
        id: 's',
        name: 'S',
        entryMethod: EntryMethod.giantStride,
        exitMethod: EntryMethod.ladder,
      );
      expect(site.entryMethod, EntryMethod.giantStride);
      expect(site.exitMethod, EntryMethod.ladder);
    });

    test('copyWith sets both fields', () {
      const site = DiveSite(id: 's', name: 'S');
      final updated = site.copyWith(
        entryMethod: EntryMethod.boat,
        exitMethod: EntryMethod.ladder,
      );
      expect(updated.entryMethod, EntryMethod.boat);
      expect(updated.exitMethod, EntryMethod.ladder);
    });

    test('copyWith preserves both fields when they are not passed', () {
      const site = DiveSite(
        id: 's',
        name: 'S',
        entryMethod: EntryMethod.shore,
        exitMethod: EntryMethod.shore,
      );
      final updated = site.copyWith(name: 'Renamed');
      expect(updated.entryMethod, EntryMethod.shore);
      expect(updated.exitMethod, EntryMethod.shore);
    });

    test('equality distinguishes sites by entry method', () {
      const a = DiveSite(id: 's', name: 'S', entryMethod: EntryMethod.boat);
      const b = DiveSite(id: 's', name: 'S', entryMethod: EntryMethod.shore);
      expect(a, isNot(equals(b)));
    });

    test('equality distinguishes sites by exit method', () {
      const a = DiveSite(id: 's', name: 'S', exitMethod: EntryMethod.ladder);
      const b = DiveSite(id: 's', name: 'S', exitMethod: EntryMethod.platform);
      expect(a, isNot(equals(b)));
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_sites/domain/entities/dive_site_entry_exit_test.dart`
Expected: FAIL, compile error, `No named parameter with the name 'entryMethod'`.

- [ ] **Step 3: Add the fields to the entity**

In `lib/features/dive_sites/domain/entities/dive_site.dart`, after the `altitude` field declaration and before `conditions`:

```dart
  /// Typical way into the water at this site (issue #1104). Snapped onto a
  /// dive when the site is assigned; the diver can always override it.
  final EntryMethod? entryMethod;

  /// Typical way out of the water at this site. Null means "same as entry".
  final EntryMethod? exitMethod;
```

In the constructor, after `this.altitude,`:

```dart
    this.entryMethod,
    this.exitMethod,
```

In `copyWith`'s parameter list, after `double? altitude,`:

```dart
    EntryMethod? entryMethod,
    EntryMethod? exitMethod,
```

In `copyWith`'s returned `DiveSite(...)`, after `altitude: altitude ?? this.altitude,`:

```dart
      entryMethod: entryMethod ?? this.entryMethod,
      exitMethod: exitMethod ?? this.exitMethod,
```

In `props`, after `altitude,`:

```dart
    entryMethod,
    exitMethod,
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_sites/domain/entities/dive_site_entry_exit_test.dart`
Expected: PASS, all six tests.

- [ ] **Step 5: Add the fields to all four companion builders**

In `lib/features/dive_sites/data/repositories/site_repository_impl.dart`, add these two lines immediately after every existing `altitude: Value(site.altitude),` line. There are four of them, in `createSite` (near `:118`), `_writeSiteUpdate` (near `:179`), the restore/undo-merge insert (near `:611`), and `_updateSiteRow` (near `:855`):

```dart
              entryMethod: Value(site.entryMethod?.name),
              exitMethod: Value(site.exitMethod?.name),
```

Match the surrounding indentation at each site; it differs between the four.

Verify you found all four:

```bash
grep -c 'entryMethod: Value(site.entryMethod?.name)' lib/features/dive_sites/data/repositories/site_repository_impl.dart
```

Expected output: `4`

- [ ] **Step 6: Hydrate the fields in `_mapRowToSite`**

In the same file, in `_mapRowToSite`, after `altitude: row.altitude,`:

```dart
      entryMethod: row.entryMethod == null
          ? null
          : EntryMethod.values.asNameMap()[row.entryMethod],
      exitMethod: row.exitMethod == null
          ? null
          : EntryMethod.values.asNameMap()[row.exitMethod],
```

`EntryMethod` comes from `package:submersion/core/constants/enums.dart`, which this file already imports for `WaterType`. Confirm with `grep -n "core/constants/enums.dart" lib/features/dive_sites/data/repositories/site_repository_impl.dart` and add the import if it is missing.

- [ ] **Step 7: Write the persistence round-trip test**

Append to `test/features/dive_sites/domain/entities/dive_site_entry_exit_test.dart`, inside `main()`:

```dart
  group('DiveSite persistence round-trip', () {
    test('a site saved with both methods reads back with both', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = SiteRepositoryImpl(db, SyncRepository(db));

      final id = await repo.createSite(
        const DiveSite(
          id: '',
          name: 'Blue Hole',
          entryMethod: EntryMethod.boat,
          exitMethod: EntryMethod.ladder,
        ),
      );

      final loaded = await repo.getSiteById(id);
      expect(loaded!.entryMethod, EntryMethod.boat);
      expect(loaded.exitMethod, EntryMethod.ladder);
    });

    test('an updated site persists a changed entry method', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = SiteRepositoryImpl(db, SyncRepository(db));

      final id = await repo.createSite(
        const DiveSite(id: '', name: 'Shore Spot'),
      );
      final created = await repo.getSiteById(id);
      await repo.updateSite(
        created!.copyWith(entryMethod: EntryMethod.shore),
      );

      final loaded = await repo.getSiteById(id);
      expect(loaded!.entryMethod, EntryMethod.shore);
      expect(loaded.exitMethod, isNull);
    });
  });
```

Add these imports at the top of the file:

```dart
import 'package:drift/native.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
```

If `SiteRepositoryImpl`'s or `SyncRepository`'s constructor signature differs from the two-argument form above, read the constructor and adjust. Confirm with:

```bash
grep -n "SiteRepositoryImpl(" lib/features/dive_sites/data/repositories/site_repository_impl.dart | head -3
grep -rn "SiteRepositoryImpl(" test | head -3
```

Prefer whatever construction the existing tests use.

- [ ] **Step 8: Write the sync serialization round-trip test**

Sync serializes whole Drift rows with `row.toJson()` (`lib/core/services/sync/sync_data_serializer.dart`), so new columns ride along without per-field registration. This test is what guarantees that stays true.

Create `test/core/services/sync/dive_site_entry_exit_sync_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

void main() {
  test('a dive_sites row carries entry/exit method through toJson', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 'site-1',
            name: 'Blue Hole',
            createdAt: 0,
            updatedAt: 0,
            entryMethod: const Value('boat'),
            exitMethod: const Value('ladder'),
          ),
        );

    final row = await (db.select(
      db.diveSites,
    )..where((t) => t.id.equals('site-1'))).getSingle();

    final json = row.toJson();
    expect(json['entryMethod'], 'boat');
    expect(json['exitMethod'], 'ladder');

    final restored = DiveSite.fromJson(json);
    expect(restored.entryMethod, 'boat');
    expect(restored.exitMethod, 'ladder');
  });
}
```

`DiveSite` here is the **Drift row class** from `database.dart`, not the domain entity. Do not import the domain entity in this file. Add `import 'package:drift/drift.dart' show Value;` if `Value` is not already in scope. If `DiveSitesCompanion.insert` requires other non-nullable columns, add them; the analyzer will name them.

Run: `flutter test test/core/services/sync/dive_site_entry_exit_sync_test.dart`
Expected: PASS.

- [ ] **Step 9: Run the tests to verify they pass**

Run: `flutter test test/features/dive_sites/domain/entities/dive_site_entry_exit_test.dart`
Expected: PASS, all eight tests.

- [ ] **Step 10: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_sites/domain/entities/dive_site.dart lib/features/dive_sites/data/repositories/site_repository_impl.dart test/features/dive_sites/domain/entities/dive_site_entry_exit_test.dart test/core/services/sync/dive_site_entry_exit_sync_test.dart
git commit -m "feat(sites): carry entry/exit method through the site entity and repository (#1104)"
```

---

### Task 3: The snap rule

A pure function deciding the dive form's entry, exit, and linked state when a site is assigned. No UI in this task.

**Files:**
- Create: `lib/features/dive_log/presentation/utils/entry_exit_autofill.dart`
- Test: `test/features/dive_log/presentation/utils/entry_exit_autofill_test.dart`

**Interfaces:**
- Consumes: `DiveSite.entryMethod` / `DiveSite.exitMethod` from Task 2.
- Produces: `EntryExitSelection` (fields `entry`, `exit`, `linked`) and `EntryExitSelection entryExitAfterSiteAssign({required EntryMethod? currentEntry, required EntryMethod? currentExit, required bool currentLinked, required DiveSite? site})`.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/utils/entry_exit_autofill_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/utils/entry_exit_autofill.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  DiveSite site({EntryMethod? entry, EntryMethod? exit}) =>
      DiveSite(id: 's', name: 'S', entryMethod: entry, exitMethod: exit);

  group('entryExitAfterSiteAssign', () {
    test('clearing the site changes nothing', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: EntryMethod.shore,
        currentExit: EntryMethod.shore,
        currentLinked: true,
        site: null,
      );
      expect(result.entry, EntryMethod.shore);
      expect(result.exit, EntryMethod.shore);
      expect(result.linked, isTrue);
    });

    test('clearing the site never materializes an exit method', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: EntryMethod.shore,
        currentExit: null,
        currentLinked: true,
        site: null,
      );
      expect(result.entry, EntryMethod.shore);
      expect(result.exit, isNull);
    });

    test('a site with neither value changes nothing', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: EntryMethod.shore,
        currentExit: null,
        currentLinked: true,
        site: site(),
      );
      expect(result.entry, EntryMethod.shore);
      expect(result.exit, isNull);
    });

    test('a site entry method snaps and a linked exit follows it', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: EntryMethod.shore,
        currentExit: EntryMethod.shore,
        currentLinked: true,
        site: site(entry: EntryMethod.boat),
      );
      expect(result.entry, EntryMethod.boat);
      expect(result.exit, EntryMethod.boat);
      expect(result.linked, isTrue);
    });

    test('a manual exit override survives a site entry method', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: EntryMethod.shore,
        currentExit: EntryMethod.ladder,
        currentLinked: false,
        site: site(entry: EntryMethod.boat),
      );
      expect(result.entry, EntryMethod.boat);
      expect(result.exit, EntryMethod.ladder);
      expect(result.linked, isFalse);
    });

    test('a manual exit override survives an explicit site exit method', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: EntryMethod.shore,
        currentExit: EntryMethod.ladder,
        currentLinked: false,
        site: site(entry: EntryMethod.boat, exit: EntryMethod.boat),
      );
      expect(result.entry, EntryMethod.boat);
      expect(result.exit, EntryMethod.ladder);
      expect(result.linked, isFalse);
    });

    test('a differing site pair snaps both and breaks the link', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: EntryMethod.shore,
        currentExit: EntryMethod.shore,
        currentLinked: true,
        site: site(entry: EntryMethod.giantStride, exit: EntryMethod.ladder),
      );
      expect(result.entry, EntryMethod.giantStride);
      expect(result.exit, EntryMethod.ladder);
      expect(result.linked, isFalse);
    });

    test('a new dive with nothing set takes the whole site pair', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: null,
        currentExit: null,
        currentLinked: true,
        site: site(entry: EntryMethod.giantStride, exit: EntryMethod.ladder),
      );
      expect(result.entry, EntryMethod.giantStride);
      expect(result.exit, EntryMethod.ladder);
      expect(result.linked, isFalse);
    });

    test('a site exit method alone applies without touching entry', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: EntryMethod.shore,
        currentExit: EntryMethod.shore,
        currentLinked: true,
        site: site(exit: EntryMethod.ladder),
      );
      expect(result.entry, EntryMethod.shore);
      expect(result.exit, EntryMethod.ladder);
      expect(result.linked, isFalse);
    });

    test('linked is true when the resulting exit is null', () {
      final result = entryExitAfterSiteAssign(
        currentEntry: null,
        currentExit: null,
        currentLinked: true,
        site: site(),
      );
      expect(result.exit, isNull);
      expect(result.linked, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/utils/entry_exit_autofill_test.dart`
Expected: FAIL, `Target of URI doesn't exist: 'entry_exit_autofill.dart'`.

- [ ] **Step 3: Write the implementation**

Create `lib/features/dive_log/presentation/utils/entry_exit_autofill.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// The dive form's entry method, exit method, and link flag as one value, so
/// the flag can never drift out of step with the two methods it describes.
class EntryExitSelection {
  const EntryExitSelection({
    required this.entry,
    required this.exit,
    required this.linked,
  });

  final EntryMethod? entry;
  final EntryMethod? exit;

  /// True when exit is unset or equal to entry, matching the dive form's
  /// own definition of "the diver has not broken the mirror".
  final bool linked;
}

/// The dive's entry/exit selection after [site] is assigned to it.
///
/// Snap-on-assign, with three rules in priority order:
///
/// 1. A manual exit override is sticky. Once the diver has unlinked exit from
///    entry, no site value replaces it. The site knows the place; it does not
///    know how the diver got out that day.
/// 2. An explicit site exit method applies to a still-linked dive.
/// 3. A still-linked exit follows the new entry, but only when the entry
///    actually changed. Without that guard, clearing the site or assigning a
///    site with no entry method would write exit = entry and materialize an
///    exit method on a dive that had none.
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
    exit = currentExit;
  } else if (site?.exitMethod != null) {
    exit = site!.exitMethod;
  } else if (entryChanged) {
    exit = entry;
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

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/utils/entry_exit_autofill_test.dart`
Expected: PASS, all ten tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/presentation/utils/entry_exit_autofill.dart test/features/dive_log/presentation/utils/entry_exit_autofill_test.dart
git commit -m "feat(dives): add the site entry/exit snap rule (#1104)"
```

---

### Task 4: Apply the snap rule in the dive edit form

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (`_assignSite` at `:2096-2104`)
- Test: `test/features/dive_log/presentation/pages/dive_edit_site_entry_method_test.dart`

**Interfaces:**
- Consumes: `entryExitAfterSiteAssign` and `EntryExitSelection` from Task 3.
- Produces: assigning a site in the dive editor updates `_entryMethod`, `_exitMethod`, and `_exitMethodLinked`.

- [ ] **Step 1: Write the failing widget test**

Create `test/features/dive_log/presentation/pages/dive_edit_site_entry_method_test.dart`. Model it on the nearest existing dive-edit widget test so the provider overrides and pump helpers match. Find one first:

```bash
ls test/features/dive_log/presentation/pages/ | grep dive_edit
```

The test must:

1. Pump the dive edit page for a new dive, with a site in the repository carrying `entryMethod: EntryMethod.boat` and `exitMethod: EntryMethod.ladder`.
2. Open the site picker and select that site.
3. Assert the Entry Method row reads "Boat Entry" and the Exit Method row reads "Ladder".

```dart
testWidgets('assigning a site snaps its entry and exit method', (tester) async {
  await pumpDiveEditPage(tester, sites: [
    const DiveSite(
      id: 'site-1',
      name: 'Blue Hole',
      entryMethod: EntryMethod.boat,
      exitMethod: EntryMethod.ladder,
    ),
  ]);

  await selectSite(tester, 'Blue Hole');
  await tester.pumpAndSettle();

  expect(find.text('Boat Entry'), findsOneWidget);
  expect(find.text('Ladder'), findsOneWidget);
});
```

`pumpDiveEditPage` and `selectSite` are placeholders for whatever the existing dive-edit tests use. Read the neighboring test file and reuse its helpers verbatim rather than writing new ones.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_site_entry_method_test.dart`
Expected: FAIL. The site is assigned but the entry and exit rows still read "Not specified".

- [ ] **Step 3: Wire the rule into `_assignSite`**

In `lib/features/dive_log/presentation/pages/dive_edit_page.dart`, replace `_assignSite` and its doc comment:

```dart
  /// Assigns [site] to the dive and snaps the water type and the entry/exit
  /// methods from it (manual overrides survive; see the rules on
  /// [entryExitAfterSiteAssign]). Use for user-initiated assignments and
  /// new-dive prefill, NOT the load path, which restores the dive's own
  /// saved values.
  void _assignSite(DiveSite? site) {
    _selectedSite = site;
    _waterType = waterTypeAfterSiteAssign(_waterType, site);
    final entryExit = entryExitAfterSiteAssign(
      currentEntry: _entryMethod,
      currentExit: _exitMethod,
      currentLinked: _exitMethodLinked,
      site: site,
    );
    _entryMethod = entryExit.entry;
    _exitMethod = entryExit.exit;
    _exitMethodLinked = entryExit.linked;
    unawaited(_maybeAutoFillAltitude());
  }
```

Add the import alongside the existing `water_type_autofill.dart` import:

```dart
import 'package:submersion/features/dive_log/presentation/utils/entry_exit_autofill.dart';
```

`_assignSite` is called from five places, all user-initiated, and all of them must keep calling it: `_applyPrefill()` (`:523`), clear site (`:1859`), site created from photo GPS (`:2044`), the site picker (`:2123`), and the create-new-site return (`:2141`). Do not change the load path at `:664`; it deliberately assigns `_selectedSite` directly so reopening a saved dive never re-snaps it.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/pages/dive_edit_site_entry_method_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the surrounding dive edit tests for regressions**

Run: `flutter test test/features/dive_log/presentation/pages/`
Expected: PASS. `_assignSite` is on the site-picking path, so any test that picks a site now also runs the new rule.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/presentation/pages/dive_edit_site_entry_method_test.dart
git commit -m "feat(dives): snap entry/exit method from the assigned site (#1104)"
```

---

### Task 5: Localization keys

All strings the remaining tasks need, added once so no later task is blocked on translation.

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb` (11 files)
- Modify (generated, commit them): `lib/l10n/app_localizations*.dart`

**Interfaces:**
- Produces: `l10n.diveSites_edit_access_entryMethod_label`, `l10n.diveSites_edit_access_exitMethod_label`, `l10n.diveSites_detail_access_entryMethod`, `l10n.diveSites_detail_access_exitMethod`, `l10n.diveSites_edit_access_entrySuggestionPair(count, entry, exit)`, `l10n.diveSites_edit_access_entrySuggestionEntryOnly(count, entry)`.

- [ ] **Step 1: Add the English keys**

In `lib/l10n/arb/app_en.arb`, add these entries in the correct alphabetical position among the other `diveSites_edit_access_*` keys:

```json
  "diveSites_edit_access_entryMethod_label": "Entry Method",
  "@diveSites_edit_access_entryMethod_label": {
    "description": "Site form row: the typical way into the water at this site"
  },
  "diveSites_edit_access_exitMethod_label": "Exit Method",
  "@diveSites_edit_access_exitMethod_label": {
    "description": "Site form row: the typical way out of the water at this site"
  },
  "diveSites_edit_access_entrySuggestionPair": "{count, plural, one{Your dive here: {entry} in, {exit} out} other{Your {count} dives here: {entry} in, {exit} out}}",
  "@diveSites_edit_access_entrySuggestionPair": {
    "description": "Chip offering to fill a site's entry and exit method from the dives already logged there",
    "placeholders": {
      "count": { "type": "int" },
      "entry": { "type": "String" },
      "exit": { "type": "String" }
    }
  },
  "diveSites_edit_access_entrySuggestionEntryOnly": "{count, plural, one{Your dive here: {entry}} other{Your {count} dives here: {entry}}}",
  "@diveSites_edit_access_entrySuggestionEntryOnly": {
    "description": "Chip offering to fill a site's entry method when the logged dives record no exit method",
    "placeholders": {
      "count": { "type": "int" },
      "entry": { "type": "String" }
    }
  },
```

And among the `diveSites_detail_access_*` keys:

```json
  "diveSites_detail_access_entryMethod": "Entry",
  "@diveSites_detail_access_entryMethod": {
    "description": "Site detail access card: entry method row label"
  },
  "diveSites_detail_access_exitMethod": "Exit",
  "@diveSites_detail_access_exitMethod": {
    "description": "Site detail access card: exit method row label"
  },
```

- [ ] **Step 2: Translate into the other 10 locales**

Add the same six keys to `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, and `app_zh.arb`, translated. Only `app_en.arb` carries the `@key` metadata blocks; the other locales carry the bare key/value pairs, matching how the existing keys are structured in those files. Confirm that convention first:

```bash
grep -c '"@diveSites_edit_group_accessSafety"' lib/l10n/arb/app_de.arb
```

If the count is 0, the other locales carry no metadata and you should follow that. If it is 1, include the metadata everywhere.

Keep the ICU plural structure intact in every locale. Arabic needs the full plural category set its existing plural keys use; copy the shape from a neighboring plural key in `app_ar.arb` rather than inventing it.

- [ ] **Step 3: Regenerate and verify**

```bash
flutter gen-l10n
grep -c 'diveSites_edit_access_entryMethod_label' lib/l10n/app_localizations.dart
```

Expected: at least `1`. If `flutter gen-l10n` reports missing translations for any locale, add them before proceeding.

- [ ] **Step 4: Analyze and commit**

```bash
dart format .
flutter analyze
git add lib/l10n/
git commit -m "i18n: add site entry/exit method strings (#1104)"
```

---

### Task 6: Site editor rows

Adds the two pickers to the Access and Safety section, without merge support.

**Files:**
- Modify: `lib/features/dive_sites/presentation/widgets/edit_sections/access_safety_section.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart` (state near `:95`, seed near `:274`, `_accessSummary` at `:779`, section wiring at `:889`, save at `:1420`)
- Test: `test/features/dive_sites/presentation/pages/site_edit_entry_method_test.dart`

**Interfaces:**
- Consumes: `DiveSite.entryMethod` / `exitMethod` (Task 2), the l10n keys (Task 5).
- Produces: `AccessSafetySection` gains required `entryMethod`, `exitMethod`, `onEntryMethodChanged`, `onExitMethodChanged` parameters and optional `entryMethodExtras`, `exitMethodExtras`. `_SiteEditPageState` gains `_entryMethod` and `_exitMethod`.

- [ ] **Step 1: Write the failing widget test**

Create `test/features/dive_sites/presentation/pages/site_edit_entry_method_test.dart`. Reuse the pump helper from `test/features/dive_sites/presentation/pages/site_edit_page_test.dart`; read that file first and copy its setup exactly.

```dart
testWidgets('the access section shows entry and exit method rows',
    (tester) async {
  await pumpSiteEditPage(tester);
  await expandAccessSection(tester);

  expect(find.text('Entry Method'), findsOneWidget);
  expect(find.text('Exit Method'), findsOneWidget);
});

testWidgets('an existing site seeds both pickers', (tester) async {
  await pumpSiteEditPage(
    tester,
    site: const DiveSite(
      id: 'site-1',
      name: 'Blue Hole',
      entryMethod: EntryMethod.boat,
      exitMethod: EntryMethod.ladder,
    ),
  );
  await expandAccessSection(tester);

  expect(find.text('Boat Entry'), findsOneWidget);
  expect(find.text('Ladder'), findsOneWidget);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/pages/site_edit_entry_method_test.dart`
Expected: FAIL, `Expected: exactly one matching candidate, Actual: _TextFinder:<zero widgets>`.

- [ ] **Step 3: Add the parameters and rows to the section**

In `lib/features/dive_sites/presentation/widgets/edit_sections/access_safety_section.dart`, add to the constructor after `required this.hazardsController,`:

```dart
    required this.entryMethod,
    required this.exitMethod,
    required this.onEntryMethodChanged,
    required this.onExitMethodChanged,
    this.entryMethodExtras,
    this.exitMethodExtras,
```

Add to the field declarations after `final TextEditingController hazardsController;`:

```dart
  final EntryMethod? entryMethod;
  final EntryMethod? exitMethod;
  final ValueChanged<EntryMethod?> onEntryMethodChanged;
  final ValueChanged<EntryMethod?> onExitMethodChanged;

  /// Dedicated merge affordances. These cannot go through [mergeExtras],
  /// which resolves through the page's text-controller candidate map.
  final MergeFieldExtras? entryMethodExtras;
  final MergeFieldExtras? exitMethodExtras;
```

Add a private builder next to `_row`:

```dart
  Widget _methodRow(
    BuildContext context, {
    required String label,
    required EntryMethod? value,
    required ValueChanged<EntryMethod?> onChanged,
    required MergeFieldExtras? extras,
  }) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (extras != null)
          MergeSourceRow(
            sourceLabel: extras.sourceLabel,
            onCycle: extras.onCycle,
          ),
        EnumPickerRow<EntryMethod>(
          label: label,
          value: value,
          values: EntryMethod.values,
          displayName: (v) => v.localizedName(l10n),
          onChanged: onChanged,
        ),
      ],
    );
  }
```

Insert the two rows in `build`'s `children`, immediately after the `accessNotes` row and before `mooringNumber`, so the section reads "how to get there, how you get in, how you get out, then the logistics":

```dart
        _methodRow(
          context,
          label: l10n.diveSites_edit_access_entryMethod_label,
          value: entryMethod,
          onChanged: onEntryMethodChanged,
          extras: entryMethodExtras,
        ),
        _methodRow(
          context,
          label: l10n.diveSites_edit_access_exitMethod_label,
          value: exitMethod,
          onChanged: onExitMethodChanged,
          extras: exitMethodExtras,
        ),
```

Add these imports:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/shared/widgets/forms/enum_picker_row.dart';
```

- [ ] **Step 4: Add page state, seeding, summary, wiring, and save**

In `lib/features/dive_sites/presentation/pages/site_edit_page.dart`:

State, next to `WaterType? _waterType;`:

```dart
  EntryMethod? _entryMethod;
  EntryMethod? _exitMethod;
```

Seeding, in `_initializeFromSite`, next to `_waterType = site.waterType;`:

```dart
    _entryMethod = site.entryMethod;
    _exitMethod = site.exitMethod;
```

Summary, in `_accessSummary()`, as the second and third entries in the list, right after the `accessNotes` entry:

```dart
    if (_entryMethod != null) _entryMethod!.localizedName(context.l10n),
    if (_exitMethod != null && _exitMethod != _entryMethod)
      _exitMethod!.localizedName(context.l10n),
```

The `_exitMethod != _entryMethod` guard keeps the summary from reading "Boat Entry · Boat Entry" for the common mirrored case.

Section wiring, in the `AccessSafetySection(...)` call:

```dart
            entryMethod: _entryMethod,
            exitMethod: _exitMethod,
            onEntryMethodChanged: (value) => setState(() {
              _entryMethod = value;
              _hasChanges = true;
            }),
            onExitMethodChanged: (value) => setState(() {
              _exitMethod = value;
              _hasChanges = true;
            }),
```

Save, in the `DiveSite(...)` constructor next to `waterType: _waterType,`:

```dart
        entryMethod: _entryMethod,
        exitMethod: _exitMethod,
```

Add the imports for `EntryMethod` and `EntryMethodDisplay` if the file does not already have them.

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/dive_sites/presentation/pages/site_edit_entry_method_test.dart`
Expected: PASS, both tests.

- [ ] **Step 6: Run the site editor suite for regressions**

Run: `flutter test test/features/dive_sites/`
Expected: PASS. `AccessSafetySection` gained four required parameters, so every existing construction of it must be updated. If any test fails to compile, add the four parameters there.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_sites/ test/features/dive_sites/
git commit -m "feat(sites): edit entry and exit method in the access section (#1104)"
```

---

### Task 7: Site editor merge mode

Ten pieces, five per field, so merging two sites lets the diver cycle through each source's value.

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart` (candidates near `:110`, `_initializeFromMerge` near `:418`, extras near `:720`, cycle near `:1118`, wiring near `:889`)
- Test: `test/features/dive_sites/presentation/pages/site_edit_merge_entry_method_test.dart`

**Interfaces:**
- Consumes: `AccessSafetySection.entryMethodExtras` / `exitMethodExtras` from Task 6.
- Produces: merge-mode cycling for both fields.

- [ ] **Step 1: Write the failing widget test**

Create `test/features/dive_sites/presentation/pages/site_edit_merge_entry_method_test.dart`, modeled on the existing water-type merge test at `test/features/dive_sites/presentation/pages/site_edit_merge_page_test.dart:152-200`. Read that test and copy its harness.

```dart
testWidgets('cycling entry method walks the merge candidates',
    (tester) async {
  await pumpSiteMergePage(tester, sites: const [
    DiveSite(id: 'a', name: 'A', entryMethod: EntryMethod.boat),
    DiveSite(id: 'b', name: 'B', entryMethod: EntryMethod.shore),
  ]);
  await expandAccessSection(tester);

  expect(find.text('Boat Entry'), findsOneWidget);

  await tester.tap(cycleButtonFor(tester, 'Entry Method'));
  await tester.pumpAndSettle();

  expect(find.text('Shore Entry'), findsOneWidget);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/pages/site_edit_merge_entry_method_test.dart`
Expected: FAIL. There is no cycle button next to the Entry Method row.

- [ ] **Step 3: Add the candidate lists**

Next to `List<_MergeFieldCandidate<WaterType?>> _waterTypeCandidates = [];`:

```dart
  List<_MergeFieldCandidate<EntryMethod?>> _entryMethodCandidates = [];
  List<_MergeFieldCandidate<EntryMethod?>> _exitMethodCandidates = [];
```

- [ ] **Step 4: Build the candidates in `_initializeFromMerge`**

Immediately after the existing water type block:

```dart
    _entryMethodCandidates = _buildDistinctCandidates<EntryMethod?>(
      data.sites,
      (site) => site.entryMethod,
      equals: (a, b) => a == b,
    );
    _mergeFieldIndices['entryMethod'] = _firstMeaningfulIndex(
      _entryMethodCandidates,
      (value) => value != null,
    );
    _entryMethod =
        _entryMethodCandidates[_mergeFieldIndices['entryMethod'] ?? 0].value;

    _exitMethodCandidates = _buildDistinctCandidates<EntryMethod?>(
      data.sites,
      (site) => site.exitMethod,
      equals: (a, b) => a == b,
    );
    _mergeFieldIndices['exitMethod'] = _firstMeaningfulIndex(
      _exitMethodCandidates,
      (value) => value != null,
    );
    _exitMethod =
        _exitMethodCandidates[_mergeFieldIndices['exitMethod'] ?? 0].value;
```

Do **not** add `entryMethod` or `exitMethod` to `_selectTextFieldCandidate`'s `switch (key)` at `:1064`. That switch handles `TextEditingController`s only, and the omission is deliberate. Add a comment there so a future reader does not "fix" it:

```dart
    // Enum-valued merge fields (difficulty, waterType, entryMethod,
    // exitMethod, rating) are cycled by their own _cycleX methods and are
    // deliberately absent from this controller-backed switch.
```

- [ ] **Step 5: Add the extras builders**

Immediately after `_waterTypeExtras()`:

```dart
  MergeFieldExtras? _entryMethodExtras() {
    if (!widget.isMerging || _entryMethodCandidates.length < 2) return null;
    final index = _mergeFieldIndices['entryMethod'] ?? 0;
    return MergeFieldExtras(
      sourceLabel: context.l10n.diveSites_edit_merge_fieldSourceLabel(
        _entryMethodCandidates[index].siteName,
        index + 1,
        _entryMethodCandidates.length,
      ),
      onCycle: _cycleEntryMethod,
    );
  }

  MergeFieldExtras? _exitMethodExtras() {
    if (!widget.isMerging || _exitMethodCandidates.length < 2) return null;
    final index = _mergeFieldIndices['exitMethod'] ?? 0;
    return MergeFieldExtras(
      sourceLabel: context.l10n.diveSites_edit_merge_fieldSourceLabel(
        _exitMethodCandidates[index].siteName,
        index + 1,
        _exitMethodCandidates.length,
      ),
      onCycle: _cycleExitMethod,
    );
  }
```

- [ ] **Step 6: Add the cycle methods**

Immediately after `_cycleWaterType()`:

```dart
  void _cycleEntryMethod() {
    if (_entryMethodCandidates.length < 2) return;
    setState(() {
      final nextIndex =
          ((_mergeFieldIndices['entryMethod'] ?? 0) + 1) %
          _entryMethodCandidates.length;
      _mergeFieldIndices['entryMethod'] = nextIndex;
      _entryMethod = _entryMethodCandidates[nextIndex].value;
      _hasChanges = true;
    });
  }

  void _cycleExitMethod() {
    if (_exitMethodCandidates.length < 2) return;
    setState(() {
      final nextIndex =
          ((_mergeFieldIndices['exitMethod'] ?? 0) + 1) %
          _exitMethodCandidates.length;
      _mergeFieldIndices['exitMethod'] = nextIndex;
      _exitMethod = _exitMethodCandidates[nextIndex].value;
      _hasChanges = true;
    });
  }
```

- [ ] **Step 7: Wire the extras into the section**

Add to the `AccessSafetySection(...)` call:

```dart
            entryMethodExtras: _entryMethodExtras(),
            exitMethodExtras: _exitMethodExtras(),
```

- [ ] **Step 8: Run the test to verify it passes**

Run: `flutter test test/features/dive_sites/presentation/pages/site_edit_merge_entry_method_test.dart`
Expected: PASS.

- [ ] **Step 9: Run the merge suite for regressions**

Run: `flutter test test/features/dive_sites/presentation/pages/`
Expected: PASS.

- [ ] **Step 10: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_sites/presentation/pages/site_edit_page.dart lib/features/dive_sites/presentation/widgets/edit_sections/access_safety_section.dart test/features/dive_sites/presentation/pages/site_edit_merge_entry_method_test.dart
git commit -m "feat(sites): merge-mode cycling for entry and exit method (#1104)"
```

---

### Task 8: Site detail display

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart` (`_hasAccessInfo` at `:983`, `_buildAccessSection` at `:1422`)
- Test: `test/features/dive_sites/presentation/pages/site_detail_entry_method_test.dart`

**Interfaces:**
- Consumes: `DiveSite.entryMethod` / `exitMethod`, the detail l10n keys from Task 5.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Write the failing widget test**

Create `test/features/dive_sites/presentation/pages/site_detail_entry_method_test.dart`, reusing the harness from the nearest existing site detail test.

```dart
testWidgets('the access card renders when entry method is the only field',
    (tester) async {
  await pumpSiteDetailPage(
    tester,
    site: const DiveSite(
      id: 'site-1',
      name: 'Blue Hole',
      entryMethod: EntryMethod.boat,
    ),
  );

  expect(find.text('Boat Entry'), findsOneWidget);
});

testWidgets('the access card shows exit method when it differs',
    (tester) async {
  await pumpSiteDetailPage(
    tester,
    site: const DiveSite(
      id: 'site-1',
      name: 'Blue Hole',
      entryMethod: EntryMethod.giantStride,
      exitMethod: EntryMethod.ladder,
    ),
  );

  expect(find.text('Giant Stride'), findsOneWidget);
  expect(find.text('Ladder'), findsOneWidget);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/pages/site_detail_entry_method_test.dart`
Expected: FAIL. The card does not render at all, because `_hasAccessInfo` returns false.

- [ ] **Step 3: Extend the gate**

Replace `_hasAccessInfo`:

```dart
  bool _hasAccessInfo(DiveSite site) {
    return (site.accessNotes != null && site.accessNotes!.isNotEmpty) ||
        (site.mooringNumber != null && site.mooringNumber!.isNotEmpty) ||
        (site.parkingInfo != null && site.parkingInfo!.isNotEmpty) ||
        site.entryMethod != null ||
        site.exitMethod != null;
  }
```

- [ ] **Step 4: Add the rows**

In `_buildAccessSection`, immediately after the `accessNotes` block and before the `mooringNumber` block:

```dart
            if (site.entryMethod != null) ...[
              _buildDetailRow(
                context,
                Icons.login,
                context.l10n.diveSites_detail_access_entryMethod,
                site.entryMethod!.localizedName(context.l10n),
              ),
            ],
            if (site.exitMethod != null &&
                site.exitMethod != site.entryMethod) ...[
              _buildDetailRow(
                context,
                Icons.logout,
                context.l10n.diveSites_detail_access_exitMethod,
                site.exitMethod!.localizedName(context.l10n),
              ),
            ],
```

The `site.exitMethod != site.entryMethod` guard suppresses a redundant "Exit: Boat Entry" row directly under "Entry: Boat Entry".

Add the `EntryMethodDisplay` import if it is not already present.

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/dive_sites/presentation/pages/site_detail_entry_method_test.dart`
Expected: PASS, both tests.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_sites/presentation/pages/site_detail_page.dart test/features/dive_sites/presentation/pages/site_detail_entry_method_test.dart
git commit -m "feat(sites): show entry and exit method on the site detail page (#1104)"
```

---

### Task 9: Suggestion query and provider

Derives a site's likely entry/exit pair from the dives already logged there. No UI in this task.

**Files:**
- Create: `lib/features/dive_sites/domain/models/entry_exit_suggestion.dart`
- Modify: `lib/features/statistics/data/repositories/statistics_repository.dart` (next to `getEntryMethodDistribution` at `:1186`)
- Modify: `lib/features/dive_sites/presentation/providers/site_providers.dart`
- Test: `test/features/dive_sites/domain/entry_exit_suggestion_test.dart`

**Interfaces:**
- Consumes: `dives.entry_method` / `exit_method` (existing columns).
- Produces: `EntryExitSuggestion` (fields `entry`, `exit`, `count`); `StatisticsRepository.getEntryExitMethodPairsForSite({required String siteId, String? diverId})` returning `List<EntryExitPairCount>`; `siteEntryExitSuggestionProvider`, a `FutureProvider.family<EntryExitSuggestion?, String>` keyed by site id.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_sites/domain/entry_exit_suggestion_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

void main() {
  late AppDatabase db;
  late StatisticsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = StatisticsRepository(db);
  });

  tearDown(() => db.close());

  Future<void> insertDive({
    required String id,
    required String siteId,
    required String diverId,
    String? entry,
    String? exit,
  }) async {
    await db.customStatement(
      'INSERT INTO dives (id, diver_id, site_id, entry_method, exit_method, '
      'dive_date_time, created_at, updated_at) '
      'VALUES (?, ?, ?, ?, ?, 0, 0, 0)',
      [id, diverId, siteId, entry, exit],
    );
  }

  test('returns the modal entry/exit pair for the site', () async {
    await insertDive(
      id: 'd1', siteId: 's1', diverId: 'me',
      entry: 'giantStride', exit: 'ladder',
    );
    await insertDive(
      id: 'd2', siteId: 's1', diverId: 'me',
      entry: 'giantStride', exit: 'ladder',
    );
    await insertDive(
      id: 'd3', siteId: 's1', diverId: 'me',
      entry: 'shore', exit: 'shore',
    );

    final pairs = await repo.getEntryExitMethodPairsForSite(
      siteId: 's1',
      diverId: 'me',
    );

    expect(pairs.first.entryMethod, 'giantStride');
    expect(pairs.first.exitMethod, 'ladder');
    expect(pairs.first.count, 2);
  });

  test('groups on the pair rather than on each column independently', () async {
    // Regression guard for the exit-mirroring bias: the dive form defaults
    // exit to mirror entry, so most rows carry exit == entry for values the
    // diver never set. Grouping jointly keeps the two pairings distinct
    // instead of collapsing them into one inflated exit mode.
    await insertDive(
      id: 'd1', siteId: 's1', diverId: 'me', entry: 'boat', exit: 'boat',
    );
    await insertDive(
      id: 'd2', siteId: 's1', diverId: 'me', entry: 'boat', exit: 'boat',
    );
    await insertDive(
      id: 'd3', siteId: 's1', diverId: 'me', entry: 'boat', exit: 'ladder',
    );

    final pairs = await repo.getEntryExitMethodPairsForSite(
      siteId: 's1',
      diverId: 'me',
    );

    expect(pairs.length, 2);
    expect(pairs.first.exitMethod, 'boat');
    expect(pairs.first.count, 2);
    expect(pairs[1].exitMethod, 'ladder');
    expect(pairs[1].count, 1);
  });

  test('excludes dives with no entry method', () async {
    await insertDive(id: 'd1', siteId: 's1', diverId: 'me', entry: null);
    await insertDive(id: 'd2', siteId: 's1', diverId: 'me', entry: '');

    final pairs = await repo.getEntryExitMethodPairsForSite(
      siteId: 's1',
      diverId: 'me',
    );

    expect(pairs, isEmpty);
  });

  test('carries a null exit method through as null', () async {
    await insertDive(
      id: 'd1', siteId: 's1', diverId: 'me', entry: 'shore', exit: null,
    );

    final pairs = await repo.getEntryExitMethodPairsForSite(
      siteId: 's1',
      diverId: 'me',
    );

    expect(pairs.first.entryMethod, 'shore');
    expect(pairs.first.exitMethod, isNull);
  });

  test('ignores dives at other sites and other divers', () async {
    await insertDive(
      id: 'd1', siteId: 's1', diverId: 'me', entry: 'shore', exit: 'shore',
    );
    await insertDive(
      id: 'd2', siteId: 's2', diverId: 'me', entry: 'boat', exit: 'boat',
    );
    await insertDive(
      id: 'd3', siteId: 's1', diverId: 'other', entry: 'boat', exit: 'boat',
    );

    final pairs = await repo.getEntryExitMethodPairsForSite(
      siteId: 's1',
      diverId: 'me',
    );

    expect(pairs.length, 1);
    expect(pairs.first.entryMethod, 'shore');
  });
}
```

Before running, check the `dives` table's NOT NULL columns and widen the INSERT if it rejects the fixture:

```bash
grep -n "class Dives extends Table" -A 40 lib/core/database/database.dart | grep -v nullable
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_sites/domain/entry_exit_suggestion_test.dart`
Expected: FAIL, `The method 'getEntryExitMethodPairsForSite' isn't defined`.

- [ ] **Step 3: Add the repository query**

In `lib/features/statistics/data/repositories/statistics_repository.dart`, add next to `DistributionSegment`:

```dart
/// One observed (entry method, exit method) pairing and how often it occurs.
/// Both values are stored EntryMethod enum names; the presentation layer
/// translates them.
class EntryExitPairCount {
  const EntryExitPairCount({
    required this.entryMethod,
    required this.exitMethod,
    required this.count,
  });

  final String entryMethod;
  final String? exitMethod;
  final int count;
}
```

And after `getEntryMethodDistribution`:

```dart
  /// Observed entry/exit method pairings among a diver's dives at one site,
  /// most frequent first.
  ///
  /// Grouping on the pair is deliberate. The dive form defaults exit method
  /// to mirror entry, so taking the most common exit_method independently
  /// would over-report "in and out the same way" for values the diver never
  /// actually set. Rows with no entry method carry no information and are
  /// excluded; a null exit method is meaningful and is carried through.
  Future<List<EntryExitPairCount>> getEntryExitMethodPairsForSite({
    required String siteId,
    String? diverId,
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
      final params = diverId != null ? [siteId, diverId] : [siteId];

      final results = await _db.customSelect('''
        SELECT
          entry_method,
          exit_method,
          COUNT(*) AS count
        FROM dives
        WHERE site_id = ?
          AND entry_method IS NOT NULL AND entry_method != '' $diverFilter
        GROUP BY entry_method, exit_method
        ORDER BY count DESC
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      return results.map((row) {
        final exit = row.read<String?>('exit_method');
        return EntryExitPairCount(
          entryMethod: row.read<String>('entry_method'),
          exitMethod: (exit == null || exit.isEmpty) ? null : exit,
          count: row.read<int>('count'),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_sites/domain/entry_exit_suggestion_test.dart`
Expected: PASS, all five tests.

- [ ] **Step 5: Add the suggestion model**

Create `lib/features/dive_sites/domain/models/entry_exit_suggestion.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// The entry/exit pairing most often logged at a site, offered to fill that
/// site's own empty entry and exit method fields.
class EntryExitSuggestion extends Equatable {
  const EntryExitSuggestion({
    required this.entry,
    required this.exit,
    required this.count,
  });

  final EntryMethod entry;
  final EntryMethod? exit;

  /// How many dives at this site record the pairing.
  final int count;

  @override
  List<Object?> get props => [entry, exit, count];
}
```

- [ ] **Step 6: Add the provider**

In `lib/features/dive_sites/presentation/providers/site_providers.dart`:

```dart
/// The entry/exit pairing most often logged at [siteId], or null when the
/// site has no dives that record an entry method.
///
/// Takes the dives tick because site merges, bulk edits, and sync pulls all
/// change which dives belong to a site without touching the site row.
final siteEntryExitSuggestionProvider =
    FutureProvider.family<EntryExitSuggestion?, String>((ref, siteId) async {
      final diveRepository = ref.watch(diveRepositoryProvider);
      ref.invalidateSelfWhen(diveRepository.watchDivesChanges());

      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      if (diverId == null) return null;

      final stats = ref.watch(statisticsRepositoryProvider);
      final pairs = await stats.getEntryExitMethodPairsForSite(
        siteId: siteId,
        diverId: diverId,
      );
      if (pairs.isEmpty) return null;

      final top = pairs.first;
      final entry = EntryMethod.values.asNameMap()[top.entryMethod];
      if (entry == null) return null;

      return EntryExitSuggestion(
        entry: entry,
        exit: top.exitMethod == null
            ? null
            : EntryMethod.values.asNameMap()[top.exitMethod],
        count: top.count,
      );
    });
```

Add the imports for `EntryMethod`, `EntryExitSuggestion`, and `statisticsRepositoryProvider` (`package:submersion/features/statistics/presentation/providers/statistics_providers.dart`). `diveRepositoryProvider` and `validatedCurrentDiverIdProvider` are already imported by this file.

- [ ] **Step 7: Verify the provider compiles**

Run: `flutter analyze lib/features/dive_sites/presentation/providers/site_providers.dart`
Expected: no issues.

- [ ] **Step 8: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/statistics/data/repositories/statistics_repository.dart lib/features/dive_sites/domain/models/entry_exit_suggestion.dart lib/features/dive_sites/presentation/providers/site_providers.dart test/features/dive_sites/domain/entry_exit_suggestion_test.dart
git commit -m "feat(sites): derive an entry/exit suggestion from dives at the site (#1104)"
```

---

### Task 10: Suggestion chip

**Files:**
- Modify: `lib/features/dive_sites/presentation/widgets/edit_sections/access_safety_section.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart`
- Test: `test/features/dive_sites/presentation/pages/site_edit_entry_suggestion_test.dart`

**Interfaces:**
- Consumes: `siteEntryExitSuggestionProvider` and `EntryExitSuggestion` from Task 9; the suggestion l10n keys from Task 5.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Write the failing widget test**

Create `test/features/dive_sites/presentation/pages/site_edit_entry_suggestion_test.dart`, overriding `siteEntryExitSuggestionProvider` so the test does not need a populated dive table:

```dart
testWidgets('the chip appears when both fields are empty', (tester) async {
  await pumpSiteEditPage(
    tester,
    site: const DiveSite(id: 'site-1', name: 'Blue Hole'),
    overrides: [
      siteEntryExitSuggestionProvider('site-1').overrideWith(
        (ref) async => const EntryExitSuggestion(
          entry: EntryMethod.boat,
          exit: EntryMethod.ladder,
          count: 14,
        ),
      ),
    ],
  );
  await expandAccessSection(tester);

  expect(
    find.text('Your 14 dives here: Boat Entry in, Ladder out'),
    findsOneWidget,
  );
});

testWidgets('the chip is absent when entry method is already set',
    (tester) async {
  await pumpSiteEditPage(
    tester,
    site: const DiveSite(
      id: 'site-1',
      name: 'Blue Hole',
      entryMethod: EntryMethod.shore,
    ),
    overrides: [
      siteEntryExitSuggestionProvider('site-1').overrideWith(
        (ref) async => const EntryExitSuggestion(
          entry: EntryMethod.boat,
          exit: EntryMethod.ladder,
          count: 14,
        ),
      ),
    ],
  );
  await expandAccessSection(tester);

  expect(find.byType(ActionChip), findsNothing);
});

testWidgets('tapping the chip fills both fields', (tester) async {
  await pumpSiteEditPage(
    tester,
    site: const DiveSite(id: 'site-1', name: 'Blue Hole'),
    overrides: [
      siteEntryExitSuggestionProvider('site-1').overrideWith(
        (ref) async => const EntryExitSuggestion(
          entry: EntryMethod.boat,
          exit: EntryMethod.ladder,
          count: 14,
        ),
      ),
    ],
  );
  await expandAccessSection(tester);

  await tester.tap(find.byType(ActionChip));
  await tester.pumpAndSettle();

  expect(find.text('Boat Entry'), findsOneWidget);
  expect(find.text('Ladder'), findsOneWidget);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/pages/site_edit_entry_suggestion_test.dart`
Expected: FAIL. No `ActionChip` is rendered.

- [ ] **Step 3: Add the chip slot to the section**

In `access_safety_section.dart`, add an optional parameter after `this.exitMethodExtras,`:

```dart
    this.entrySuggestion,
```

and the field:

```dart
  /// Optional one-tap fill offered above the entry method row. Built by the
  /// page so this widget stays free of provider dependencies.
  final Widget? entrySuggestion;
```

In `build`, insert immediately before the entry method row:

```dart
        if (entrySuggestion != null) entrySuggestion!,
```

- [ ] **Step 4: Build the chip in the page**

In `site_edit_page.dart`, add a builder method next to the extras builders:

```dart
  /// The one-tap fill offered when this site has no entry or exit method yet
  /// but the diver has already logged dives here.
  ///
  /// Gated on both fields being empty. Once a site carries a value, dives that
  /// inherited it would otherwise become evidence "confirming" the value the
  /// site itself produced.
  Widget? _entrySuggestionChip() {
    if (!widget.isEditing || widget.siteId == null) return null;
    if (_entryMethod != null || _exitMethod != null) return null;
    if (widget.isMerging) return null;

    return Consumer(
      builder: (context, ref, _) {
        final l10n = context.l10n;
        final async = ref.watch(
          siteEntryExitSuggestionProvider(widget.siteId!),
        );
        return async.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (suggestion) {
            if (suggestion == null) return const SizedBox.shrink();
            final entryLabel = suggestion.entry.localizedName(l10n);
            final label = suggestion.exit == null
                ? l10n.diveSites_edit_access_entrySuggestionEntryOnly(
                    suggestion.count,
                    entryLabel,
                  )
                : l10n.diveSites_edit_access_entrySuggestionPair(
                    suggestion.count,
                    entryLabel,
                    suggestion.exit!.localizedName(l10n),
                  );
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: const Icon(Icons.history, size: 18),
                  label: Text(label),
                  onPressed: () => setState(() {
                    _entryMethod = suggestion.entry;
                    _exitMethod = suggestion.exit;
                    _hasChanges = true;
                  }),
                ),
              ),
            );
          },
        );
      },
    );
  }
```

Wire it into the `AccessSafetySection(...)` call:

```dart
            entrySuggestion: _entrySuggestionChip(),
```

Add imports for `Consumer` (`package:flutter_riverpod/flutter_riverpod.dart`, likely already present) and `siteEntryExitSuggestionProvider`.

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/dive_sites/presentation/pages/site_edit_entry_suggestion_test.dart`
Expected: PASS, all three tests.

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_sites/ test/features/dive_sites/
git commit -m "feat(sites): offer an entry/exit method fill from dive history (#1104)"
```

---

### Task 11: Repair the dead export columns

Points `SiteField.entryType` and the site exporters at the real fields. These columns render blank today.

**Files:**
- Modify: `lib/features/dive_sites/domain/constants/site_field.dart` (enum near `:41`, `displayName` near `:90`, extractor at `:522`)
- Modify: `lib/core/services/export/csv/csv_export_service.dart:230-232`
- Modify: `lib/core/services/export/excel/excel_export_service.dart:315-317`
- Modify: `lib/core/services/export/kml/kml_export_service.dart:227-243`
- Test: `test/features/dive_sites/domain/constants/site_field_entry_method_test.dart`

**Interfaces:**
- Consumes: `DiveSite.entryMethod` / `exitMethod`.
- Produces: `SiteField.exitMethod`, a new enum member.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_sites/domain/constants/site_field_entry_method_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  test('entryType extracts the real entry method column', () {
    const site = DiveSite(
      id: 's',
      name: 'S',
      entryMethod: EntryMethod.boat,
    );
    expect(
      SiteField.entryType.extractValue(siteEntity(site)),
      EntryMethod.boat.displayName,
    );
  });

  test('exitMethod extracts the real exit method column', () {
    const site = DiveSite(
      id: 's',
      name: 'S',
      exitMethod: EntryMethod.ladder,
    );
    expect(
      SiteField.exitMethod.extractValue(siteEntity(site)),
      EntryMethod.ladder.displayName,
    );
  });

  test('both are null when unset', () {
    const site = DiveSite(id: 's', name: 'S');
    expect(SiteField.entryType.extractValue(siteEntity(site)), isNull);
    expect(SiteField.exitMethod.extractValue(siteEntity(site)), isNull);
  });
}
```

Read `extractValue`'s actual signature first; it takes a wrapper carrying `site` and `diveCount`. Replace `siteEntity(site)` with the real construction:

```bash
grep -n "extractValue" -B 8 lib/features/dive_sites/domain/constants/site_field.dart | head -20
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_sites/domain/constants/site_field_entry_method_test.dart`
Expected: FAIL. `entryType` returns null and `SiteField.exitMethod` does not exist.

- [ ] **Step 3: Add the enum member and its label**

In `site_field.dart`, add to the `// Conditions` group immediately after `entryType,`:

```dart
  exitMethod,
```

Do **not** rename `entryType`. Users' saved table layouts store these members by name, and renaming one throws when a saved layout is loaded. Add a comment above it:

```dart
  // Named entryType for historical reasons; it now reads
  // DiveSite.entryMethod. Renaming it would break saved table layouts.
  entryType,
```

Add to `displayName`, after the `entryType` case:

```dart
      case SiteField.exitMethod:
        return 'Exit Method';
```

Add matching arms to every other exhaustive `switch (SiteField ...)` in the file (`shortLabel`, category, alignment). `flutter analyze` will name each one that is missing a case.

- [ ] **Step 4: Repoint the extractor**

Replace the `entryType` arm and add the new one:

```dart
      case SiteField.entryType:
        return site.entryMethod?.displayName;
      case SiteField.exitMethod:
        return site.exitMethod?.displayName;
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/dive_sites/domain/constants/site_field_entry_method_test.dart`
Expected: PASS, all three tests.

- [ ] **Step 6: Repoint the CSV exporter**

In `csv_export_service.dart`, replace lines 230-232:

```dart
        site.waterType?.displayName ?? '',
        '',
        site.entryMethod?.displayName ?? '',
```

The middle value is Typical Current, which has no backing column and stays blank. Leave the header row unchanged so existing consumers of the CSV keep their column positions.

- [ ] **Step 7: Repoint the Excel exporter**

In `excel_export_service.dart`, replace lines 315-317 with the same three values.

- [ ] **Step 8: Repoint the KML exporter**

In `kml_export_service.dart`, replace the whole `if (site.conditions != null) { ... }` block at `:227-243`:

```dart
    if (site.waterType != null) {
      buffer.writeln(
        '<p><b>Water Type:</b> ${_escapeHtml(site.waterType!.displayName)}</p>',
      );
    }
    if (site.entryMethod != null) {
      buffer.writeln(
        '<p><b>Entry:</b> ${_escapeHtml(site.entryMethod!.displayName)}</p>',
      );
    }
    if (site.exitMethod != null && site.exitMethod != site.entryMethod) {
      buffer.writeln(
        '<p><b>Exit:</b> ${_escapeHtml(site.exitMethod!.displayName)}</p>',
      );
    }
```

- [ ] **Step 9: Add the UDDF site import mapping**

In `lib/core/services/export/uddf/uddf_full_import_service.dart`, find the site metadata map (it currently reads `const {'watertype': 'waterType', 'bodyofwater': 'bodyOfWater', 'difficulty': 'difficulty'}`) and add `'entrytype': 'entryMethod'`. Then extend `SiteRepository.updateSiteWithImportedMetadata` (`site_repository_impl.dart:147-161`) to patch the new column, following exactly how it patches `waterType` at `:198-199`.

If the mapping shape differs from the above, read the surrounding code and follow it rather than forcing this shape.

- [ ] **Step 10: Run the export suite**

Run: `flutter test test/core/services/export/`
Expected: PASS. Any test asserting a blank Entry Type or Water Type cell must be updated to the real value; that assertion was encoding the bug.

- [ ] **Step 11: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_sites/domain/constants/site_field.dart lib/core/services/export/ test/
git commit -m "fix(sites): point the blank Entry Type export columns at real data (#1104)"
```

---

### Task 12: Retire SiteConditions (optional, independently rejectable)

Removes a class that is never constructed anywhere in `lib`. The feature does not depend on this task, and it can be dropped without affecting anything above.

**Files:**
- Modify: `lib/features/dive_sites/domain/entities/dive_site.dart` (field `:59`, `copyWith` param `:149`, `props`, class `:225-254`)
- Modify: `lib/features/dive_sites/domain/constants/site_field.dart` (`:517`, `:519`, `:525`)

**Interfaces:**
- Consumes: the repointed readers from Task 11.
- Produces: `DiveSite.conditions` and `SiteConditions` no longer exist.

- [ ] **Step 1: Confirm no readers remain**

```bash
grep -rn "conditions" lib --include="*.dart" | grep -v "\.g\.dart" | grep -i "site"
```

Expected: only `site_field.dart:517/519/525` (typicalVisibility, typicalCurrent, bestSeason) and the `dive_site.dart` declarations. If anything else appears, Task 11 is incomplete; stop and finish it.

- [ ] **Step 2: Null out the three remaining dead extractors**

In `site_field.dart`, replace those three arms:

```dart
      case SiteField.typicalVisibility:
      case SiteField.typicalCurrent:
      case SiteField.bestSeason:
        // No backing column. These enum members are retained because saved
        // table layouts reference them by name; removing them would throw on
        // load. They render blank until a real column exists.
        return null;
```

Keep all three enum members. Do not delete them.

- [ ] **Step 3: Remove the class and the field**

In `dive_site.dart`, delete the `conditions` field declaration, its constructor parameter, its `copyWith` parameter and assignment, its `props` entry, and the entire `class SiteConditions extends Equatable { ... }`.

- [ ] **Step 4: Verify the tree compiles**

Run: `flutter analyze`
Expected: no issues. Any remaining reference will be named here.

- [ ] **Step 5: Run the full suite**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/dive_sites/
git commit -m "refactor(sites): remove the never-constructed SiteConditions (#1104)"
```

---

## Final verification

- [ ] **Run the whole suite**

Run: `flutter test`
Expected: PASS. Compare any failure against a `main` baseline before assuming this branch caused it; the suite carries two known flaky split tests and a recovery-dialog timing flake.

- [ ] **Run the analyzer over the whole project**

Run: `flutter analyze`
Expected: no issues, including infos.

- [ ] **Confirm formatting**

Run: `dart format --set-exit-if-changed .`
Expected: exit 0.

- [ ] **Manual check on macOS**

Run: `flutter run -d macos`

1. Open a dive site, expand Access and Safety, set Entry Method to Boat Entry, save.
2. Create a new dive, assign that site, confirm Entry Method reads Boat Entry.
3. Set the dive's Exit Method to Ladder by hand, reassign the site, confirm Exit Method stays Ladder.
4. On a site with several logged dives and no entry method set, confirm the suggestion chip appears and fills both fields.
