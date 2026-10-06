# Visibility Scale Calibration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Store visibility as a measured distance and derive the good/poor
adjective from a per-diver calibration, so a cold-water diver's best day is not
permanently filed as low-end "Moderate".

**Architecture:** A new nullable `dives.visibility_meters` column becomes the
canonical fact. The existing `dives.visibility` TEXT bucket is retained but
becomes read-only legacy. A pure `VisibilityScale` value object maps a distance
to one of four bands using thresholds chosen by the diver (preset or custom,
stored on `diver_settings`). All display flows through one formatter.

**Tech Stack:** Flutter 3.x, Drift ORM (SQLite), Riverpod, `flutter_localizations`
with ARB files.

**Design spec:** `docs/superpowers/specs/2026-08-07-visibility-scale-calibration-design.md`

## Global Constraints

- Schema version for this work is **v144**. `currentSchemaVersion` is `142` on
  `origin/main` (`database.dart:2935`); v143 is claimed by the unmerged media
  integration branch (PR #894). Re-grep `origin/main` before pushing.
- Column additions MUST use the idempotent `_assert<Thing>Column()` pattern and
  be called from BOTH the `onUpgrade` version gate AND the `beforeOpen`
  backstop. Plain `m.addColumn()` in the ladder alone is a defect - see
  `database.dart:7353-7355`.
- Every `_assert*` helper returns early when `PRAGMA table_info` is empty, so
  minimal migration-test fixtures without the table do not fail.
- All distances are stored in **metric** (meters) and converted only for display.
  Never store a converted value.
- Anything displaying units MUST respect the active diver's unit settings.
- Enum `displayName` stays English (data interchange). On-screen text goes
  through `AppLocalizations`. See `environment_enum_display.dart:6-10`.
- New user-facing strings MUST be added to **all 12 locale ARB files**
  (`en, de, es, fr, it, nl, pt, zh, hu, ar, he`, plus the template).
- `dart format .` must produce no changes. `flutter analyze` must be clean
  (infos are fatal in CI).
- Never write a legacy-bucket clear with `Value.absent()`. Use `Value(null)`.
- No emojis in code, comments, or docs.
- Run `dart run build_runner build --delete-conflicting-outputs` after any
  change to Drift tables or ARB files.

## File Structure

**Create:**

| Path | Responsibility |
| ------ | ---------------- |
| `lib/core/domain/visibility/visibility_scale.dart` | Pure value object: presets, thresholds, distance -> band. No I/O. |
| `lib/features/dive_log/presentation/formatters/visibility_display.dart` | Localized, unit-aware rendering of a distance, a band name, and a legacy band range. |
| `test/core/domain/visibility/visibility_scale_test.dart` | Band boundary and validation tests. |
| `test/features/dive_log/presentation/formatters/visibility_display_test.dart` | Formatter tests. |
| `test/core/database/migration_v144_test.dart` | Migration test. |
| `test/features/settings/visibility_scale_settings_test.dart` | Settings round-trip tests. |
| `test/features/statistics/visibility_distribution_test.dart` | Mixed legacy/numeric binning tests. |

**Modify:**

| Path | Change |
| ------ | -------- |
| `lib/core/constants/enums.dart:31-40` | Add metric band bounds to `Visibility`. Keep `displayName`. |
| `lib/core/database/database.dart` | New columns, two `_assert*` helpers, v144 ladder step, backstops, version bump. |
| `lib/features/dive_log/domain/entities/dive.dart` | Add `visibilityMeters`. |
| `lib/features/dive_log/data/repositories/dive_repository_impl.dart` | Map the new column both directions; clear legacy on numeric write. |
| `lib/features/settings/presentation/providers/settings_providers.dart` | `AppSettings` gains scale fields. |
| `lib/features/dive_log/presentation/pages/dive_edit_page.dart` | Replace the enum picker with a numeric field plus live adjective. |
| `lib/core/constants/dive_field_extractor.dart:50-51` | Return the raw metric double. |
| `lib/features/statistics/data/repositories/statistics_repository.dart:971` | Bin in Dart, not SQL. |
| UDDF / Subsurface / CSV import and export services | Carry the real number. |
| `lib/l10n/arb/app_*.arb` (12 files) | New keys. |

---

### Task 1: VisibilityScale value object

Pure Dart, no dependencies on Flutter, Drift, or Riverpod. This is the whole
calibration model and everything else consumes it.

**Files:**
- Create: `lib/core/domain/visibility/visibility_scale.dart`
- Test: `test/core/domain/visibility/visibility_scale_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum VisibilityScalePreset { tropical, temperate, coldWater, custom }`
  - `enum VisibilityBand { poor, moderate, good, excellent }`
  - `class VisibilityScale` with `const VisibilityScale({required double excellentAtOrAboveM, required double goodAtOrAboveM, required double moderateAtOrAboveM})`
  - `static const VisibilityScale tropical / temperate / coldWater`
  - `static VisibilityScale forPreset(VisibilityScalePreset preset, {double? excellentM, double? goodM, double? moderateM})`
  - `VisibilityBand bandFor(double meters)`
  - `bool get isValid`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/domain/visibility/visibility_scale_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';

void main() {
  group('VisibilityScale.bandFor', () {
    test('tropical preset reproduces the pre-v144 thresholds', () {
      const scale = VisibilityScale.tropical;
      expect(scale.bandFor(31), VisibilityBand.excellent);
      expect(scale.bandFor(20), VisibilityBand.good);
      expect(scale.bandFor(10), VisibilityBand.moderate);
      expect(scale.bandFor(2), VisibilityBand.poor);
    });

    test('boundaries are inclusive at the lower edge', () {
      const scale = VisibilityScale.tropical;
      expect(scale.bandFor(30), VisibilityBand.excellent);
      expect(scale.bandFor(29.99), VisibilityBand.good);
      expect(scale.bandFor(15), VisibilityBand.good);
      expect(scale.bandFor(14.99), VisibilityBand.moderate);
      expect(scale.bandFor(5), VisibilityBand.moderate);
      expect(scale.bandFor(4.99), VisibilityBand.poor);
    });

    test('cold-water preset calls a 6 m day good and a 12 m day excellent', () {
      const scale = VisibilityScale.coldWater;
      expect(scale.bandFor(6), VisibilityBand.good);
      expect(scale.bandFor(12), VisibilityBand.excellent);
      expect(scale.bandFor(1.5), VisibilityBand.poor);
    });

    test('zero and negative distances are poor, not a crash', () {
      expect(VisibilityScale.tropical.bandFor(0), VisibilityBand.poor);
      expect(VisibilityScale.tropical.bandFor(-1), VisibilityBand.poor);
    });
  });

  group('VisibilityScale.forPreset', () {
    test('named presets ignore the custom values', () {
      final scale = VisibilityScale.forPreset(
        VisibilityScalePreset.coldWater,
        excellentM: 99,
        goodM: 88,
        moderateM: 77,
      );
      expect(scale, VisibilityScale.coldWater);
    });

    test('custom uses supplied values', () {
      final scale = VisibilityScale.forPreset(
        VisibilityScalePreset.custom,
        excellentM: 18,
        goodM: 9,
        moderateM: 3,
      );
      expect(scale.bandFor(18), VisibilityBand.excellent);
      expect(scale.bandFor(9), VisibilityBand.good);
      expect(scale.bandFor(3), VisibilityBand.moderate);
    });

    test('custom falls back to tropical when values are missing', () {
      final scale = VisibilityScale.forPreset(VisibilityScalePreset.custom);
      expect(scale, VisibilityScale.tropical);
    });

    test('custom falls back to tropical when values are invalid', () {
      final scale = VisibilityScale.forPreset(
        VisibilityScalePreset.custom,
        excellentM: 5,
        goodM: 10,
        moderateM: 20,
      );
      expect(scale, VisibilityScale.tropical);
    });
  });

  group('VisibilityScale.isValid', () {
    test('requires strictly descending positive thresholds', () {
      expect(
        const VisibilityScale(
          excellentAtOrAboveM: 12,
          goodAtOrAboveM: 6,
          moderateAtOrAboveM: 2,
        ).isValid,
        isTrue,
      );
      expect(
        const VisibilityScale(
          excellentAtOrAboveM: 6,
          goodAtOrAboveM: 6,
          moderateAtOrAboveM: 2,
        ).isValid,
        isFalse,
      );
      expect(
        const VisibilityScale(
          excellentAtOrAboveM: 12,
          goodAtOrAboveM: 6,
          moderateAtOrAboveM: 0,
        ).isValid,
        isFalse,
      );
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/domain/visibility/visibility_scale_test.dart`
Expected: FAIL - `Target of URI doesn't exist: visibility_scale.dart`

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/domain/visibility/visibility_scale.dart

/// Which calibration a diver has chosen for visibility adjectives.
enum VisibilityScalePreset { tropical, temperate, coldWater, custom }

/// The four qualitative bands a visibility distance can fall into.
enum VisibilityBand { poor, moderate, good, excellent }

/// Maps a visibility distance in meters to a [VisibilityBand].
///
/// Purely presentational: the stored fact is always the distance, so changing
/// the scale re-labels a logbook without altering any dive.
class VisibilityScale {
  /// A distance at or above this is [VisibilityBand.excellent].
  final double excellentAtOrAboveM;

  /// A distance at or above this (and below [excellentAtOrAboveM]) is good.
  final double goodAtOrAboveM;

  /// A distance at or above this (and below [goodAtOrAboveM]) is moderate.
  /// Anything below it is poor.
  final double moderateAtOrAboveM;

  const VisibilityScale({
    required this.excellentAtOrAboveM,
    required this.goodAtOrAboveM,
    required this.moderateAtOrAboveM,
  });

  /// Reproduces the pre-v144 hardcoded thresholds, so upgrading re-labels
  /// nothing.
  static const tropical = VisibilityScale(
    excellentAtOrAboveM: 30,
    goodAtOrAboveM: 15,
    moderateAtOrAboveM: 5,
  );

  static const temperate = VisibilityScale(
    excellentAtOrAboveM: 20,
    goodAtOrAboveM: 10,
    moderateAtOrAboveM: 4,
  );

  static const coldWater = VisibilityScale(
    excellentAtOrAboveM: 12,
    goodAtOrAboveM: 6,
    moderateAtOrAboveM: 2,
  );

  /// Thresholds must descend strictly and stay positive, otherwise a band
  /// would be unreachable.
  bool get isValid =>
      moderateAtOrAboveM > 0 &&
      goodAtOrAboveM > moderateAtOrAboveM &&
      excellentAtOrAboveM > goodAtOrAboveM;

  /// Resolves a stored preference into a usable scale. Custom values that are
  /// absent or invalid fall back to [tropical] rather than producing an
  /// unreachable band.
  static VisibilityScale forPreset(
    VisibilityScalePreset preset, {
    double? excellentM,
    double? goodM,
    double? moderateM,
  }) {
    switch (preset) {
      case VisibilityScalePreset.tropical:
        return tropical;
      case VisibilityScalePreset.temperate:
        return temperate;
      case VisibilityScalePreset.coldWater:
        return coldWater;
      case VisibilityScalePreset.custom:
        if (excellentM == null || goodM == null || moderateM == null) {
          return tropical;
        }
        final candidate = VisibilityScale(
          excellentAtOrAboveM: excellentM,
          goodAtOrAboveM: goodM,
          moderateAtOrAboveM: moderateM,
        );
        return candidate.isValid ? candidate : tropical;
    }
  }

  VisibilityBand bandFor(double meters) {
    if (meters >= excellentAtOrAboveM) return VisibilityBand.excellent;
    if (meters >= goodAtOrAboveM) return VisibilityBand.good;
    if (meters >= moderateAtOrAboveM) return VisibilityBand.moderate;
    return VisibilityBand.poor;
  }

  @override
  bool operator ==(Object other) =>
      other is VisibilityScale &&
      other.excellentAtOrAboveM == excellentAtOrAboveM &&
      other.goodAtOrAboveM == goodAtOrAboveM &&
      other.moderateAtOrAboveM == moderateAtOrAboveM;

  @override
  int get hashCode =>
      Object.hash(excellentAtOrAboveM, goodAtOrAboveM, moderateAtOrAboveM);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/domain/visibility/visibility_scale_test.dart`
Expected: PASS (all groups)

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/domain/visibility/visibility_scale.dart test/core/domain/visibility/visibility_scale_test.dart
git commit -m "Add VisibilityScale value object with calibration presets"
```

---

### Task 2: Schema v144 columns and migration

**Files:**
- Modify: `lib/core/database/database.dart`
- Test: `test/core/database/migration_v144_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `dives.visibility_meters` (REAL, nullable);
  `diver_settings.visibility_scale_preset` (TEXT NOT NULL DEFAULT 'tropical'),
  `visibility_scale_excellent_m`, `visibility_scale_good_m`,
  `visibility_scale_moderate_m` (REAL, nullable). Drift getters
  `visibilityMeters`, `visibilityScalePreset`, `visibilityScaleExcellentM`,
  `visibilityScaleGoodM`, `visibilityScaleModerateM`.
  Helpers `_assertVisibilityMetersColumn()`, `_assertVisibilityScaleColumns()`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/database/migration_v144_test.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('v144 adds visibility_meters to dives', () async {
    expect(await _columns(db, 'dives'), contains('visibility_meters'));
  });

  test('v144 keeps the legacy visibility column', () async {
    expect(await _columns(db, 'dives'), contains('visibility'));
  });

  test('v144 adds the calibration columns to diver_settings', () async {
    final cols = await _columns(db, 'diver_settings');
    expect(cols, contains('visibility_scale_preset'));
    expect(cols, contains('visibility_scale_excellent_m'));
    expect(cols, contains('visibility_scale_good_m'));
    expect(cols, contains('visibility_scale_moderate_m'));
  });

  test('schema version is 144', () {
    expect(AppDatabase.currentSchemaVersion, 144);
  });

  test('assert helpers are idempotent when run twice', () async {
    await db.assertVisibilityColumnsForTesting();
    await db.assertVisibilityColumnsForTesting();
    expect(await _columns(db, 'dives'), contains('visibility_meters'));
  });

  test('legacy bucket rows are not backfilled', () async {
    await db.customStatement(
      "INSERT INTO dives (id, dive_date_time, visibility, created_at, updated_at) "
      "VALUES ('legacy-1', 0, 'moderate', 0, 0)",
    );
    final row = await db
        .customSelect("SELECT visibility, visibility_meters FROM dives WHERE id = 'legacy-1'")
        .getSingle();
    expect(row.read<String?>('visibility'), 'moderate');
    expect(row.read<double?>('visibility_meters'), isNull);
  });
}
```

Note: match the `AppDatabase.forTesting` constructor and the required `dives`
insert columns to what already exists in the repo's other migration tests. If
`assertVisibilityColumnsForTesting` conflicts with an existing test-hook naming
convention, follow the repo's convention instead and update this test.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/database/migration_v144_test.dart`
Expected: FAIL - `visibility_meters` absent, `currentSchemaVersion` is 142.

- [ ] **Step 3: Add the Drift columns**

In `lib/core/database/database.dart`, in the `Dives` table beside the existing
`visibility` column (near line 584):

```dart
  // v144: measured horizontal visibility in meters. Canonical from v144 on.
  // The legacy `visibility` bucket column above is retained read-only for
  // dives logged before v144 and is cleared when a numeric value is written.
  RealColumn get visibilityMeters => real().nullable()();
```

In the `DiverSettings` table, beside `defaultCurrency`:

```dart
  // v144: per-diver calibration for visibility adjectives. Presentational
  // only -- dives always store the measured distance.
  TextColumn get visibilityScalePreset =>
      text().withDefault(const Constant('tropical'))();
  RealColumn get visibilityScaleExcellentM => real().nullable()();
  RealColumn get visibilityScaleGoodM => real().nullable()();
  RealColumn get visibilityScaleModerateM => real().nullable()();
```

- [ ] **Step 4: Add the idempotent helpers**

Beside `_assertTripReturnFlightColumn` (around `database.dart:4120`):

```dart
  /// Idempotent DDL for the v144 dives.visibility_meters column. Called from
  /// the v144 onUpgrade step and the beforeOpen backstop, matching the
  /// _assertTripReturnFlightColumn pattern so a schema-version collision
  /// cannot strand a database without it. Self-guarding when the table is
  /// absent (minimal migration-test fixtures).
  Future<void> _assertVisibilityMetersColumn() async {
    final cols = await customSelect("PRAGMA table_info('dives')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('visibility_meters')) {
      await customStatement(
        'ALTER TABLE dives ADD COLUMN visibility_meters REAL',
      );
    }
  }

  /// Idempotent DDL for the v144 diver_settings visibility calibration
  /// columns. Same dual-call contract as [_assertVisibilityMetersColumn].
  Future<void> _assertVisibilityScaleColumns() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('visibility_scale_preset')) {
      await customStatement(
        "ALTER TABLE diver_settings ADD COLUMN visibility_scale_preset "
        "TEXT NOT NULL DEFAULT 'tropical'",
      );
    }
    if (!names.contains('visibility_scale_excellent_m')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN visibility_scale_excellent_m REAL',
      );
    }
    if (!names.contains('visibility_scale_good_m')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN visibility_scale_good_m REAL',
      );
    }
    if (!names.contains('visibility_scale_moderate_m')) {
      await customStatement(
        'ALTER TABLE diver_settings ADD COLUMN visibility_scale_moderate_m REAL',
      );
    }
  }

  /// Test hook: run the v144 visibility DDL on demand so tests can assert it
  /// is idempotent.
  Future<void> assertVisibilityColumnsForTesting() async {
    await _assertVisibilityMetersColumn();
    await _assertVisibilityScaleColumns();
  }
```

- [ ] **Step 5: Wire the ladder step and the backstop**

In `onUpgrade`, immediately after the `if (from < 142)` block (around
`database.dart:7359`):

```dart
        // v144: dives.visibility_meters + diver_settings visibility scale.
        // v143 is reserved by the media integration branch (PR #894); the
        // beforeOpen backstop heals any DB stranded between.
        if (from < 144) {
          await _assertVisibilityMetersColumn();
          await _assertVisibilityScaleColumns();
        }
        if (from < 144) await reportProgress();
```

In `beforeOpen`, beside the other backstops (near `database.dart:7477`):

```dart
        // v144 backstop: re-assert the visibility measurement and calibration
        // columns.
        await _assertVisibilityMetersColumn();
        await _assertVisibilityScaleColumns();
```

Bump `database.dart:2935`:

```dart
  static const int currentSchemaVersion = 144;
```

- [ ] **Step 6: Regenerate and run the test**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter test test/core/database/migration_v144_test.dart
```

Expected: PASS

- [ ] **Step 7: Commit**

```bash
dart format .
flutter analyze
git add lib/core/database/ test/core/database/migration_v144_test.dart
git commit -m "Add schema v144 visibility measurement and calibration columns"
```

---

### Task 3: Domain entity and repository plumbing

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (field at :45, ctor
  at :181, `copyWith` at :556 and :649, props list at :745)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart`
  (row mapping at :2933 and :3304, plus the companion writes)
- Test: `test/features/dive_log/visibility_meters_persistence_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `Dive.visibilityMeters` (`double?`), persisted round-trip, and the
  invariant that writing a number clears the legacy bucket.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_log/visibility_meters_persistence_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('visibilityMeters persistence', () {
    test('round-trips a measured distance', () async {
      // Arrange: create a dive with visibilityMeters == 6.0 through the
      // repository, using the same in-memory AppDatabase + repository setup
      // the existing dive repository tests use.
      // Act: read it back by id.
      // Assert: visibilityMeters == 6.0.
    });

    test('writing a number clears the legacy bucket', () async {
      // Arrange: insert a legacy dive with visibility = 'moderate' and
      // visibility_meters NULL.
      // Act: update it through the repository with visibilityMeters = 6.0.
      // Assert: raw SQL shows visibility IS NULL and visibility_meters = 6.0.
      // This is the Value(null) vs Value.absent() regression guard.
    });

    test('a legacy dive with no numeric value keeps its bucket', () async {
      // Arrange: legacy dive with visibility = 'moderate'.
      // Act: update an unrelated field (e.g. notes).
      // Assert: visibility is still 'moderate'.
    });
  });
}
```

Replace each comment block with real arrange/act/assert using the existing
repository test harness in `test/features/dive_log/`. Do not leave the bodies
empty - find the nearest existing repository test and copy its setup verbatim.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/visibility_meters_persistence_test.dart`
Expected: FAIL - `Dive` has no `visibilityMeters`.

- [ ] **Step 3: Add the entity field**

In `dive.dart`, beside the existing `visibility` field:

```dart
  /// Measured horizontal visibility in meters. Canonical from v144.
  ///
  /// When non-null this supersedes [visibility], which only survives for dives
  /// logged before v144 and records a coarse band rather than a measurement.
  final double? visibilityMeters;
```

Add it to the constructor, to both `copyWith` signature and body, and to the
props/equality list at :745.

- [ ] **Step 4: Map it in the repository**

At both row-mapping sites (`:2933` and `:3304`), beside the existing
`visibility:` mapping, add:

```dart
      visibilityMeters: row.visibilityMeters,
```

At every companion write that sets `visibility`, apply the precedence rule:

```dart
      // A measured distance supersedes the legacy bucket. Value(null) rather
      // than Value.absent(): absent() preserves the existing value on a
      // toCompanion write, which would leave both columns populated.
      visibilityMeters: Value(dive.visibilityMeters),
      visibility: dive.visibilityMeters != null
          ? const Value(null)
          : Value(dive.visibility?.name),
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/dive_log/visibility_meters_persistence_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/ test/features/dive_log/visibility_meters_persistence_test.dart
git commit -m "Persist measured visibility and clear the legacy bucket on write"
```

---

### Task 4: Band bounds on the legacy enum

**Files:**
- Modify: `lib/core/constants/enums.dart:31-40`
- Test: `test/core/constants/visibility_band_bounds_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `Visibility.bandMinM` (`double?`), `Visibility.bandMaxM` (`double?`).
  `displayName` is unchanged.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/constants/visibility_band_bounds_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';

void main() {
  test('legacy bands expose their true metric bounds', () {
    expect(Visibility.excellent.bandMinM, 30);
    expect(Visibility.excellent.bandMaxM, isNull);
    expect(Visibility.good.bandMinM, 15);
    expect(Visibility.good.bandMaxM, 30);
    expect(Visibility.moderate.bandMinM, 5);
    expect(Visibility.moderate.bandMaxM, 15);
    expect(Visibility.poor.bandMinM, isNull);
    expect(Visibility.poor.bandMaxM, 5);
    expect(Visibility.unknown.bandMinM, isNull);
    expect(Visibility.unknown.bandMaxM, isNull);
  });

  test('displayName is unchanged for data interchange', () {
    expect(Visibility.moderate.displayName, 'Moderate (5-15m / 15-50ft)');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/constants/visibility_band_bounds_test.dart`
Expected: FAIL - `bandMinM` is not defined.

- [ ] **Step 3: Write the implementation**

```dart
/// Visibility conditions.
///
/// Legacy: dives logged before v144 store one of these buckets instead of a
/// measured distance. New dives store `dives.visibility_meters`. The bounds
/// record what a bucket actually means so the UI can show the honest range
/// rather than guessing a point value.
///
/// [displayName] stays English on purpose - it feeds data interchange. On-screen
/// text goes through the formatters in
/// `dive_log/presentation/formatters/visibility_display.dart`.
enum Visibility {
  excellent('Excellent (>30m / >100ft)', 30, null),
  good('Good (15-30m / 50-100ft)', 15, 30),
  moderate('Moderate (5-15m / 15-50ft)', 5, 15),
  poor('Poor (<5m / <15ft)', null, 5),
  unknown('Unknown', null, null);

  final String displayName;

  /// Inclusive lower bound of the band in meters, or null when unbounded below.
  final double? bandMinM;

  /// Exclusive upper bound of the band in meters, or null when unbounded above.
  final double? bandMaxM;

  const Visibility(this.displayName, this.bandMinM, this.bandMaxM);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/constants/visibility_band_bounds_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib/core/constants/enums.dart test/core/constants/visibility_band_bounds_test.dart
git commit -m "Record true metric bounds on the legacy visibility bands"
```

---

### Task 5: Localization keys

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the 11 other locale files
- Test: covered by Task 6

**Interfaces:**
- Produces these `AppLocalizations` getters and methods:
  - `enum_visibilityBand_excellent` / `_good` / `_moderate` / `_poor`
  - `visibility_range_between(String min, String max, String unit)`
  - `visibility_range_over(String min, String unit)`
  - `visibility_range_under(String max, String unit)`
  - `settings_visibilityScale_title` / `_subtitle`
  - `settings_visibilityScale_preset_tropical` / `_temperate` / `_coldWater` / `_custom`
  - `settings_visibilityScale_customExcellent` / `_customGood` / `_customModerate`
  - `settings_visibilityScale_invalidOrder`
  - `statistics_conditions_visibility_legacySuffix(String band)`

- [ ] **Step 1: Add the English keys**

```json
  "enum_visibilityBand_excellent": "Excellent",
  "enum_visibilityBand_good": "Good",
  "enum_visibilityBand_moderate": "Moderate",
  "enum_visibilityBand_poor": "Poor",
  "visibility_range_between": "{min}-{max} {unit}",
  "@visibility_range_between": {
    "placeholders": {
      "min": { "type": "String" },
      "max": { "type": "String" },
      "unit": { "type": "String" }
    }
  },
  "visibility_range_over": "over {min} {unit}",
  "@visibility_range_over": {
    "placeholders": {
      "min": { "type": "String" },
      "unit": { "type": "String" }
    }
  },
  "visibility_range_under": "under {max} {unit}",
  "@visibility_range_under": {
    "placeholders": {
      "max": { "type": "String" },
      "unit": { "type": "String" }
    }
  },
  "settings_visibilityScale_title": "Visibility scale",
  "settings_visibilityScale_subtitle": "Which distances count as good visibility where you dive",
  "settings_visibilityScale_preset_tropical": "Tropical",
  "settings_visibilityScale_preset_temperate": "Temperate",
  "settings_visibilityScale_preset_coldWater": "Cold water / Inland",
  "settings_visibilityScale_preset_custom": "Custom",
  "settings_visibilityScale_customExcellent": "Excellent at or above",
  "settings_visibilityScale_customGood": "Good at or above",
  "settings_visibilityScale_customModerate": "Moderate at or above",
  "settings_visibilityScale_invalidOrder": "Each value must be smaller than the one above it, and greater than zero",
  "statistics_conditions_visibility_legacySuffix": "{band} (logged before measurement)",
  "@statistics_conditions_visibility_legacySuffix": {
    "placeholders": {
      "band": { "type": "String" }
    }
  },
```

Leave the now-unused `enum_visibility_excellent` .. `enum_visibility_unknown`
keys in place; removing them is out of scope and they are referenced by no Dart.

- [ ] **Step 2: Translate into all 11 other locales**

Add the same keys to `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_it.arb`,
`app_nl.arb`, `app_pt.arb`, `app_zh.arb`, `app_hu.arb`, `app_ar.arb`,
`app_he.arb`, and any other locale file present. Translate the values; do not
leave English placeholders. Keep the `@key` placeholder metadata identical.

- [ ] **Step 3: Regenerate and verify**

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
```

Expected: no missing-translation warnings.

- [ ] **Step 4: Commit**

```bash
dart format .
git add lib/l10n/
git commit -m "Add localization keys for calibrated visibility bands"
```

---

### Task 6: Visibility display formatter

**Files:**
- Create: `lib/features/dive_log/presentation/formatters/visibility_display.dart`
- Test: `test/features/dive_log/presentation/formatters/visibility_display_test.dart`

**Interfaces:**
- Consumes: `VisibilityScale`, `VisibilityBand` (Task 1); `Visibility.bandMinM` /
  `bandMaxM` (Task 4); the l10n keys (Task 5); `UnitFormatter`.
- Produces:
  - `String visibilityBandName(VisibilityBand band, AppLocalizations l10n)`
  - `String formatMeasuredVisibility(double meters, VisibilityScale scale, AppLocalizations l10n, UnitFormatter units)` -> `"20 ft . Excellent"`
  - `String? formatLegacyVisibilityBand(Visibility legacy, AppLocalizations l10n, UnitFormatter units)` -> `"15-50 ft"`, null for `Visibility.unknown`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_log/presentation/formatters/visibility_display_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/features/dive_log/presentation/formatters/visibility_display.dart';

void main() {
  // Build `l10n` via AppLocalizations.delegate.load(const Locale('en')) and a
  // UnitFormatter over AppSettings with DepthUnit.meters / DepthUnit.feet,
  // following the existing formatter tests in this directory.

  test('measured visibility shows distance and calibrated adjective', () {
    // metric, cold-water scale, 6 m -> "6m . Good"
  });

  test('same distance re-labels under a different scale', () {
    // tropical scale, 6 m -> "6m . Moderate"
    // cold-water scale, 6 m -> "6m . Good"
    // Asserts calibration is presentational only.
  });

  test('imperial formatting converts the distance but not the band', () {
    // feet, cold-water, 6 m -> starts with "20" and ends with "Good"
  });

  test('legacy band renders as an honest range, never an adjective', () {
    // metric: Visibility.moderate -> "5-15m"
    // imperial: Visibility.moderate -> "16-49ft" (whatever the converter
    // yields at 0 decimals -- assert against the real UnitFormatter output,
    // do not hardcode a guess)
  });

  test('unbounded legacy bands use over/under phrasing', () {
    // Visibility.excellent -> "over 30m"
    // Visibility.poor -> "under 5m"
  });

  test('unknown legacy band returns null', () {
    // Visibility.unknown -> null
  });
}
```

Fill each body using the existing formatter-test setup in
`test/features/dive_log/presentation/formatters/`. For the imperial range
assertion, compute the expected string from `UnitFormatter` rather than
hardcoding a converted number.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/formatters/visibility_display_test.dart`
Expected: FAIL - `visibility_display.dart` does not exist.

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/dive_log/presentation/formatters/visibility_display.dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized name for a calibrated band.
String visibilityBandName(VisibilityBand band, AppLocalizations l10n) =>
    switch (band) {
      VisibilityBand.excellent => l10n.enum_visibilityBand_excellent,
      VisibilityBand.good => l10n.enum_visibilityBand_good,
      VisibilityBand.moderate => l10n.enum_visibilityBand_moderate,
      VisibilityBand.poor => l10n.enum_visibilityBand_poor,
    };

/// Renders a measured distance plus the adjective the diver's calibration
/// assigns it, e.g. "20ft . Excellent".
String formatMeasuredVisibility(
  double meters,
  VisibilityScale scale,
  AppLocalizations l10n,
  UnitFormatter units,
) {
  final distance = units.formatDistance(meters);
  final band = visibilityBandName(scale.bandFor(meters), l10n);
  return '$distance · $band';
}

/// Renders a pre-v144 bucket as the distance range it actually means.
///
/// Deliberately never returns an adjective: the stored bucket only tells us the
/// dive fell somewhere in this range, so applying the diver's calibration would
/// be a guess about data we do not have.
String? formatLegacyVisibilityBand(
  Visibility legacy,
  AppLocalizations l10n,
  UnitFormatter units,
) {
  final min = legacy.bandMinM;
  final max = legacy.bandMaxM;
  if (min == null && max == null) return null;

  final unit = units.depthSymbol;
  String value(double meters) =>
      units.convertDepth(meters).toStringAsFixed(0);

  if (min == null) return l10n.visibility_range_under(value(max!), unit);
  if (max == null) return l10n.visibility_range_over(value(min), unit);
  return l10n.visibility_range_between(value(min), value(max), unit);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/formatters/visibility_display_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/presentation/formatters/visibility_display.dart test/features/dive_log/presentation/formatters/visibility_display_test.dart
git commit -m "Add localized unit-aware visibility formatter"
```

---

### Task 7: Settings model and persistence

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart`
- Test: `test/features/settings/visibility_scale_settings_test.dart`

**Interfaces:**
- Consumes: `VisibilityScalePreset`, `VisibilityScale` (Task 1); the DB columns
  (Task 2).
- Produces: on `AppSettings` - `visibilityScalePreset` (`VisibilityScalePreset`),
  `visibilityScaleExcellentM`, `visibilityScaleGoodM`, `visibilityScaleModerateM`
  (all `double?`), and a derived `VisibilityScale get visibilityScale`.
  On the settings notifier - `Future<void> updateVisibilityScale({required VisibilityScalePreset preset, double? excellentM, double? goodM, double? moderateM})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/settings/visibility_scale_settings_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to the tropical preset so no logbook re-labels on upgrade', () {
    // Build default AppSettings; expect visibilityScalePreset == tropical
    // and visibilityScale == VisibilityScale.tropical.
  });

  test('selecting cold water persists and derives the cold-water scale', () async {
    // Use the existing settings-notifier test harness (see the
    // settings notifier mocks used by other settings tests).
    // Act: updateVisibilityScale(preset: coldWater)
    // Assert: reloaded settings expose VisibilityScale.coldWater.
  });

  test('custom values persist and derive a custom scale', () async {
    // updateVisibilityScale(preset: custom, excellentM: 18, goodM: 9,
    // moderateM: 3); assert bandFor(9) == VisibilityBand.good.
  });

  test('an unrecognized stored preset falls back to tropical', () {
    // Write 'nonsense' into visibility_scale_preset directly; assert the
    // mapper yields VisibilityScalePreset.tropical rather than throwing.
  });
}
```

Fill the bodies using the existing settings test harness. Note the repo's
settings-notifier tests require specific mocks; copy that setup rather than
inventing one.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/visibility_scale_settings_test.dart`
Expected: FAIL - `AppSettings` has no `visibilityScalePreset`.

- [ ] **Step 3: Extend AppSettings**

Add the four fields beside `defaultCurrency` (`settings_providers.dart:114`),
including them in the constructor, `copyWith`, and any `fromRow` / `toCompanion`
mapping. Parse the preset defensively:

```dart
  /// Per-diver calibration for visibility adjectives. Presentational only.
  final VisibilityScalePreset visibilityScalePreset;
  final double? visibilityScaleExcellentM;
  final double? visibilityScaleGoodM;
  final double? visibilityScaleModerateM;

  /// The resolved scale. Custom values that are absent or invalid fall back to
  /// tropical, so a corrupt preference cannot make a band unreachable.
  VisibilityScale get visibilityScale => VisibilityScale.forPreset(
    visibilityScalePreset,
    excellentM: visibilityScaleExcellentM,
    goodM: visibilityScaleGoodM,
    moderateM: visibilityScaleModerateM,
  );
```

When mapping the stored string, use a tolerant lookup:

```dart
      visibilityScalePreset: VisibilityScalePreset.values.firstWhere(
        (p) => p.name == row.visibilityScalePreset,
        orElse: () => VisibilityScalePreset.tropical,
      ),
```

- [ ] **Step 4: Add the notifier method**

```dart
  Future<void> updateVisibilityScale({
    required VisibilityScalePreset preset,
    double? excellentM,
    double? goodM,
    double? moderateM,
  }) async {
    // Persist via the same path the other settings updates use.
  }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/settings/visibility_scale_settings_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
dart format .
flutter analyze
git add lib/features/settings/ test/features/settings/visibility_scale_settings_test.dart
git commit -m "Add per-diver visibility scale calibration setting"
```

---

### Task 8: Dive edit form numeric entry

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`
  (controller alongside `_swellHeightController` at :200; disposal at :797;
  hydration at :651; the `EnumPickerRow<Visibility>` at :3620-3631; the save
  paths at :1061 and :4559; `_conditionsSummary` at :3582; `_conditionsIsEmpty`
  at :3592)
- Test: `test/features/dive_log/dive_edit_visibility_field_test.dart`

**Interfaces:**
- Consumes: the formatter (Task 6), `AppSettings.visibilityScale` (Task 7),
  `Dive.visibilityMeters` (Task 3).
- Produces: numeric entry that writes `Dive.visibilityMeters` in meters.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_log/dive_edit_visibility_field_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('typing a distance shows the calibrated adjective live',
      (tester) async {
    // Pump the dive edit page with cold-water calibration and metric units.
    // Enter "6" into the visibility field.
    // Expect find.text('Good') to be present.
  });

  testWidgets('the same entry reads Moderate under tropical calibration',
      (tester) async {
    // Same, with tropical calibration. Expect 'Moderate'.
  });

  testWidgets('imperial entry is converted to meters for storage',
      (tester) async {
    // Imperial units, enter "20". Save. Expect the saved Dive to carry
    // visibilityMeters of about 6.1 (assert with closeTo, tolerance 0.05).
  });

  testWidgets('a legacy dive shows its band until the diver enters a number',
      (tester) async {
    // Load a dive with visibility == Visibility.moderate and
    // visibilityMeters == null. Expect the band range text, and no adjective.
  });
}
```

Follow the existing dive-edit widget tests for the pump helper. Note the repo's
widget tests need a MaterialApp locale host and can deadlock under fakeAsync
with Drift - copy a working neighbouring test's harness rather than improvising.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/dive_edit_visibility_field_test.dart`
Expected: FAIL - the field is still an enum picker.

- [ ] **Step 3: Replace the picker with a numeric field**

Add the controller beside `_swellHeightController`:

```dart
  final _visibilityController = TextEditingController();
```

Dispose it alongside the others. Hydrate it in the load path:

```dart
          _visibilityController.text = dive.visibilityMeters != null
              ? units.convertDepth(dive.visibilityMeters!).toStringAsFixed(0)
              : '';
```

Replace the `EnumPickerRow<Visibility>` block at :3620-3631 with:

```dart
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FormRow.text(
            label: l10n.diveLog_edit_label_visibility,
            controller: _visibilityController,
            suffixText: units.depthSymbol,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          if (_visibilityAdjective(units) case final adjective?)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Text(
                adjective,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
```

Add the helper. It reads the live text so the adjective tracks typing, and
falls back to the legacy band when the field is empty:

```dart
  /// Live adjective beneath the visibility field, or the legacy band when this
  /// dive predates measured visibility and has not been given a number yet.
  String? _visibilityAdjective(UnitFormatter units) {
    final l10n = context.l10n;
    final typed = double.tryParse(_visibilityController.text);
    if (typed != null) {
      final meters = units.depthToMeters(typed);
      final scale = ref.read(appSettingsProvider).visibilityScale;
      return visibilityBandName(scale.bandFor(meters), l10n);
    }
    if (_selectedVisibility != Visibility.unknown) {
      return formatLegacyVisibilityBand(_selectedVisibility, l10n, units);
    }
    return null;
  }
```

Use whatever the page's real settings accessor is rather than
`appSettingsProvider` if it differs.

- [ ] **Step 4: Update the save paths**

At both save sites (:1061 and :4559), replace the enum write:

```dart
      visibilityMeters: _visibilityController.text.isNotEmpty
          ? units.depthToMeters(
              double.tryParse(_visibilityController.text) ?? 0,
            )
          : null,
```

Do not write `visibility:` at all from the edit form - the repository clears it
when a number is present (Task 3), and a legacy dive left untouched keeps its
bucket.

Update `_conditionsSummary` (:3582) to use the formatter, and
`_conditionsIsEmpty` (:3592) to test `_visibilityController.text.isEmpty`
instead of the enum.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/dive_log/dive_edit_visibility_field_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/dive_edit_visibility_field_test.dart
git commit -m "Enter visibility as a measured distance with a live adjective"
```

---

### Task 9: Read-side display surfaces

**Files:**
- Modify: `lib/core/constants/dive_field_extractor.dart:50-51`
- Modify: the dive detail environment section, `compact_dive_list_tile.dart`,
  `dense_dive_list_tile.dart`, and the table cell formatter for
  `DiveField.visibility`
- Test: `test/features/dive_log/visibility_display_surfaces_test.dart`

**Interfaces:**
- Consumes: the formatter (Task 6), `AppSettings.visibilityScale` (Task 7).
- Produces: `DiveField.visibility` extracts `double?` (raw meters) when a
  measurement exists, matching how `maxDepth` and `swellHeight` already behave.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_log/visibility_display_surfaces_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/dive_field_extractor.dart';

void main() {
  test('extractor returns raw meters for a measured dive', () {
    // Dive with visibilityMeters == 6.0
    // expect(DiveField.visibility.extractFromDive(dive), 6.0);
  });

  test('extractor falls back to the legacy displayName', () {
    // Dive with visibility == Visibility.moderate, visibilityMeters == null
    // expect(..., 'Moderate (5-15m / 15-50ft)');
  });

  test('extractor returns null when neither is set', () {
    // expect(..., isNull);
  });

  testWidgets('dive detail shows distance and adjective', (tester) async {
    // Pump the environment section for a 6 m dive under cold-water
    // calibration; expect text containing 'Good'.
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/visibility_display_surfaces_test.dart`
Expected: FAIL - extractor still returns the bucket displayName.

- [ ] **Step 3: Update the extractor**

```dart
      case DiveField.visibility:
        // Raw metric value, consistent with maxDepth and swellHeight; the
        // UnitFormatter converts at render time. Falls back to the legacy
        // bucket's English label for pre-v144 dives.
        return dive.visibilityMeters ?? dive.visibility?.displayName;
```

Do the same in the `DiveSummary` extraction path if one exists for this field.

- [ ] **Step 4: Update the render surfaces**

Everywhere `dive.visibility?.displayName` currently renders on screen, switch to:

```dart
    final meters = dive.visibilityMeters;
    final text = meters != null
        ? formatMeasuredVisibility(meters, settings.visibilityScale, l10n, units)
        : (dive.visibility != null
            ? formatLegacyVisibilityBand(dive.visibility!, l10n, units)
            : null);
```

- [ ] **Step 5: Run the full dive_log suite**

Run: `flutter test test/features/dive_log/`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
dart format .
flutter analyze
git add lib/ test/features/dive_log/visibility_display_surfaces_test.dart
git commit -m "Render measured visibility with the diver's calibration"
```

---

### Task 10: Settings UI section

**Files:**
- Modify: the units/preferences settings page (the same page that hosts
  `defaultCurrency`)
- Test: `test/features/settings/visibility_scale_page_test.dart`

**Interfaces:**
- Consumes: Task 7's notifier method, Task 5's l10n keys.
- Produces: no new public API.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/settings/visibility_scale_page_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selecting cold water persists the preset', (tester) async {
    // Pump the settings page, tap the cold-water option, expect the notifier
    // to have been called with VisibilityScalePreset.coldWater.
  });

  testWidgets('custom fields appear only for the custom preset',
      (tester) async {
    // Expect the three numeric fields absent for tropical, present for custom.
  });

  testWidgets('non-descending custom values show the validation error',
      (tester) async {
    // Enter 5 / 10 / 20; expect settings_visibilityScale_invalidOrder text and
    // no persistence call.
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/visibility_scale_page_test.dart`
Expected: FAIL - the section does not exist.

- [ ] **Step 3: Build the section**

Add a section beside the unit preferences with a preset selector using the
existing settings-row widgets on that page. When `custom` is selected, show
three `FormRow.text` fields suffixed with `units.depthSymbol`. Validate with
`VisibilityScale.isValid` on the metric-converted values and show
`l10n.settings_visibilityScale_invalidOrder` inline when invalid, blocking the
save.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/settings/visibility_scale_page_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib/features/settings/ test/features/settings/visibility_scale_page_test.dart
git commit -m "Add visibility scale settings section"
```

---

### Task 11: Statistics binning

**Files:**
- Modify: `lib/features/statistics/data/repositories/statistics_repository.dart:970-1006`
- Test: `test/features/statistics/visibility_distribution_test.dart`

**Interfaces:**
- Consumes: `VisibilityScale` (Task 1), the formatter (Task 6).
- Produces: `getVisibilityDistribution({required VisibilityScale scale, ...})` -
  the existing `DistributionSegment` list, now calibration-aware.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/statistics/visibility_distribution_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('numeric dives bin by the supplied calibration', () async {
    // Seed dives at 6 m and 13 m. Query with VisibilityScale.coldWater.
    // Expect one Good segment and one Excellent segment.
  });

  test('the same data re-bins under a different calibration', () async {
    // Same seed, VisibilityScale.tropical: both fall in Moderate.
    // Count 2 in a single segment.
  });

  test('legacy dives form their own segments, never merged into an adjective',
      () async {
    // Seed one dive with visibility = 'moderate', visibility_meters NULL, and
    // one numeric dive at 6 m under cold-water calibration.
    // Expect a Good segment with count 1 and a distinct legacy segment with
    // count 1. Assert the legacy segment is NOT counted as Good.
  });

  test('dives with neither value are excluded', () async {
    // Seed a dive with both null; expect it in no segment.
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/statistics/visibility_distribution_test.dart`
Expected: FAIL - the method takes no scale parameter.

- [ ] **Step 3: Move binning into Dart**

Change the query to select both columns, keeping the existing `DiveFilterSql`
predicate and diver filter, and widen the WHERE so a row qualifies when
**either** column is populated:

```sql
        SELECT visibility, visibility_meters
        FROM dives
        WHERE (visibility_meters IS NOT NULL
               OR (visibility IS NOT NULL AND visibility != ''))
          $diverFilter ${df.clause}
```

Then bin in Dart: numeric rows through `scale.bandFor`, legacy rows into a
per-bucket tally kept separate from the calibrated bands. Order the calibrated
segments excellent-to-poor, then append legacy segments.

The consuming provider (`statistics_providers.dart`) must pass the diver's
current scale, so the chart re-renders when the setting changes.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/statistics/visibility_distribution_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
dart format .
flutter analyze
git add lib/features/statistics/ test/features/statistics/visibility_distribution_test.dart
git commit -m "Bin visibility statistics by the diver's calibration"
```

---

### Task 12: Import and export

**Files:**
- Modify: `lib/core/services/export/uddf/uddf_import_service.dart:729-731,835-843`
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart:1989-1992,2083-2091`
- Modify: `lib/core/services/export/uddf/uddf_export_service.dart:555-568`
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart:1612-1620`
- Modify: `lib/features/universal_import/data/parsers/subsurface_xml_parser.dart:246-248`
- Modify: `lib/features/universal_import/data/parsers/csv_import_parser.dart:211`
- Modify: `lib/core/services/export/csv/csv_export_service.dart:130,169`
- Modify: `lib/core/services/export/excel/excel_export_service.dart:170,214`
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart:1271`
- Test: `test/core/services/export/visibility_roundtrip_test.dart`

**Interfaces:**
- Consumes: `Dive.visibilityMeters` (Task 3), the formatter (Task 6).
- Produces: no new public API.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/services/export/visibility_roundtrip_test.dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UDDF export then import preserves the measured distance', () {
    // Build a Dive with visibilityMeters == 6.4.
    // Export to UDDF, re-import, expect visibilityMeters closeTo(6.4, 0.01).
    // This is the regression test for the pre-v144 bucket round trip, which
    // turned 6.4 into 10.
  });

  test('UDDF import of a measured value no longer buckets it', () {
    // Parse a UDDF fragment with <visibility>7.5</visibility>.
    // Expect visibilityMeters == 7.5 and the legacy bucket unset.
  });

  test('legacy dives still export a representative distance', () {
    // Dive with visibility == Visibility.moderate, visibilityMeters == null.
    // Expect the UDDF value to be the existing representative mapping (10).
  });

  test('Subsurface import carries the number through', () {
    // <dive visibility="12"> -> visibilityMeters == 12.
  });

  test('CSV export emits a numeric column and a rating column', () {
    // Header contains 'Visibility' and 'Visibility Rating'.
    // A 6 m dive under cold-water calibration emits the converted number and
    // 'Good'. A legacy dive emits an empty numeric cell and its band text.
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/export/visibility_roundtrip_test.dart`
Expected: FAIL - imports still bucket the value.

- [ ] **Step 3: Carry the number through the importers**

In both UDDF importers, replace the bucketing call with a numeric parse that
writes `visibilityMeters`. Retain `_parseUddfVisibility` only for files whose
visibility element is non-numeric text, mapping those to the legacy bucket.

In `subsurface_xml_parser.dart`, route the parsed integer to `visibilityMeters`.

In `csv_import_parser.dart`, map a `visibility` header to the numeric field,
stripping a trailing `m` or `ft` suffix and converting feet to meters.

- [ ] **Step 4: Emit the real number on export**

In `_visibilityToUddf` and the equivalent in `uddf_export_builders.dart`, prefer
`dive.visibilityMeters` when present and fall back to the existing bucket
mapping only for legacy dives:

```dart
  /// UDDF carries visibility as a distance in meters. Dives logged from v144
  /// have a real measurement; pre-v144 dives only have a bucket, so they still
  /// export the representative midpoint they always did.
  String _visibilityForUddf(Dive dive) {
    final meters = dive.visibilityMeters;
    if (meters != null) return meters.toStringAsFixed(1);
    return _visibilityToUddf(dive.visibility ?? enums.Visibility.unknown);
  }
```

- [ ] **Step 5: Split the CSV and Excel columns**

Replace the single `Visibility` header with `Visibility` and
`Visibility Rating`. Emit the numeric value in the diver's units and the
adjective (or legacy band text) in the rating column.

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/core/services/export/visibility_roundtrip_test.dart`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
dart format .
flutter analyze
git add lib/ test/core/services/export/visibility_roundtrip_test.dart
git commit -m "Preserve measured visibility through import and export"
```

---

### Task 13: Full verification

- [ ] **Step 1: Regenerate everything from clean**

```bash
flutter clean && flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 2: Format and analyze the whole project**

```bash
dart format .
flutter analyze
```

Expected: no changes from format; zero issues from analyze. Do not pipe
`flutter analyze` through `tail` - it masks the exit status.

- [ ] **Step 3: Run the full suite**

```bash
flutter test
```

Expected: all pass, with no drop from the pre-change baseline.

- [ ] **Step 4: Re-verify the schema version claim**

```bash
git fetch origin main
git show origin/main:lib/core/database/database.dart | grep -n "currentSchemaVersion = "
```

If `origin/main` has moved past 142, renumber this work above whatever the
highest claimed version now is, updating the column comments, the ladder gate,
and the migration test together.

- [ ] **Step 5: Commit any fixes**

```bash
git add -A
git commit -m "Fix formatting and analysis issues from the visibility scale work"
```

## Self-Review Notes

Spec coverage check against
`docs/superpowers/specs/2026-08-07-visibility-scale-calibration-design.md`:

| Spec section | Task |
| -------------- | ------ |
| Data model, migration mechanics, version selection | 2 |
| Precedence and clearing | 3 |
| Calibration value object and presets | 1 |
| Default preset is tropical | 1, 7 |
| Display, legacy band rendering | 4, 6, 9 |
| l10n fix for the dead ARB keys | 5, 6 |
| Statistics | 11 |
| Import and export | 12 |
| Settings UI | 10 |
| Testing | every task, plus 13 |

Known gaps deliberately left to the implementer, because the exact harness
differs per test directory: the arrange/act/assert bodies in Tasks 3, 7, 8, 9,
10, 11, and 12 are specified by behaviour and must be filled using the
neighbouring tests' existing setup. Every assertion is stated; only the fixture
wiring is delegated.

## Deviations found during implementation

Recorded here so the plan matches what was built.

1. **Migration mechanics.** The plan's first draft assumed `m.addColumn()`.
   The codebase actually uses idempotent `_assert<Thing>Column()` helpers called
   from both the version gate and the `beforeOpen` backstop, because parallel
   branches reserve version numbers. Corrected before Task 2 was written.
   `AppDatabase.migrationVersions` also had to gain 144, which the plan missed.

2. **`Visibility.displayName` is retained.** `environment_enum_display.dart:6-10`
   documents that enum `displayName` stays English for data interchange. The
   band renderer was added alongside it rather than replacing it.

3. **Bulk edit was converted too** (Task 8). Not in the plan. Leaving it would
   have kept the tropical-only bucket list in a live surface and let bulk edits
   write the legacy column onto new dives.

4. **Two extra read consumers** (Task 9): `dive_merge_builder.dart` would have
   dropped the measurement during multi-computer consolidation, and the three
   PDF logbook templates would have printed nothing for measured dives.

5. **Subsurface and CSV import were NOT converted** (Task 12). The plan assumed
   Subsurface's `visibility` attribute was a distance. It is a subjective 1-5
   star rating (`subsurface_xml_parser.dart:973`), so mapping it to meters
   would fabricate a measurement. CSV headers are ambiguous for the same reason.

6. **Four mock `SettingsNotifier` subclasses** needed the new method stubbed;
   they implement the notifier interface, so any added method breaks them.

7. **`Dive.copyWith` cannot clear a nullable field** (project-wide `?? this.x`
   idiom), so the clearing test constructs the dive instead. The edit form saves
   the same way, so this matches real usage rather than working around it.
