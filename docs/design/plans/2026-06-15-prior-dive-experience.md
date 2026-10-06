# Prior Dive Experience (Career Totals) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let each diver record dives/time accumulated before they used Submersion (issue #331) so the Stats page's Total Dives and Total Time read as a correct career total, with a `logged + prior` breakdown and a "Diving since" line.

**Architecture:** Three nullable columns on the `Divers` table hold the per-diver offset. `getStatistics()` stays logged-only. A pure `CareerTotals` value object combines logged stats with the active diver's prior values; the stats page builds it inline (watching the existing `currentDiverProvider`) and renders combined totals + breakdown. Only Total Dives and Total Time are offset — every other stat stays logged-only.

**Tech Stack:** Flutter, Drift (SQLite), Riverpod, Flutter gen-l10n (ARB), flutter_test.

---

## Preconditions (read before starting)

1. **Worktree init:** this worktree was branched fresh from `origin/main`. Before any code, run:
   ```bash
   git submodule update --init --recursive
   flutter pub get
   ```
2. **Schema-version coordination (IMPORTANT):** this plan assumes `currentSchemaVersion == 83` (verified on `origin/main`). The in-flight `feat/incremental-sync` branch reaches 86. Before writing Task 1's migration, run:
   ```bash
   grep -n "currentSchemaVersion =" lib/core/database/database.dart
   ```
   If it is **not** 83 (e.g. incremental-sync merged, making it 86), renumber Task 1's migration to the next free integer (e.g. 87): update the `currentSchemaVersion` value, the `if (from < N)` guards, and the appended entry in `migrationVersions`. The migration body (PRAGMA-guarded `ALTER TABLE divers`) is otherwise unchanged.
3. **Conventions:** commit messages use no `Co-Authored-By` line. Run whole-project `flutter analyze` (do not pipe/tail-mask it) and `dart format` on touched files before each commit. Run specific test files (not whole directories) to avoid timeouts.
4. Line numbers below are approximate; anchor edits on the quoted text, which is verbatim from this base.

## File Structure

| File | Responsibility | Action |
| --- | --- | --- |
| `lib/core/database/database.dart` | `Divers` columns, schema version, migration | Modify |
| `lib/core/database/database.g.dart` | Generated Drift row/companion | Regenerate (build_runner) |
| `lib/features/divers/domain/entities/diver.dart` | `Diver` entity fields | Modify |
| `lib/features/divers/data/repositories/diver_repository.dart` | Row<->entity mapping | Modify |
| `lib/features/statistics/domain/career_totals.dart` | Pure combine logic | Create |
| `lib/l10n/arb/app_en.arb` (+ 9 locale ARBs) | UI strings | Modify |
| `lib/features/divers/presentation/pages/diver_edit_page.dart` | Prior-experience entry form | Modify |
| `lib/features/statistics/presentation/pages/statistics_overview_page.dart` | Combined totals + breakdown + since-line | Modify |
| `test/core/database/migration_v84_prior_experience_test.dart` | Migration test | Create |
| `test/features/divers/domain/diver_prior_experience_test.dart` | Entity test | Create |
| `test/features/divers/data/repositories/diver_repository_prior_experience_test.dart` | Repo round-trip | Create |
| `test/features/statistics/domain/career_totals_test.dart` | Combine logic | Create |
| `test/features/divers/presentation/pages/diver_edit_prior_experience_test.dart` | Edit form save | Create |
| `test/features/statistics/presentation/pages/statistics_overview_prior_experience_test.dart` | Stats display | Create |

---

## Task 1: Schema columns + migration (v83 -> v84)

**Files:**
- Modify: `lib/core/database/database.dart` (Divers table ~line 12-49; `currentSchemaVersion` line 1570; `migrationVersions` line 1575; onUpgrade tail line 3976)
- Regenerate: `lib/core/database/database.g.dart`
- Test: `test/core/database/migration_v84_prior_experience_test.dart`

- [ ] **Step 1: Write the failing migration test**

Create `test/core/database/migration_v84_prior_experience_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('v84 adds prior-experience columns to divers, preserving rows', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 83');
        // Minimal v83 divers shape (pre prior-experience columns).
        rawDb.execute('''
          CREATE TABLE divers (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            medical_notes TEXT NOT NULL DEFAULT '',
            notes TEXT NOT NULL DEFAULT '',
            is_default INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0,
            hlc TEXT
          )
        ''');
        rawDb.execute(
          "INSERT INTO divers (id, name, created_at, updated_at) "
          "VALUES ('d1', 'Old Salt', 100, 100)",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    // Touch the DB so the migration runs.
    final cols = await db
        .customSelect("PRAGMA table_info('divers')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();

    expect(names, containsAll(<String>{
      'prior_dive_count',
      'prior_dive_time_seconds',
      'diving_since',
    }));

    final row = await db
        .customSelect("SELECT name, prior_dive_count FROM divers WHERE id = 'd1'")
        .getSingle();
    expect(row.read<String>('name'), 'Old Salt');
    expect(row.data['prior_dive_count'], isNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/database/migration_v84_prior_experience_test.dart`
Expected: FAIL — the columns are absent (current `currentSchemaVersion` is 83, no v84 block), so `containsAll` fails.

- [ ] **Step 3: Add the three columns to the `Divers` table**

In `lib/core/database/database.dart`, in `class Divers extends Table`, immediately after the `hlc` column getter (the line `TextColumn get hlc => text().nullable()();` inside the Divers class, just before `@override\n  Set<Column> get primaryKey => {id};`), add:

```dart
  // Prior dive experience (issue #331): per-diver lifetime offsets for dives
  // logged before the diver started using Submersion. Null = none.
  IntColumn get priorDiveCount => integer().nullable()();
  IntColumn get priorDiveTimeSeconds => integer().nullable()();
  IntColumn get divingSince => integer().nullable()(); // Unix ms timestamp
```

- [ ] **Step 4: Bump the schema version**

Change line 1570 from:

```dart
  static const int currentSchemaVersion = 83;
```

to:

```dart
  static const int currentSchemaVersion = 84;
```

- [ ] **Step 5: Append 84 to `migrationVersions`**

The list starting at line 1575 (`static const List<int> migrationVersions = [`) ends with `83,` before its closing `];`. Add `84,` as the final entry so `migrationStepCount` counts the new step. Locate the `83,` that is the last element of this list and change it to:

```dart
    83,
    84,
```

- [ ] **Step 6: Add the v84 migration block**

In `migration`'s `onUpgrade`, the tail currently reads:

```dart
        if (from < 83) await reportProgress();
      },
      beforeOpen: (details) async {
```

Insert the new block between `if (from < 83) await reportProgress();` and the closing `},`:

```dart
        if (from < 83) await reportProgress();
        if (from < 84) {
          // Prior dive experience (issue #331): three nullable columns on
          // `divers`. PRAGMA-guarded so a healthy database no-ops; existing
          // rows read as NULL = "no prior experience".
          final cols = await customSelect(
            "PRAGMA table_info('divers')",
          ).get();
          if (cols.isNotEmpty) {
            final existing = cols.map((c) => c.read<String>('name')).toSet();
            if (!existing.contains('prior_dive_count')) {
              await customStatement(
                'ALTER TABLE divers ADD COLUMN prior_dive_count INTEGER',
              );
            }
            if (!existing.contains('prior_dive_time_seconds')) {
              await customStatement(
                'ALTER TABLE divers ADD COLUMN prior_dive_time_seconds INTEGER',
              );
            }
            if (!existing.contains('diving_since')) {
              await customStatement(
                'ALTER TABLE divers ADD COLUMN diving_since INTEGER',
              );
            }
          }
        }
        if (from < 84) await reportProgress();
      },
      beforeOpen: (details) async {
```

- [ ] **Step 7: Regenerate Drift codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes; `database.g.dart` now has `priorDiveCount`, `priorDiveTimeSeconds`, `divingSince` on the generated `Diver` row and `DiversCompanion`.

- [ ] **Step 8: Run the test to verify it passes**

Run: `flutter test test/core/database/migration_v84_prior_experience_test.dart`
Expected: PASS.

- [ ] **Step 9: Format, analyze, commit**

```bash
dart format lib/core/database/database.dart test/core/database/migration_v84_prior_experience_test.dart
flutter analyze
git add lib/core/database/database.dart lib/core/database/database.g.dart test/core/database/migration_v84_prior_experience_test.dart
git commit -m "feat(db): add prior dive experience columns to divers (v84, #331)"
```

---

## Task 2: Extend the `Diver` entity

**Files:**
- Modify: `lib/features/divers/domain/entities/diver.dart`
- Test: `test/features/divers/domain/diver_prior_experience_test.dart`

- [ ] **Step 1: Write the failing entity test**

Create `test/features/divers/domain/diver_prior_experience_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

void main() {
  final now = DateTime(2026, 1, 1);

  Diver base() => Diver(id: 'd1', name: 'A', createdAt: now, updatedAt: now);

  test('defaults to null prior experience', () {
    final d = base();
    expect(d.priorDiveCount, isNull);
    expect(d.priorDiveTimeSeconds, isNull);
    expect(d.divingSince, isNull);
  });

  test('copyWith sets and preserves prior-experience fields', () {
    final since = DateTime(1990);
    final d = base().copyWith(
      priorDiveCount: 1200,
      priorDiveTimeSeconds: 1150 * 3600,
      divingSince: since,
    );
    expect(d.priorDiveCount, 1200);
    expect(d.priorDiveTimeSeconds, 1150 * 3600);
    expect(d.divingSince, since);

    final d2 = d.copyWith(name: 'B');
    expect(d2.priorDiveCount, 1200);
    expect(d2.divingSince, since);
  });

  test('props include prior-experience fields (value equality)', () {
    expect(base().copyWith(priorDiveCount: 5) == base(), isFalse);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/divers/domain/diver_prior_experience_test.dart`
Expected: FAIL — `priorDiveCount` is not a named parameter / getter on `Diver`.

- [ ] **Step 3: Add the fields to `Diver`**

In `lib/features/divers/domain/entities/diver.dart`, in `class Diver extends Equatable`:

Add these final fields after `final DateTime updatedAt;`:

```dart
  final int? priorDiveCount;
  final int? priorDiveTimeSeconds;
  final DateTime? divingSince;
```

Add these to the constructor (after `required this.updatedAt,`):

```dart
    this.priorDiveCount,
    this.priorDiveTimeSeconds,
    this.divingSince,
```

Add these to the `copyWith` signature (after `DateTime? updatedAt,`):

```dart
    int? priorDiveCount,
    int? priorDiveTimeSeconds,
    DateTime? divingSince,
```

Add these to the `copyWith` body (after `updatedAt: updatedAt ?? this.updatedAt,`):

```dart
      priorDiveCount: priorDiveCount ?? this.priorDiveCount,
      priorDiveTimeSeconds: priorDiveTimeSeconds ?? this.priorDiveTimeSeconds,
      divingSince: divingSince ?? this.divingSince,
```

Add these to the `props` list (after `updatedAt,`):

```dart
    priorDiveCount,
    priorDiveTimeSeconds,
    divingSince,
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/divers/domain/diver_prior_experience_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/divers/domain/entities/diver.dart test/features/divers/domain/diver_prior_experience_test.dart
flutter analyze
git add lib/features/divers/domain/entities/diver.dart test/features/divers/domain/diver_prior_experience_test.dart
git commit -m "feat(divers): add prior-experience fields to Diver entity (#331)"
```

---

## Task 3: Map the new fields in the diver repository

**Files:**
- Modify: `lib/features/divers/data/repositories/diver_repository.dart` (`_mapRowToDiver` ~line 626; `createDiver` ~line 105; `updateDiver` ~line 169)
- Test: `test/features/divers/data/repositories/diver_repository_prior_experience_test.dart`

- [ ] **Step 1: Write the failing repository round-trip test**

Create `test/features/divers/data/repositories/diver_repository_prior_experience_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiverRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiverRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('create then read back round-trips prior-experience fields', () async {
    final since = DateTime(1990);
    final created = await repository.createDiver(
      Diver(
        id: '',
        name: 'Old Salt',
        priorDiveCount: 1200,
        priorDiveTimeSeconds: 1150 * 3600,
        divingSince: since,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    final fetched = await repository.getDiverById(created.id);
    expect(fetched, isNotNull);
    expect(fetched!.priorDiveCount, 1200);
    expect(fetched.priorDiveTimeSeconds, 1150 * 3600);
    expect(fetched.divingSince, since);
  });

  test('update persists prior-experience fields', () async {
    final created = await repository.createDiver(
      Diver(
        id: '',
        name: 'A',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await repository.updateDiver(
      created.copyWith(priorDiveCount: 50, priorDiveTimeSeconds: 30 * 3600),
    );

    final fetched = await repository.getDiverById(created.id);
    expect(fetched!.priorDiveCount, 50);
    expect(fetched.priorDiveTimeSeconds, 30 * 3600);
  });
}
```

> Note: confirm `DiverRepository()`'s constructor matches the project's DI (the SAC repo test uses a no-arg `StatisticsRepository()` after `setUpTestDatabase()`; mirror whatever `setUpTestDatabase()` wires for the singleton DB). If `DiverRepository` requires explicit dependencies, construct it the same way the existing diver tests do.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/divers/data/repositories/diver_repository_prior_experience_test.dart`
Expected: FAIL — `priorDiveCount` is always null after read (mapping not wired).

- [ ] **Step 3: Read the columns in `_mapRowToDiver`**

In `_mapRowToDiver`, before the closing `);` of the `domain.Diver(...)` return (after `updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),`), add:

```dart
    priorDiveCount: row.priorDiveCount,
    priorDiveTimeSeconds: row.priorDiveTimeSeconds,
    divingSince: row.divingSince != null
        ? DateTime.fromMillisecondsSinceEpoch(row.divingSince!)
        : null,
```

- [ ] **Step 4: Write the columns in `createDiver`**

In `createDiver`, inside the `DiversCompanion(...)` passed to `.insert(...)`, after `updatedAt: Value(now.millisecondsSinceEpoch),` add:

```dart
            priorDiveCount: Value(diver.priorDiveCount),
            priorDiveTimeSeconds: Value(diver.priorDiveTimeSeconds),
            divingSince: Value(diver.divingSince?.millisecondsSinceEpoch),
```

- [ ] **Step 5: Write the columns in `updateDiver`**

In `updateDiver`, inside the `DiversCompanion(...)` passed to `.write(...)`, after `updatedAt: Value(now),` add:

```dart
        priorDiveCount: Value(diver.priorDiveCount),
        priorDiveTimeSeconds: Value(diver.priorDiveTimeSeconds),
        divingSince: Value(diver.divingSince?.millisecondsSinceEpoch),
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/features/divers/data/repositories/diver_repository_prior_experience_test.dart`
Expected: PASS.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format lib/features/divers/data/repositories/diver_repository.dart test/features/divers/data/repositories/diver_repository_prior_experience_test.dart
flutter analyze
git add lib/features/divers/data/repositories/diver_repository.dart test/features/divers/data/repositories/diver_repository_prior_experience_test.dart
git commit -m "feat(divers): persist prior-experience fields in diver repository (#331)"
```

---

## Task 4: Pure `CareerTotals` combine logic

**Files:**
- Create: `lib/features/statistics/domain/career_totals.dart`
- Test: `test/features/statistics/domain/career_totals_test.dart`

- [ ] **Step 1: Write the failing combine tests**

Create `test/features/statistics/domain/career_totals_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/domain/career_totals.dart';

void main() {
  test('no prior experience -> combined equals logged, flags false', () {
    final c = CareerTotals.from(loggedDives: 312, loggedTimeSeconds: 43 * 3600);
    expect(c.combinedDives, 312);
    expect(c.combinedTimeSeconds, 43 * 3600);
    expect(c.hasPriorDives, isFalse);
    expect(c.hasPriorTime, isFalse);
    expect(c.divingSinceResolved, isNull);
  });

  test('adds prior dives and time', () {
    final c = CareerTotals.from(
      loggedDives: 312,
      loggedTimeSeconds: 43 * 3600,
      priorDives: 1200,
      priorTimeSeconds: 1150 * 3600,
    );
    expect(c.combinedDives, 1512);
    expect(c.combinedTimeSeconds, (43 + 1150) * 3600);
    expect(c.hasPriorDives, isTrue);
    expect(c.hasPriorTime, isTrue);
    expect(c.loggedHours, 43);
    expect(c.priorHours, 1150);
    expect(c.combinedTimeFormatted, '1193h 0m');
  });

  test('partial: only prior dives', () {
    final c = CareerTotals.from(
      loggedDives: 10,
      loggedTimeSeconds: 3600,
      priorDives: 90,
    );
    expect(c.combinedDives, 100);
    expect(c.hasPriorDives, isTrue);
    expect(c.hasPriorTime, isFalse);
  });

  test('negative/null prior treated as zero', () {
    final c = CareerTotals.from(
      loggedDives: 5,
      loggedTimeSeconds: 0,
      priorDives: -3,
      priorTimeSeconds: null,
    );
    expect(c.combinedDives, 5);
    expect(c.hasPriorDives, isFalse);
  });

  group('divingSinceResolved', () {
    test('entered only -> entered', () {
      final c = CareerTotals.from(
        loggedDives: 0,
        loggedTimeSeconds: 0,
        divingSince: DateTime(1990),
      );
      expect(c.divingSinceResolved, DateTime(1990));
    });

    test('entered later than first logged -> first logged (earlier)', () {
      final c = CareerTotals.from(
        loggedDives: 1,
        loggedTimeSeconds: 0,
        firstLoggedDive: DateTime(1985, 6, 1),
        divingSince: DateTime(1990),
      );
      expect(c.divingSinceResolved, DateTime(1985, 6, 1));
    });

    test('not entered -> null even if logged dives exist', () {
      final c = CareerTotals.from(
        loggedDives: 1,
        loggedTimeSeconds: 0,
        firstLoggedDive: DateTime(2020),
      );
      expect(c.divingSinceResolved, isNull);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/statistics/domain/career_totals_test.dart`
Expected: FAIL — `career_totals.dart` / `CareerTotals` does not exist.

- [ ] **Step 3: Implement `CareerTotals`**

Create `lib/features/statistics/domain/career_totals.dart`:

```dart
/// Combined "career" lifetime totals: app-logged dives plus a per-diver
/// manually-entered offset of dives/time accumulated before the diver started
/// using Submersion (issue #331). Pure value object (no I/O) so the combine
/// logic is unit-testable in isolation.
class CareerTotals {
  final int loggedDives;
  final int loggedTimeSeconds;
  final int priorDives;
  final int priorTimeSeconds;

  /// The date to show as "Diving since". Non-null only when the diver entered
  /// a value (then reconciled to be no later than their first logged dive).
  final DateTime? divingSinceResolved;

  const CareerTotals._({
    required this.loggedDives,
    required this.loggedTimeSeconds,
    required this.priorDives,
    required this.priorTimeSeconds,
    required this.divingSinceResolved,
  });

  factory CareerTotals.from({
    required int loggedDives,
    required int loggedTimeSeconds,
    DateTime? firstLoggedDive,
    int? priorDives,
    int? priorTimeSeconds,
    DateTime? divingSince,
  }) {
    final pDives = (priorDives == null || priorDives < 0) ? 0 : priorDives;
    final pTime =
        (priorTimeSeconds == null || priorTimeSeconds < 0) ? 0 : priorTimeSeconds;

    DateTime? resolved;
    if (divingSince != null) {
      resolved =
          (firstLoggedDive != null && firstLoggedDive.isBefore(divingSince))
          ? firstLoggedDive
          : divingSince;
    }

    return CareerTotals._(
      loggedDives: loggedDives,
      loggedTimeSeconds: loggedTimeSeconds,
      priorDives: pDives,
      priorTimeSeconds: pTime,
      divingSinceResolved: resolved,
    );
  }

  int get combinedDives => loggedDives + priorDives;
  int get combinedTimeSeconds => loggedTimeSeconds + priorTimeSeconds;

  bool get hasPriorDives => priorDives > 0;
  bool get hasPriorTime => priorTimeSeconds > 0;
  bool get hasPriorExperience =>
      hasPriorDives || hasPriorTime || divingSinceResolved != null;

  int get loggedHours => loggedTimeSeconds ~/ 3600;
  int get priorHours => priorTimeSeconds ~/ 3600;

  /// "Xh Ym" formatting of the combined time, matching DiveStatistics.
  String get combinedTimeFormatted {
    final d = Duration(seconds: combinedTimeSeconds);
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/statistics/domain/career_totals_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/statistics/domain/career_totals.dart test/features/statistics/domain/career_totals_test.dart
flutter analyze
git add lib/features/statistics/domain/career_totals.dart test/features/statistics/domain/career_totals_test.dart
git commit -m "feat(stats): add pure CareerTotals combine logic (#331)"
```

---

## Task 5: Localization strings (all locales)

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and every non-English ARB present (currently 9: `app_pt`, `app_he`, `app_de`, `app_it`, `app_es`, `app_hu`, `app_fr`, `app_nl`, `app_zh`).

- [ ] **Step 1: Add the English entries to `app_en.arb`**

Add these key/value pairs (placeholders carry `@`-metadata). Insert them in a sensible place (e.g. near the existing `divers_edit_*` and `statistics_*` blocks):

```json
  "divers_edit_priorExperienceSection": "Prior Experience",
  "divers_edit_priorExperienceHelp": "Dives and time from before you started logging in Submersion.",
  "divers_edit_priorDivesLabel": "Prior dives",
  "divers_edit_priorHoursLabel": "Prior hours",
  "divers_edit_priorMinutesLabel": "Minutes",
  "divers_edit_divingSinceLabel": "Diving since",
  "divers_edit_divingSinceNotSet": "Not set",
  "divers_edit_priorInvalidNumber": "Enter a valid number",
  "statistics_priorBreakdown": "{logged} logged + {prior} prior",
  "@statistics_priorBreakdown": {
    "placeholders": {
      "logged": { "type": "String" },
      "prior": { "type": "String" }
    }
  },
  "statistics_divingSince": "Diving since {year}",
  "@statistics_divingSince": {
    "placeholders": {
      "year": { "type": "int" }
    }
  }
```

- [ ] **Step 2: Add translations to every non-English ARB**

Per project convention (see commit "feat(l10n): translate ... into all locales"), do not leave English fallbacks. Add the same keys to each locale file with the translations below. Keep the `{logged}`, `{prior}`, `{year}` placeholders verbatim. Reconcile diving terms ("dives") with each file's existing usage; have `he`, `zh`, `hu` spot-checked by a native speaker.

| key | pt | es | fr | de | it | nl | hu | zh | he |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| priorExperienceSection | Experiência Anterior | Experiencia Previa | Expérience Antérieure | Frühere Erfahrung | Esperienza Precedente | Eerdere Ervaring | Korábbi Tapasztalat | 既往经验 | ניסיון קודם |
| priorExperienceHelp | Mergulhos e tempo de antes de começar a registar no Submersion. | Inmersiones y tiempo de antes de empezar a registrar en Submersion. | Plongées et temps d'avant votre utilisation de Submersion. | Tauchgänge und Zeit aus der Zeit vor deiner Nutzung von Submersion. | Immersioni e tempo prima di iniziare a registrare in Submersion. | Duiken en tijd van voordat je begon te loggen in Submersion. | Merülések és idő azelőttről, hogy elkezdted naplózni a Submersionben. | 在开始使用 Submersion 记录之前的潜水次数和时间。 | צלילות וזמן מהתקופה שלפני שהתחלת לתעד ב-Submersion. |
| priorDivesLabel | Mergulhos anteriores | Inmersiones previas | Plongées antérieures | Frühere Tauchgänge | Immersioni precedenti | Eerdere duiken | Korábbi merülések | 既往潜水次数 | צלילות קודמות |
| priorHoursLabel | Horas anteriores | Horas previas | Heures antérieures | Frühere Stunden | Ore precedenti | Eerdere uren | Korábbi órák | 既往小时数 | שעות קודמות |
| priorMinutesLabel | Minutos | Minutos | Minutes | Minuten | Minuti | Minuten | Perc | 分钟 | דקות |
| divingSinceLabel | Mergulha desde | Buceando desde | Plonge depuis | Taucht seit | Immersioni dal | Duikt sinds | Merül azóta | 潜水始于 | צולל מאז |
| divingSinceNotSet | Não definido | Sin definir | Non défini | Nicht festgelegt | Non impostato | Niet ingesteld | Nincs beállítva | 未设置 | לא הוגדר |
| priorInvalidNumber | Introduza um número válido | Introduce un número válido | Saisissez un nombre valide | Gib eine gültige Zahl ein | Inserisci un numero valido | Voer een geldig getal in | Adjon meg egy érvényes számot | 请输入有效数字 | הזן מספר תקין |
| statistics_priorBreakdown | {logged} registados + {prior} anteriores | {logged} registradas + {prior} previas | {logged} enregistrées + {prior} antérieures | {logged} erfasst + {prior} früher | {logged} registrate + {prior} precedenti | {logged} gelogd + {prior} eerder | {logged} naplózva + {prior} korábbi | {logged} 已记录 + {prior} 既往 | {logged} מתועדות + {prior} קודמות |
| statistics_divingSince | Mergulha desde {year} | Buceando desde {year} | Plonge depuis {year} | Taucht seit {year} | Immersioni dal {year} | Duikt sinds {year} | {year} óta merül | 自 {year} 年起潜水 | צולל מאז {year} |

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
(If the project generates l10n via build_runner instead, run `dart run build_runner build --delete-conflicting-outputs`.)
Expected: `AppLocalizations` now exposes `divers_edit_priorExperienceSection`, `statistics_priorBreakdown(...)`, `statistics_divingSince(...)`, etc.

- [ ] **Step 4: Analyze + commit**

```bash
flutter analyze
git add lib/l10n/arb/
git commit -m "feat(l10n): add prior-experience strings in all locales (#331)"
```

---

## Task 6: Prior-experience entry section on the diver edit page

**Files:**
- Modify: `lib/features/divers/presentation/pages/diver_edit_page.dart`
- Test: `test/features/divers/presentation/pages/diver_edit_prior_experience_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `test/features/divers/presentation/pages/diver_edit_prior_experience_test.dart`. Mirror the mock-notifier pattern from `test/features/divers/presentation/pages/diver_detail_page_test.dart` (capture the `Diver` passed to `updateDiver`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/pages/diver_edit_page.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

class _CapturingNotifier extends StateNotifier<AsyncValue<List<Diver>>>
    implements DiverListNotifier {
  _CapturingNotifier(super.state);
  Diver? updated;

  @override
  Future<void> updateDiver(Diver diver) async => updated = diver;
  @override
  Future<Diver> addDiver(Diver diver) async => diver;
  @override
  Future<void> refresh() async {}
  @override
  Future<DeleteDiverResult> deleteDiver(String id) async =>
      const DeleteDiverResult(reassignedTripsCount: 0, reassignedSitesCount: 0);
  @override
  Future<void> setAsDefault(String id) async {}
}

void main() {
  testWidgets('entering prior experience saves it onto the Diver',
      (tester) async {
    tester.view.physicalSize = const Size(700, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final now = DateTime(2026, 1, 1);
    final existing = Diver(
      id: 'd1', name: 'Old Salt', createdAt: now, updatedAt: now,
    );
    final notifier = _CapturingNotifier(AsyncValue.data([existing]));
    final overrides = await getBaseOverrides();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diverListNotifierProvider.overrideWith((ref) => notifier),
          diverByIdProvider('d1').overrideWith((ref) async => existing),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiverEditPage(diverId: 'd1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Prior dives'), '1200');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Prior hours'), '1150');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.save));
    await tester.pumpAndSettle();

    expect(notifier.updated, isNotNull);
    expect(notifier.updated!.priorDiveCount, 1200);
    expect(notifier.updated!.priorDiveTimeSeconds, 1150 * 3600);
  });
}
```

> Confirm the page's constructor name/params (`DiverEditPage(diverId: ...)`) and the save trigger (an `Icons.save` action) against the actual file; adjust the finder for the save button and the diver-load provider override (`diverByIdProvider`) to match how the page loads its diver.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/divers/presentation/pages/diver_edit_prior_experience_test.dart`
Expected: FAIL — no "Prior dives" field exists.

- [ ] **Step 3: Declare controllers + state**

In `_DiverEditPageState` (after `final _notesController = TextEditingController();` at line ~65), add:

```dart
  // Prior experience (issue #331)
  final _priorDiveCountController = TextEditingController();
  final _priorDiveHoursController = TextEditingController();
  final _priorDiveMinutesController = TextEditingController();
  DateTime? _divingSince;
```

- [ ] **Step 4: Initialize from the loaded diver**

In the load method, after `_notesController.text = diver.notes;` (line ~139), add:

```dart
        _priorDiveCountController.text = diver.priorDiveCount?.toString() ?? '';
        if (diver.priorDiveTimeSeconds != null) {
          _priorDiveHoursController.text =
              (diver.priorDiveTimeSeconds! ~/ 3600).toString();
          _priorDiveMinutesController.text =
              ((diver.priorDiveTimeSeconds! % 3600) ~/ 60).toString();
        }
        _divingSince = diver.divingSince;
```

- [ ] **Step 5: Dispose the controllers**

In `dispose()` (after `_notesController.dispose();` at line ~172), add:

```dart
    _priorDiveCountController.dispose();
    _priorDiveHoursController.dispose();
    _priorDiveMinutesController.dispose();
```

- [ ] **Step 6: Add the year picker handler + the section builder**

Add these two methods to `_DiverEditPageState` (place them near `_buildInsuranceSection`):

```dart
  Future<void> _pickDivingSince() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _divingSince ?? DateTime(now.year - 10),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _divingSince = DateTime(picked.year);
        _hasChanges = true;
      });
    }
  }

  Widget _buildPriorExperienceSection() {
    String? nonNegativeInt(String? v, {int? max}) {
      if (v == null || v.trim().isEmpty) return null;
      final n = int.tryParse(v.trim());
      if (n == null || n < 0) {
        return context.l10n.divers_edit_priorInvalidNumber;
      }
      if (max != null && n > max) {
        return context.l10n.divers_edit_priorInvalidNumber;
      }
      return null;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.divers_edit_priorExperienceHelp,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priorDiveCountController,
              decoration: InputDecoration(
                labelText: context.l10n.divers_edit_priorDivesLabel,
                prefixIcon: const Icon(Icons.waves),
              ),
              keyboardType: TextInputType.number,
              validator: (v) => nonNegativeInt(v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priorDiveHoursController,
                    decoration: InputDecoration(
                      labelText: context.l10n.divers_edit_priorHoursLabel,
                      prefixIcon: const Icon(Icons.timer),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => nonNegativeInt(v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _priorDiveMinutesController,
                    decoration: InputDecoration(
                      labelText: context.l10n.divers_edit_priorMinutesLabel,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => nonNegativeInt(v, max: 59),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(context.l10n.divers_edit_divingSinceLabel),
              subtitle: Text(
                _divingSince != null
                    ? '${_divingSince!.year}'
                    : context.l10n.divers_edit_divingSinceNotSet,
              ),
              trailing: _divingSince != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() {
                        _divingSince = null;
                        _hasChanges = true;
                      }),
                    )
                  : null,
              onTap: _pickDivingSince,
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 7: Insert the section into the form**

In `build`, the children list has (lines ~220-228):

```dart
                  _buildInsuranceSection(),
                  const SizedBox(height: 24),

                  // Notes Section
```

Insert the prior-experience section before `// Notes Section`:

```dart
                  _buildInsuranceSection(),
                  const SizedBox(height: 24),

                  // Prior Experience Section
                  _buildSectionHeader(
                    context,
                    context.l10n.divers_edit_priorExperienceSection,
                  ),
                  _buildPriorExperienceSection(),
                  const SizedBox(height: 24),

                  // Notes Section
```

- [ ] **Step 8: Wire the fields into `_saveDiver`**

In `_saveDiver`, just before `final diver = Diver(` (line ~784), compute the values:

```dart
      final priorCount = int.tryParse(_priorDiveCountController.text.trim());
      final hStr = _priorDiveHoursController.text.trim();
      final mStr = _priorDiveMinutesController.text.trim();
      final priorSeconds = (hStr.isEmpty && mStr.isEmpty)
          ? null
          : (int.tryParse(hStr) ?? 0) * 3600 + (int.tryParse(mStr) ?? 0) * 60;
```

Then add to the `Diver(...)` constructor (after `updatedAt: now,`):

```dart
        priorDiveCount: priorCount,
        priorDiveTimeSeconds: priorSeconds,
        divingSince: _divingSince,
```

- [ ] **Step 9: Run the test to verify it passes**

Run: `flutter test test/features/divers/presentation/pages/diver_edit_prior_experience_test.dart`
Expected: PASS. If the save-button finder or page constructor differs, adjust per the file and re-run.

- [ ] **Step 10: Format, analyze, commit**

```bash
dart format lib/features/divers/presentation/pages/diver_edit_page.dart test/features/divers/presentation/pages/diver_edit_prior_experience_test.dart
flutter analyze
git add lib/features/divers/presentation/pages/diver_edit_page.dart test/features/divers/presentation/pages/diver_edit_prior_experience_test.dart
git commit -m "feat(divers): add prior-experience entry to diver edit form (#331)"
```

---

## Task 7: Combined totals + breakdown on the Stats page

**Files:**
- Modify: `lib/features/statistics/presentation/pages/statistics_overview_page.dart`
- Test: `test/features/statistics/presentation/pages/statistics_overview_prior_experience_test.dart`

- [ ] **Step 1: Write the failing widget test**

Create `test/features/statistics/presentation/pages/statistics_overview_prior_experience_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/statistics/presentation/pages/statistics_overview_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

DiveStatistics _stats() => DiveStatistics(
      totalDives: 312,
      totalTimeSeconds: 43 * 3600,
      maxDepth: 30,
      avgMaxDepth: 18,
      totalSites: 5,
      firstDiveDate: DateTime(2020),
    );

Diver _diver({int? count, int? seconds, DateTime? since}) => Diver(
      id: 'd1', name: 'A',
      priorDiveCount: count, priorDiveTimeSeconds: seconds, divingSince: since,
      createdAt: DateTime(2026), updatedAt: DateTime(2026),
    );

Future<void> _pump(WidgetTester tester, Diver diver) async {
  tester.view.physicalSize = const Size(700, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...overrides,
        diveStatisticsProvider.overrideWith((ref) async => _stats()),
        currentDiverProvider.overrideWith((ref) async => diver),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: StatisticsOverviewPage()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows combined total + breakdown + diving since', (tester) async {
    await _pump(tester, _diver(
      count: 1200, seconds: 1150 * 3600, since: DateTime(1990)));
    expect(find.textContaining('1512'), findsWidgets);
    expect(find.textContaining('logged'), findsWidgets);
    expect(find.textContaining('1990'), findsOneWidget);
  });

  testWidgets('no prior experience -> logged-only, no breakdown', (tester) async {
    await _pump(tester, _diver());
    expect(find.text('312'), findsOneWidget);
    expect(find.textContaining('prior'), findsNothing);
    expect(find.textContaining('Diving since'), findsNothing);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/statistics/presentation/pages/statistics_overview_prior_experience_test.dart`
Expected: FAIL — the page shows `312` (logged) not `1512`, and no breakdown.

- [ ] **Step 3: Import dependencies**

In `statistics_overview_page.dart`, add to the import block:

```dart
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/statistics/domain/career_totals.dart';
```

- [ ] **Step 4: Build `CareerTotals` in `_OverviewBody` and pass it to the grid**

In `_OverviewBody.build`, after `final fmt = UnitFormatter(settings);` add:

```dart
    final diver = ref.watch(currentDiverProvider).valueOrNull;
    final career = CareerTotals.from(
      loggedDives: stats.totalDives,
      loggedTimeSeconds: stats.totalTimeSeconds,
      firstLoggedDive: stats.firstDiveDate,
      priorDives: diver?.priorDiveCount,
      priorTimeSeconds: diver?.priorDiveTimeSeconds,
      divingSince: diver?.divingSince,
    );
```

Change the grid construction from `_AggregateGrid(stats: stats, fmt: fmt)` to:

```dart
          _AggregateGrid(stats: stats, fmt: fmt, career: career),
          if (career.divingSinceResolved != null) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                context.l10n.statistics_divingSince(
                  career.divingSinceResolved!.year,
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
```

(`context.l10n` is available via the existing `app/l10n/l10n_extension.dart` import.)

- [ ] **Step 5: Accept `career` in `_AggregateGrid` and wire the two cards**

Change the `_AggregateGrid` fields/constructor:

```dart
class _AggregateGrid extends StatelessWidget {
  final DiveStatistics stats;
  final UnitFormatter fmt;
  final CareerTotals career;
  const _AggregateGrid({
    required this.stats,
    required this.fmt,
    required this.career,
  });
```

Replace the "Total Dives" card with:

```dart
      _StatCard(
        icon: Icons.waves,
        label: 'Total Dives',
        value: '${career.combinedDives}',
        subtitle: career.hasPriorDives
            ? context.l10n.statistics_priorBreakdown(
                '${career.loggedDives}', '${career.priorDives}')
            : null,
        color: Colors.blue,
      ),
```

Replace the "Total Time" card with:

```dart
      _StatCard(
        icon: Icons.timer,
        label: 'Total Time',
        value: career.combinedTimeFormatted,
        subtitle: career.hasPriorTime
            ? context.l10n.statistics_priorBreakdown(
                '${career.loggedHours}h', '${career.priorHours}h')
            : null,
        color: Colors.teal,
      ),
```

> `_AggregateGrid` is a `StatelessWidget` (no `context.l10n` until `build`). Since these cards are built inside `build(BuildContext context)`, `context.l10n` is in scope there — the `cards` list is already constructed inside `build`, so this compiles as-is.

- [ ] **Step 6: Add an optional `subtitle` to `_StatCard`**

Change the `_StatCard` fields/constructor:

```dart
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final Color color;
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    required this.color,
  });
```

In `_StatCard.build`, after the `FittedBox(... child: Text(value, ...))` block and before `const SizedBox(height: 2)`, add:

```dart
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `flutter test test/features/statistics/presentation/pages/statistics_overview_prior_experience_test.dart`
Expected: PASS.

- [ ] **Step 8: Guard against regressions in the existing stats page test**

Run the existing overview test if present:
Run: `flutter test test/features/statistics/`
Expected: PASS (the logged-only path is unchanged when no prior experience and no `currentDiverProvider` override — `valueOrNull` is null, so `career` equals logged-only).

- [ ] **Step 9: Format, analyze, commit**

```bash
dart format lib/features/statistics/presentation/pages/statistics_overview_page.dart test/features/statistics/presentation/pages/statistics_overview_prior_experience_test.dart
flutter analyze
git add lib/features/statistics/presentation/pages/statistics_overview_page.dart test/features/statistics/presentation/pages/statistics_overview_prior_experience_test.dart
git commit -m "feat(stats): show combined career totals with logged+prior breakdown (#331)"
```

---

## Final verification

- [ ] **Run the full feature test set:**

```bash
flutter test \
  test/core/database/migration_v84_prior_experience_test.dart \
  test/features/divers/domain/diver_prior_experience_test.dart \
  test/features/divers/data/repositories/diver_repository_prior_experience_test.dart \
  test/features/statistics/domain/career_totals_test.dart \
  test/features/divers/presentation/pages/diver_edit_prior_experience_test.dart \
  test/features/statistics/presentation/pages/statistics_overview_prior_experience_test.dart
```

- [ ] **Whole-project analyze + format check:**

```bash
flutter analyze
dart format --set-exit-if-changed lib/ test/
```

- [ ] **Sync serialization check (low risk, confirm):** verify how `divers` rows are exported for sync. Run `grep -rn "divers" lib/core/services/sync lib/core/data/repositories/sync_repository.dart` and confirm rows serialize generically (full row / `toJson` / `SELECT *`) rather than an explicit column allowlist. If an explicit column list exists, add `prior_dive_count`, `prior_dive_time_seconds`, `diving_since`. (Row-level HLC already bumps on update via `markRecordPending('divers', ...)`.)

- [ ] **Manual smoke (device/sim):** edit a diver, enter 1200 prior dives / 1150 prior hours / diving since 1990; open Stats; confirm combined totals, breakdown, and "Diving since 1990"; clear the fields and confirm the page returns to logged-only.

## Notes on scope

- `getStatistics()` and `DiveStatistics` are intentionally NOT modified: `firstDiveDate` already exists, and Total Dives/Total Time stay logged-only at the data layer. The combine happens only in the presentation `CareerTotals`.
- `divesPerMonth` / `divesPerYear` / averages / max depth / charts are intentionally left logged-only (the scope decision). Do not feed `career.combined*` into them.
