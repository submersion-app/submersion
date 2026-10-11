# Visibility Range Input Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver log visibility as a band pick (Poor / Moderate / Good / Excellent) saved as a metre range, alongside the existing precise number (issue #3226).

**Architecture:** Two new nullable columns, `dives.visibility_min_meters` (inclusive) and `dives.visibility_max_meters` (exclusive), hold a range; `visibility_meters` stays the precise value; a dive carries at most one shape (precise, range, legacy bucket). `VisibilityScale` converts a band to a range and a range back to a band. Every reader prefers precise, then range, then legacy, so no reader ever treats a range as a measurement.

**Tech Stack:** Flutter, Riverpod, Drift (SQLite), flutter_test, ARB l10n (11 locales), SharedPreferences.

**Spec:** `docs/design/specs/2026-10-10-visibility-range-input-design.md`

## Global Constraints

- Schema version 278 (main is at 276; no open PR or local worktree claims 278). `minimumCompatibleSchemaVersion` stays 275.
- Range ends are metres: `minM` inclusive, `maxM` exclusive, either may be null, never both.
- One visibility shape per dive. Precedence everywhere: precise, then range, then legacy bucket.
- A band pick is converted with the diver's scale at save time; stored metres never move when the scale changes.
- An adjective shows for a range only when the whole range sits inside one band of the current scale.
- No em dashes anywhere (code, comments, ARB text, commits). No mention of any AI tool.
- Every new l10n key goes into all 11 ARBs (`lib/l10n/arb/app_{en,ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`), then `flutter gen-l10n`, and the regenerated `app_localizations*.dart` files are committed.
- Imports grouped dart, flutter, packages, local. `dart format .` before every commit.
- Commit scope is the main feature directory in kebab case (`dive-log`, `insights`, `core`).

## Review Focus

1. **A dive carrying both a precise value and a range.** An older (pre-v278) device's sync overlay keeps the local range while writing a precise value. Every reader must treat that dive as precise: formatter, Insights (counted once, as precise), filter (matches by precise only). Pinned in Tasks 4, 5 and 6.
2. **Scale changed after saving a range.** A Cold water "Good" (6-12 m) dive opened under Tropical shows no selected chip and the caption "6-12 m"; saving without touching visibility keeps 6-12 m. Pinned in Task 8.
3. **Re-saving an untouched dive never rewrites visibility.** A precise 6.44 m dive saved after editing only its notes keeps 6.44 (today the form re-parses a rounded "6" and saves 6.0); a legacy dive keeps its bucket. Pinned in Task 8.
4. **Open-ended ranges against filter bounds.** `visibility <= 20` must not match an Excellent "12 m+" dive; `visibility >= 5` must not match a Poor "under 2 m" dive. Pinned in Task 6.
5. **Unreadable range values in imported files.** A hand-edited CSV or UDDF with a negative end, or min >= max, must import as no range rather than a nonsense one. Pinned in Tasks 1, 9 and 10.

---

### Task 1: VisibilityRange value object and scale conversions

**Files:**
- Create: `lib/core/domain/visibility/visibility_range.dart`
- Modify: `lib/core/domain/visibility/visibility_scale.dart`
- Test: `test/core/domain/visibility/visibility_range_test.dart` (create), `test/core/domain/visibility/visibility_scale_test.dart`

**Interfaces:**
- Produces: `class VisibilityRange implements Comparable<VisibilityRange>` with `final double? minM`, `final double? maxM`, `const VisibilityRange({this.minM, this.maxM})`, `static VisibilityRange? fromColumns(double? minM, double? maxM)`, `static VisibilityRange? tryParse(double? minM, double? maxM)`, `copyWith`, `compareTo`, `==`, `hashCode`.
- Produces: `const visibilityRangeSpanningKey = 'range_spanning';` (top level in `visibility_range.dart`).
- Produces on `VisibilityScale`: `VisibilityRange rangeFor(VisibilityBand band)`, `VisibilityBand? bandForRange(VisibilityRange range)`, `VisibilityBand? bandMatching(VisibilityRange range)`.

- [ ] **Step 1: Write the failing tests**

Create `test/core/domain/visibility/visibility_range_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/domain/visibility/visibility_range.dart';

void main() {
  group('VisibilityRange.fromColumns', () {
    test('no ends is no range', () {
      expect(VisibilityRange.fromColumns(null, null), isNull);
    });

    test('either end alone is an open range', () {
      expect(
        VisibilityRange.fromColumns(null, 2),
        const VisibilityRange(maxM: 2),
      );
      expect(
        VisibilityRange.fromColumns(12, null),
        const VisibilityRange(minM: 12),
      );
    });
  });

  group('VisibilityRange.tryParse (imported values)', () {
    test('accepts a closed range and open ends', () {
      expect(
        VisibilityRange.tryParse(6, 12),
        const VisibilityRange(minM: 6, maxM: 12),
      );
      expect(VisibilityRange.tryParse(null, 2), const VisibilityRange(maxM: 2));
      expect(VisibilityRange.tryParse(12, null), const VisibilityRange(minM: 12));
    });

    test('rejects a negative end, an empty or inverted range, and no ends', () {
      expect(VisibilityRange.tryParse(-1, 5), isNull);
      expect(VisibilityRange.tryParse(null, 0), isNull);
      expect(VisibilityRange.tryParse(6, 6), isNull);
      expect(VisibilityRange.tryParse(12, 6), isNull);
      expect(VisibilityRange.tryParse(null, null), isNull);
      expect(VisibilityRange.tryParse(double.nan, 5), isNull);
    });
  });

  test('sorts poorest to clearest: open low first, open high last', () {
    final sorted = [
      const VisibilityRange(minM: 12),
      const VisibilityRange(minM: 6, maxM: 12),
      const VisibilityRange(maxM: 2),
      const VisibilityRange(minM: 6, maxM: 8),
    ]..sort();
    expect(sorted, [
      const VisibilityRange(maxM: 2),
      const VisibilityRange(minM: 6, maxM: 8),
      const VisibilityRange(minM: 6, maxM: 12),
      const VisibilityRange(minM: 12),
    ]);
  });
}
```

Append to `test/core/domain/visibility/visibility_scale_test.dart`, inside `main()` (add `import 'package:submersion/core/domain/visibility/visibility_range.dart';`):

```dart
  group('VisibilityScale.rangeFor (issue #3226)', () {
    test('cold-water bands become their metre ranges', () {
      const scale = VisibilityScale.coldWater;
      expect(
        scale.rangeFor(VisibilityBand.poor),
        const VisibilityRange(maxM: 2),
      );
      expect(
        scale.rangeFor(VisibilityBand.moderate),
        const VisibilityRange(minM: 2, maxM: 6),
      );
      expect(
        scale.rangeFor(VisibilityBand.good),
        const VisibilityRange(minM: 6, maxM: 12),
      );
      expect(
        scale.rangeFor(VisibilityBand.excellent),
        const VisibilityRange(minM: 12),
      );
    });

    test('every band range maps back to its own band on the same scale', () {
      for (final scale in const [
        VisibilityScale.tropical,
        VisibilityScale.temperate,
        VisibilityScale.coldWater,
      ]) {
        for (final band in VisibilityBand.values) {
          expect(scale.bandForRange(scale.rangeFor(band)), band);
          expect(scale.bandMatching(scale.rangeFor(band)), band);
        }
      }
    });
  });

  group('VisibilityScale.bandForRange', () {
    const tropical = VisibilityScale.tropical;

    test('a range inside one band takes that band', () {
      expect(
        tropical.bandForRange(const VisibilityRange(minM: 16, maxM: 25)),
        VisibilityBand.good,
      );
      // Cold water's Good (6-12 m) sits inside tropical Moderate (5-15 m).
      expect(
        tropical.bandForRange(const VisibilityRange(minM: 6, maxM: 12)),
        VisibilityBand.moderate,
      );
      expect(
        tropical.bandForRange(const VisibilityRange(maxM: 3)),
        VisibilityBand.poor,
      );
      expect(
        tropical.bandForRange(const VisibilityRange(minM: 40)),
        VisibilityBand.excellent,
      );
    });

    test('a range crossing a band edge has no band', () {
      expect(
        tropical.bandForRange(const VisibilityRange(minM: 6, maxM: 20)),
        isNull,
      );
      expect(tropical.bandForRange(const VisibilityRange(maxM: 10)), isNull);
      expect(tropical.bandForRange(const VisibilityRange(minM: 20)), isNull);
      expect(
        VisibilityScale.coldWater.bandForRange(
          const VisibilityRange(minM: 1, maxM: 3),
        ),
        isNull,
      );
    });

    test('a high end equal to a threshold stays in the lower band', () {
      expect(
        tropical.bandForRange(const VisibilityRange(minM: 15, maxM: 30)),
        VisibilityBand.good,
      );
      expect(
        tropical.bandForRange(const VisibilityRange(maxM: 5)),
        VisibilityBand.poor,
      );
    });
  });

  group('VisibilityScale.bandMatching', () {
    test('only an exact band range selects a band', () {
      const cold = VisibilityScale.coldWater;
      expect(
        cold.bandMatching(const VisibilityRange(minM: 6, maxM: 12)),
        VisibilityBand.good,
      );
      expect(
        cold.bandMatching(const VisibilityRange(minM: 6, maxM: 11)),
        isNull,
      );
      expect(
        VisibilityScale.tropical.bandMatching(
          cold.rangeFor(VisibilityBand.good),
        ),
        isNull,
      );
    });
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/domain/visibility/`
Expected: FAIL, compile error "Target of URI doesn't exist: visibility_range.dart".

- [ ] **Step 3: Implement**

Create `lib/core/domain/visibility/visibility_range.dart`:

```dart
/// The Insights key for a range that crosses a band edge on the diver's
/// current scale, so it belongs to no single band (issue #3226).
const visibilityRangeSpanningKey = 'range_spanning';

/// A visibility range in meters, logged when a diver picks a band instead of
/// measuring (issue #3226). [minM] is inclusive and [maxM] exclusive, matching
/// how [VisibilityScale.bandFor] draws band edges.
///
/// Either end may be null for an open range ("under 2 m", "12 m+"), never
/// both: a range with no ends says nothing, so callers model that as no range
/// at all ([fromColumns] returns null for it).
class VisibilityRange implements Comparable<VisibilityRange> {
  final double? minM;
  final double? maxM;

  const VisibilityRange({this.minM, this.maxM})
    : assert(minM != null || maxM != null, 'a range needs at least one end');

  /// The range the two `dives` columns hold, or null when both are null.
  static VisibilityRange? fromColumns(double? minM, double? maxM) =>
      minM == null && maxM == null
      ? null
      : VisibilityRange(minM: minM, maxM: maxM);

  /// As [fromColumns], for values read from an imported file: a negative or
  /// non-finite end, or a low end at or above the high end, is unreadable
  /// and yields null rather than a nonsense range.
  static VisibilityRange? tryParse(double? minM, double? maxM) {
    bool bad(double? v) => v != null && (!v.isFinite || v < 0);
    if (bad(minM) || bad(maxM)) return null;
    if (maxM != null && maxM <= 0) return null;
    if (minM != null && maxM != null && minM >= maxM) return null;
    return fromColumns(minM, maxM);
  }

  VisibilityRange copyWith({double? minM, double? maxM}) =>
      VisibilityRange(minM: minM ?? this.minM, maxM: maxM ?? this.maxM);

  /// Orders by low end, then high end. An open low end sorts first and an
  /// open high end last, so a table column reads poorest to clearest.
  @override
  int compareTo(VisibilityRange other) {
    final byMin = (minM ?? double.negativeInfinity).compareTo(
      other.minM ?? double.negativeInfinity,
    );
    if (byMin != 0) return byMin;
    return (maxM ?? double.infinity).compareTo(other.maxM ?? double.infinity);
  }

  @override
  bool operator ==(Object other) =>
      other is VisibilityRange && other.minM == minM && other.maxM == maxM;

  @override
  int get hashCode => Object.hash(minM, maxM);

  @override
  String toString() => 'VisibilityRange($minM m, $maxM m)';
}
```

In `lib/core/domain/visibility/visibility_scale.dart` add `import 'package:submersion/core/domain/visibility/visibility_range.dart';` at the top and these members after `bandFor`:

```dart
  /// The metres [band] covers on this scale (issue #3226). What a band pick
  /// in the edit form saves: Good on cold water is 6-12 m.
  VisibilityRange rangeFor(VisibilityBand band) => switch (band) {
    VisibilityBand.poor => VisibilityRange(maxM: moderateAtOrAboveM),
    VisibilityBand.moderate => VisibilityRange(
      minM: moderateAtOrAboveM,
      maxM: goodAtOrAboveM,
    ),
    VisibilityBand.good => VisibilityRange(
      minM: goodAtOrAboveM,
      maxM: excellentAtOrAboveM,
    ),
    VisibilityBand.excellent => VisibilityRange(minM: excellentAtOrAboveM),
  };

  /// The band that wholly contains [range], or null when it crosses a band
  /// edge. A saved range keeps its metres when the diver changes scale, so
  /// under a different scale it may honestly belong to no single band.
  ///
  /// `VisibilityBandSql` in the Insights repositories is the SQL twin of
  /// this; keep the two in step.
  VisibilityBand? bandForRange(VisibilityRange range) {
    final lo = range.minM ?? double.negativeInfinity;
    final hi = range.maxM ?? double.infinity;
    if (lo >= excellentAtOrAboveM) return VisibilityBand.excellent;
    if (lo >= goodAtOrAboveM && hi <= excellentAtOrAboveM) {
      return VisibilityBand.good;
    }
    if (lo >= moderateAtOrAboveM && hi <= goodAtOrAboveM) {
      return VisibilityBand.moderate;
    }
    if (hi <= moderateAtOrAboveM) return VisibilityBand.poor;
    return null;
  }

  /// The band whose [rangeFor] is exactly [range], or null. Decides which
  /// chip the edit form shows selected for a stored range.
  VisibilityBand? bandMatching(VisibilityRange range) =>
      VisibilityBand.values.where((b) => rangeFor(b) == range).firstOrNull;
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/domain/visibility/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/domain/visibility test/core/domain/visibility
git add lib/core/domain/visibility/visibility_range.dart lib/core/domain/visibility/visibility_scale.dart test/core/domain/visibility/visibility_range_test.dart test/core/domain/visibility/visibility_scale_test.dart
git commit -m "feat(core): convert visibility bands to metre ranges and back"
```

---

### Task 2: Schema v278 range columns

**Files:**
- Modify: `lib/core/database/tables/dive_tables.dart:45-50`, `lib/core/database/database.dart:256` and the end of `migrationVersions` (about :1179-1181), `lib/core/database/migrations/helpers/dive_migrations.dart` (after `_assertVisibilityMetersColumn`, about :505), `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (after the v276 rung, about :308), `lib/core/database/migrations/before_open.dart` (after the v276 backstop, about :63)
- Test: `test/core/database/migration_v278_visibility_range_test.dart` (create)

**Interfaces:**
- Produces: Drift getters `visibilityMinMeters`, `visibilityMaxMeters` on `$DivesTable`; `Dive` data class (generated) fields of the same names; `DivesCompanion` fields of the same names.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v278: dives.visibility_min_meters / visibility_max_meters (issue
/// #3226).
void main() {
  Future<Set<String>> diveColumns(AppDatabase db) async {
    final cols = await db.customSelect("PRAGMA table_info('dives')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  test('v278 is at or below the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(278));
    expect(AppDatabase.migrationVersions, contains(278));
    expect(
      AppDatabase.migrationStepCount(276),
      AppDatabase.migrationStepCount(278) + 1,
    );
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(278));
  });

  test('a fresh database has both range columns', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(
      await diveColumns(db),
      containsAll(['visibility_min_meters', 'visibility_max_meters']),
    );
  });

  test('upgrading from v276 adds both columns and keeps visibility', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('PRAGMA user_version = 276');
          raw.execute(
            'CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY, '
            'dive_date_time INTEGER, visibility TEXT, visibility_meters REAL)',
          );
          raw.execute(
            "INSERT INTO dives (id, dive_date_time, visibility_meters) "
            "VALUES ('d1', 0, 6.5)",
          );
        },
      ),
    );
    addTearDown(db.close);

    expect(
      await diveColumns(db),
      containsAll(['visibility_min_meters', 'visibility_max_meters']),
    );
    final row = await db
        .customSelect(
          'SELECT visibility_meters AS m, visibility_min_meters AS lo, '
          'visibility_max_meters AS hi FROM dives',
        )
        .getSingle();
    expect(row.read<double>('m'), 6.5);
    expect(row.read<double?>('lo'), isNull);
    expect(row.read<double?>('hi'), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/database/migration_v278_visibility_range_test.dart`
Expected: FAIL (`currentSchemaVersion` is 276; columns missing).

- [ ] **Step 3: Implement**

`dive_tables.dart`, after the `visibilityMeters` getter:

```dart
  /// v278: low end of a visibility range in meters, inclusive (issue #3226).
  /// Set when the diver picked a band instead of measuring. Null with
  /// [visibilityMaxMeters] set means "under that". Never set together with
  /// [visibilityMeters]: the repository writes one shape or the other.
  RealColumn get visibilityMinMeters => real().nullable()();

  /// v278: high end of a visibility range in meters, exclusive. Null with
  /// [visibilityMinMeters] set means "that or more".
  RealColumn get visibilityMaxMeters => real().nullable()();
```

`database.dart`: `static const int currentSchemaVersion = 278;` and append to `migrationVersions` after `276,`:

```dart
    // v278: dives.visibility_min_meters / visibility_max_meters (issue #3226).
    278,
```

`dive_migrations.dart`, after `_assertVisibilityMetersColumn`:

```dart
  /// v278: the visibility range columns (issue #3226). Idempotent, so the
  /// ladder rung and the beforeOpen backstop can both call it.
  Future<void> _assertVisibilityRangeColumns() async {
    await _addColumnIfMissing('dives', 'visibility_min_meters', 'REAL');
    await _addColumnIfMissing('dives', 'visibility_max_meters', 'REAL');
  }
```

`rungs_v231_onward.dart`, after the v276 rung:

```dart
      // v278: dives.visibility_min_meters / visibility_max_meters (issue
      // #3226). Columns only; re-asserted in beforeOpen.
      if (from < 278) {
        await _assertVisibilityRangeColumns();
      }
      if (from < 278) await reportProgress();
```

`before_open.dart`, after the v276 backstop line:

```dart
    // v278 backstop: the dives visibility range columns.
    await _assertVisibilityRangeColumns();
```

Then regenerate: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/database/migration_v278_visibility_range_test.dart test/core/database/database_table_libraries_test.dart`
Expected: PASS (the second keeps every migration file under 800 lines).

- [ ] **Step 5: Commit**

```bash
dart format lib/core/database test/core/database/migration_v278_visibility_range_test.dart
git add lib/core/database test/core/database/migration_v278_visibility_range_test.dart
git commit -m "feat(core): add the dives visibility range columns (schema v278)"
```

---

### Task 3: Dive entity, repository write rule, and the field lists

**Files:**
- Modify: `lib/features/dive_log/domain/entities/dive.dart` (field docs :69-73, constructor :241, copyWith :653/:753, props :855)
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (createDive companion :1699-1706, updateDive companion :2025-2032, mappers :3982 and :4427)
- Modify: `lib/features/dive_log/domain/services/dive_merge_builder.dart:354-355`
- Modify: `lib/features/dive_log/domain/services/dive_mirror_fields.dart:18,123`
- Modify: `lib/features/dive_computer/domain/services/planned_dive_fill_fields.dart:53-54`
- Modify: `lib/features/settings/presentation/conflicts/catalogue/dive_log_fields.dart:631-639`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (seed :958, `Dive(` literal :5912-5915) for a minimal carry
- Modify: `test/core/services/sync/cross_version_roundtrip_test.dart:74`
- Test: `test/features/dive_log/data/repositories/dive_repository_visibility_range_test.dart` (create), `test/features/dive_log/domain/services/dive_merge_builder_test.dart`

**Interfaces:**
- Consumes: `VisibilityRange` (Task 1); Drift columns (Task 2).
- Produces: `Dive.visibilityMinMeters`, `Dive.visibilityMaxMeters` (`double?`), `VisibilityRange? get visibilityRange` on `Dive`, `copyWith(visibilityMinMeters:, visibilityMaxMeters:)`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_log/data/repositories/dive_repository_visibility_range_test.dart`:

```dart
import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/domain/visibility/visibility_range.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// One visibility shape per dive (issue #3226).
void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  domain.Dive makeDive({
    double? meters,
    double? min,
    double? max,
    Visibility? legacy,
  }) => domain.Dive(
    id: '',
    dateTime: DateTime.utc(2026, 7, 1, 10),
    visibilityMeters: meters,
    visibilityMinMeters: min,
    visibilityMaxMeters: max,
    visibility: legacy,
  );

  Future<Map<String, Object?>> raw(String id) async {
    final row = await db
        .customSelect(
          'SELECT visibility, visibility_meters, visibility_min_meters, '
          'visibility_max_meters FROM dives WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingle();
    return row.data;
  }

  test('a range round-trips, open ends included', () async {
    final closed = await repository.createDive(makeDive(min: 6, max: 12));
    final open = await repository.createDive(makeDive(min: 12));

    expect(
      (await repository.getDiveById(closed.id))!.visibilityRange,
      const VisibilityRange(minM: 6, maxM: 12),
    );
    expect(
      (await repository.getDiveById(open.id))!.visibilityRange,
      const VisibilityRange(minM: 12),
    );
  });

  test('writing a range clears the legacy bucket', () async {
    final created = await repository.createDive(
      makeDive(legacy: Visibility.moderate),
    );
    await repository.updateDive(
      created.copyWith(visibilityMinMeters: 6, visibilityMaxMeters: 12),
    );

    final row = await raw(created.id);
    expect(row['visibility'], isNull);
    expect(row['visibility_min_meters'], 6.0);
    expect(row['visibility_max_meters'], 12.0);
  });

  test('a measured distance wins over a range on the same entity', () async {
    final created = await repository.createDive(
      makeDive(meters: 8, min: 6, max: 12),
    );

    final row = await raw(created.id);
    expect(row['visibility_meters'], 8.0);
    expect(row['visibility_min_meters'], isNull);
    expect(row['visibility_max_meters'], isNull);
  });

  test('writing a measured distance clears a stored range', () async {
    final created = await repository.createDive(makeDive(min: 6, max: 12));
    await repository.updateDive(created.copyWith(visibilityMeters: 9));

    final row = await raw(created.id);
    expect(row['visibility_meters'], 9.0);
    expect(row['visibility_min_meters'], isNull);
    expect(row['visibility_max_meters'], isNull);
  });
}
```

Append to `test/features/dive_log/domain/services/dive_merge_builder_test.dart` inside `main()`:

```dart
  group('build - visibility (issue #3226)', () {
    Dive at(String id, int hour) => dive(
      id,
      entry: DateTime.utc(2026, 7, 1, hour),
      runtimeMin: 20,
    );

    test('a measured distance from any source wins over an earlier range', () {
      final a = at('a', 9).copyWith(
        visibilityMinMeters: 6,
        visibilityMaxMeters: 12,
      );
      final b = at('b', 10).copyWith(visibilityMeters: 8);
      final merged = builder.build([a, b]).mergedDive;
      expect(merged.visibilityMeters, 8);
      expect(merged.visibilityRange, isNull);
    });

    test('a range wins over a legacy bucket', () {
      final a = at('a', 9).copyWith(visibility: Visibility.good);
      final b = at('b', 10).copyWith(
        visibilityMinMeters: 6,
        visibilityMaxMeters: 12,
      );
      final merged = builder.build([a, b]).mergedDive;
      expect(merged.visibilityRange, const VisibilityRange(minM: 6, maxM: 12));
      expect(merged.visibility, isNull);
    });

    test('the range comes whole from one source', () {
      final a = at('a', 9).copyWith(visibilityMaxMeters: 2);
      final b = at('b', 10).copyWith(
        visibilityMinMeters: 6,
        visibilityMaxMeters: 12,
      );
      final merged = builder.build([a, b]).mergedDive;
      expect(merged.visibilityRange, const VisibilityRange(maxM: 2));
    });
  });
```

(add `import 'package:submersion/core/domain/visibility/visibility_range.dart';`).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_visibility_range_test.dart test/features/dive_log/domain/services/dive_merge_builder_test.dart`
Expected: FAIL (no `visibilityMinMeters` parameter on `Dive`).

- [ ] **Step 3: Implement**

`dive.dart`: import `visibility_range.dart`; after the `visibilityMeters` field:

```dart
  /// Low end of a visibility range in meters, inclusive (v278, issue #3226).
  /// Set when the diver picked a band rather than measuring. Never set
  /// together with [visibilityMeters].
  final double? visibilityMinMeters;

  /// High end of a visibility range in meters, exclusive.
  final double? visibilityMaxMeters;
```

Constructor: `this.visibilityMinMeters, this.visibilityMaxMeters,` after `this.visibilityMeters,`. `copyWith`: parameters `double? visibilityMinMeters, double? visibilityMaxMeters,` and body `visibilityMinMeters: visibilityMinMeters ?? this.visibilityMinMeters, visibilityMaxMeters: visibilityMaxMeters ?? this.visibilityMaxMeters,`. `props`: add both after `visibilityMeters,`. Getter near the other derived getters:

```dart
  /// The stored visibility range, or null when the dive has none.
  VisibilityRange? get visibilityRange =>
      VisibilityRange.fromColumns(visibilityMinMeters, visibilityMaxMeters);
```

Repository, both companions (createDive and updateDive), replacing the `visibilityMeters:` / `visibility:` pair:

```dart
                  visibilityMeters: Value(dive.visibilityMeters),
                  // One visibility shape per dive (issue #3226): a measured
                  // distance wins over a range, and either supersedes the
                  // legacy bucket. Value(null) rather than Value.absent():
                  // absent() preserves the existing column on a companion
                  // write, which would leave the dive carrying two shapes.
                  visibilityMinMeters: Value(
                    dive.visibilityMeters == null
                        ? dive.visibilityMinMeters
                        : null,
                  ),
                  visibilityMaxMeters: Value(
                    dive.visibilityMeters == null
                        ? dive.visibilityMaxMeters
                        : null,
                  ),
                  visibility:
                      dive.visibilityMeters != null ||
                          dive.visibilityRange != null
                      ? const Value(null)
                      : Value(dive.visibility?.name),
```

Both mappers, after `visibilityMeters: row.visibilityMeters,`:

```dart
      visibilityMinMeters: row.visibilityMinMeters,
      visibilityMaxMeters: row.visibilityMaxMeters,
```

Merge builder, replacing the two `_firstNonNull` visibility lines. Before the `Dive(` literal that holds them:

```dart
    // Visibility comes whole from one source, by the same precedence every
    // reader uses (issue #3226): picking each column independently could
    // pair one source's measurement with another's range.
    final visibilitySource =
        sorted.where((d) => d.visibilityMeters != null).firstOrNull ??
        sorted.where((d) => d.visibilityRange != null).firstOrNull ??
        sorted.where((d) => d.visibility != null).firstOrNull;
```

and in the literal:

```dart
      visibility: visibilitySource?.visibility,
      visibilityMeters: visibilitySource?.visibilityMeters,
      visibilityMinMeters: visibilitySource?.visibilityMinMeters,
      visibilityMaxMeters: visibilitySource?.visibilityMaxMeters,
```

`dive_mirror_fields.dart`: add `'visibilityMinMeters', 'visibilityMaxMeters',` to the conditions line of `kMirroredDiveFields`, and in `mirroredDiveFrom` after `visibilityMeters: source.visibilityMeters,`:

```dart
    visibilityMinMeters: source.visibilityMinMeters,
    visibilityMaxMeters: source.visibilityMaxMeters,
```

`planned_dive_fill_fields.dart`: add `'visibilityMinMeters', 'visibilityMaxMeters',` to `kHumanDiveFields` after `'visibilityMeters'`.

`dive_log_fields.dart`, alphabetically between `'visibility'` and `'visibilityMeters'`:

```dart
  'visibilityMaxMeters': ConflictField(
    (l) => DiveField.visibility.localizedDisplayName(l),
    FieldKind.distance,
  ),
  'visibilityMinMeters': ConflictField(
    (l) => DiveField.visibility.localizedDisplayName(l),
    FieldKind.distance,
  ),
```

`cross_version_roundtrip_test.dart:74`: `const postV137DiveKeys = ['visibilityMeters', 'visibilityMinMeters', 'visibilityMaxMeters'];` and extend the doc sentence: "v278 added dives.visibility_min_meters and visibility_max_meters."

`dive_edit_page.dart`, a minimal carry so a range synced from another device is not wiped by a save before Task 8 lands. Next to `_selectedVisibility` (:311):

```dart
  /// A stored visibility range (issue #3226), carried through a save
  /// untouched. Replaced by the full range input in a later change.
  VisibilityRange? _storedVisibilityRange;
```

Seed, after `_selectedVisibility = ...` (:958): `_storedVisibilityRange = dive.visibilityRange;`. In the `Dive(` literal after `visibilityMeters: _visibilityMetersInput(units),`:

```dart
        visibilityMinMeters: _storedVisibilityRange?.minM,
        visibilityMaxMeters: _storedVisibilityRange?.maxM,
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/data/repositories/ test/features/dive_log/domain/services/ test/features/dive_computer/domain/services/planned_dive_fill_fields_test.dart test/features/settings/presentation/conflicts/ test/core/services/sync/cross_version_roundtrip_test.dart test/features/dive_log/presentation/pages/dive_edit_save_field_census_test.dart`
Expected: PASS (mirror, planned-fill, conflict-coverage and save-census tests included).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/dive_log/domain lib/features/dive_log/data/repositories/dive_repository_impl.dart lib/features/dive_computer/domain/services/planned_dive_fill_fields.dart lib/features/settings/presentation/conflicts/catalogue/dive_log_fields.dart lib/features/dive_log/presentation/pages/dive_edit_page.dart test/features/dive_log/data/repositories/dive_repository_visibility_range_test.dart test/features/dive_log/domain/services/dive_merge_builder_test.dart test/core/services/sync/cross_version_roundtrip_test.dart
git commit -m "feat(dive-log): store a visibility range on the dive, one shape per dive"
```

---

### Task 4: Rendering a range (detail card, PDFs, table column)

**Files:**
- Modify: `lib/features/dive_log/presentation/formatters/visibility_display.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:3248`
- Modify: `lib/core/services/pdf_templates/pdf_template_padi.dart:379-385`, `pdf_template_naui.dart:413-421`, `pdf_template_detailed.dart:486-492`
- Modify: `lib/core/constants/dive_field_extractor.dart:52-56`, `lib/core/constants/dive_field_formatter.dart:17-21`
- Test: `test/features/dive_log/presentation/formatters/visibility_display_test.dart`, `test/features/dive_log/presentation/pages/dive_detail_visibility_row_test.dart`, `test/core/constants/dive_field_visibility_test.dart`, `test/core/services/pdf_templates/pdf_visibility_test.dart`

**Interfaces:**
- Consumes: `VisibilityRange`, `VisibilityScale.bandForRange` (Task 1); `Dive.visibilityRange` (Task 3).
- Produces: `String formatVisibilityRange(VisibilityRange range, AppLocalizations l10n, UnitFormatter units)`; `String formatRangeVisibility(VisibilityRange range, VisibilityScale scale, AppLocalizations l10n, UnitFormatter units)`; `formatDiveVisibility({required double? meters, required VisibilityRange? range, required Visibility? legacy, required VisibilityScale scale, required AppLocalizations l10n, required UnitFormatter units})`; `String? formatDiveVisibilityPlain({required double? meters, required VisibilityRange? range, required Visibility? legacy, required AppLocalizations l10n, required UnitFormatter units})`.

- [ ] **Step 1: Write the failing tests**

In `visibility_display_test.dart` add a group (reuse the file's existing `l10n`, `metric`/`imperial` `UnitFormatter` setup; read the top of the file for their names and match them):

```dart
  group('formatVisibilityRange (issue #3226)', () {
    test('a closed range reads low-high in the depth unit', () {
      expect(
        formatVisibilityRange(
          const VisibilityRange(minM: 6, maxM: 12),
          l10n,
          metricUnits,
        ),
        '6-12 m',
      );
    });

    test('open ends read under / plus', () {
      expect(
        formatVisibilityRange(const VisibilityRange(maxM: 2), l10n, metricUnits),
        'under 2 m',
      );
      expect(
        formatVisibilityRange(const VisibilityRange(minM: 12), l10n, metricUnits),
        '12 m+',
      );
    });

    test('feet convert each end', () {
      expect(
        formatVisibilityRange(
          const VisibilityRange(minM: 6, maxM: 12),
          l10n,
          imperialUnits,
        ),
        '20-39 ft',
      );
    });
  });

  group('formatRangeVisibility', () {
    test('adds the band when the range sits inside one', () {
      expect(
        formatRangeVisibility(
          const VisibilityRange(minM: 6, maxM: 12),
          VisibilityScale.coldWater,
          l10n,
          metricUnits,
        ),
        '6-12 m · Good',
      );
    });

    test('omits the adjective when the range spans bands', () {
      expect(
        formatRangeVisibility(
          const VisibilityRange(minM: 6, maxM: 20),
          VisibilityScale.tropical,
          l10n,
          metricUnits,
        ),
        '6-20 m',
      );
    });
  });

  group('formatDiveVisibility precedence with a range', () {
    test('a range shows when there is no measurement', () {
      expect(
        formatDiveVisibility(
          meters: null,
          range: const VisibilityRange(minM: 12),
          legacy: null,
          scale: VisibilityScale.coldWater,
          l10n: l10n,
          units: metricUnits,
        ),
        '12 m+ · Excellent',
      );
    });

    test('a measurement wins over a range carried alongside it', () {
      expect(
        formatDiveVisibility(
          meters: 8,
          range: const VisibilityRange(minM: 6, maxM: 12),
          legacy: null,
          scale: VisibilityScale.coldWater,
          l10n: l10n,
          units: metricUnits,
        ),
        formatMeasuredVisibility(8, VisibilityScale.coldWater, l10n, metricUnits),
      );
    });
  });
```

Every existing `formatDiveVisibility(` call in that test file gains `range: null,`.

In `dive_detail_visibility_row_test.dart` add:

```dart
  testWidgets('a range dive shows its range and band', (tester) async {
    final dive = createTestDiveWithBottomTime().copyWith(
      visibilityMinMeters: 15,
      visibilityMaxMeters: 30,
    );
    await pumpWith(tester, dive);
    final l10n = l10nOf(tester);
    // Default (tropical) scale: 15-30 m is exactly Good.
    expect(
      find.descendant(
        of: visibilityRow(l10n),
        matching: find.text('15-30 m · ${l10n.enum_visibilityBand_good}'),
      ),
      findsOneWidget,
    );
  });
```

In `dive_field_visibility_test.dart` add (match the file's existing `units` helper name):

```dart
  test('a range dive extracts its range and formats it compactly', () {
    final dive = Dive(
      id: 'r',
      dateTime: DateTime.utc(2026, 1, 1),
      visibilityMinMeters: 6,
      visibilityMaxMeters: 12,
    );
    final value = DiveFieldExtractor.extract(DiveField.visibility, dive);
    expect(value, const VisibilityRange(minM: 6, maxM: 12));
    expect(DiveFieldFormatter.format(DiveField.visibility, value, units), '6-12m');
    expect(
      DiveFieldFormatter.format(
        DiveField.visibility,
        const VisibilityRange(maxM: 2),
        units,
      ),
      '<2m',
    );
    expect(
      DiveFieldFormatter.format(
        DiveField.visibility,
        const VisibilityRange(minM: 12),
        units,
      ),
      '12m+',
    );
  });
```

(Use the extractor/formatter entry points exactly as that test file already calls them.)

In `pdf_visibility_test.dart` add a case per template that a range dive renders `6-12 m` with no adjective, mirroring the file's existing measured-dive cases.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/formatters/visibility_display_test.dart test/features/dive_log/presentation/pages/dive_detail_visibility_row_test.dart test/core/constants/dive_field_visibility_test.dart test/core/services/pdf_templates/pdf_visibility_test.dart`
Expected: FAIL (`formatVisibilityRange` undefined).

- [ ] **Step 3: Implement**

`visibility_display.dart` (import `visibility_range.dart` and `package:submersion/core/utils/number_display.dart`):

```dart
/// A visibility range as text in the diver's depth unit: "6-12 m",
/// "under 2 m" or "12 m+" (issue #3226). Whole units, like a measured
/// distance; the band is always decided on the unrounded meters.
String formatVisibilityRange(
  VisibilityRange range,
  AppLocalizations l10n,
  UnitFormatter units,
) {
  String value(double meters) =>
      formatFixedForDisplay(units.convertDepth(meters), 0);
  final unit = units.depthSymbol;
  final min = range.minM;
  final max = range.maxM;
  if (min == null) return l10n.visibility_range_under(value(max!), unit);
  if (max == null) return l10n.visibility_range_atLeast(value(min), unit);
  return l10n.visibility_range_between(value(min), value(max), unit);
}

/// A range plus the adjective [scale] gives it when the whole range sits in
/// one band ("6-12 m · Good"), or just the range when it spans bands.
String formatRangeVisibility(
  VisibilityRange range,
  VisibilityScale scale,
  AppLocalizations l10n,
  UnitFormatter units,
) {
  final text = formatVisibilityRange(range, l10n, units);
  final band = scale.bandForRange(range);
  return band == null ? text : '$text · ${visibilityBandName(band, l10n)}';
}
```

`formatDiveVisibility` gains `required VisibilityRange? range,` and after the measured branch: `if (range != null) return formatRangeVisibility(range, scale, l10n, units);`. Update its doc to "precise, then range, then legacy bucket".

```dart
/// A dive's visibility without an adjective, for the surfaces that never
/// show one (the PDF logbook pages). Same precedence as
/// [formatDiveVisibility].
String? formatDiveVisibilityPlain({
  required double? meters,
  required VisibilityRange? range,
  required Visibility? legacy,
  required AppLocalizations l10n,
  required UnitFormatter units,
}) {
  if (meters != null) return units.formatDistance(meters);
  if (range != null) return formatVisibilityRange(range, l10n, units);
  if (legacy != null) return visibilityName(legacy, l10n);
  return null;
}
```

Detail page: add `range: dive.visibilityRange,` to the `formatDiveVisibility` call.

PDFs: padi and naui become `_buildPadiField(l10n.pdf_visibilityShort, formatDiveVisibilityPlain(meters: dive.visibilityMeters, range: dive.visibilityRange, legacy: dive.visibility, l10n: l10n, units: units) ?? '-')` (and the naui equivalent). Detailed replaces its two `if`/`else if` entries with:

```dart
        if (formatDiveVisibilityPlain(
              meters: dive.visibilityMeters,
              range: dive.visibilityRange,
              legacy: dive.visibility,
              l10n: l10n,
              units: units,
            )
            case final visibility?)
          _Field(l10n.pdf_visibility, visibility),
```

`dive_field_extractor.dart`: `return dive.visibilityMeters ?? dive.visibilityRange ?? dive.visibility?.displayName;` and extend its comment: "A range dive (issue #3226) yields its VisibilityRange, which sorts after measured values and before legacy text."

`dive_field_formatter.dart` (import `visibility_range.dart` and `number_display.dart`):

```dart
      case DiveField.visibility:
        if (value is double) return units.formatDistance(value);
        if (value is VisibilityRange) return _compactRange(value, units);
        return value.toString();
```

and at file bottom:

```dart
/// A visibility range for a narrow table cell, unit attached like
/// [UnitFormatter.formatDistance]: "6-12m", "<2m", "12m+". Symbols rather
/// than words, so the cell needs no l10n.
String _compactRange(VisibilityRange range, UnitFormatter units) {
  String n(double meters) =>
      formatFixedForDisplay(units.convertDepth(meters), 0);
  final unit = units.depthSymbol;
  final min = range.minM;
  final max = range.maxM;
  if (min == null) return '<${n(max!)}$unit';
  if (max == null) return '${n(min)}$unit+';
  return '${n(min)}-${n(max)}$unit';
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the Step 2 command plus `flutter test test/features/dive_log/presentation/widgets/dive_table_view_sort_test.dart test/core/utils/table_value_compare_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/dive_log/presentation/formatters/visibility_display.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart lib/core/services/pdf_templates lib/core/constants/dive_field_extractor.dart lib/core/constants/dive_field_formatter.dart test/features/dive_log/presentation/formatters/visibility_display_test.dart test/features/dive_log/presentation/pages/dive_detail_visibility_row_test.dart test/core/constants/dive_field_visibility_test.dart test/core/services/pdf_templates/pdf_visibility_test.dart
git commit -m "feat(dive-log): show a dive's visibility range wherever visibility renders"
```

---

### Task 5: Insights distribution and Focus factor

**Files:**
- Create: `lib/features/insights/data/repositories/visibility_band_sql.dart`
- Modify: `lib/features/insights/data/repositories/insights_repository.dart:1175-1250`, `lib/features/insights/data/repositories/insights_repository_focus.dart:11-50`
- Modify: `lib/features/insights/domain/focus/focus_factor_row.dart:44-46` (doc only)
- Modify: `lib/features/dive_log/presentation/formatters/visibility_display.dart` (`visibilityDistributionLabel`)
- Modify: `lib/features/insights/presentation/pages/insights_conditions_page.dart:105-112` (fifth colour)
- Modify: all 11 ARBs (new key `insights_conditions_visibility_spansBands`), regenerate l10n
- Test: `test/features/insights/visibility_distribution_test.dart`, `test/features/insights/data/repositories/focus_factor_rows_test.dart`, `test/features/dive_log/presentation/formatters/visibility_display_test.dart`

**Interfaces:**
- Consumes: `visibilityRangeSpanningKey` (Task 1).
- Produces: `abstract final class VisibilityBandSql { static String whenBranches(String prefix); static List<double> params(VisibilityScale scale); }`.

- [ ] **Step 1: Write the failing tests**

In `visibility_distribution_test.dart`, widen `seedDive` to take `double? min, double? max` and insert `visibility_min_meters, visibility_max_meters` (add both columns and two `?` to the INSERT, values `min, max`). Add:

```dart
  test('a range inside one band counts in that band (issue #3226)', () async {
    await seedDive(min: 6, max: 12);
    await seedDive(meters: 7);

    final segments = await repository.getVisibilityDistribution(
      scale: VisibilityScale.coldWater,
    );

    expect(countsByLabel(segments), {'good': 2});
  });

  test('a range crossing a band edge gets its own segment', () async {
    await seedDive(min: 6, max: 20);
    await seedDive(max: 2);

    final segments = await repository.getVisibilityDistribution(
      scale: VisibilityScale.tropical,
    );

    expect(countsByLabel(segments), {'poor': 1, 'range_spanning': 1});
    // Bands first, then the spanning segment.
    expect(segments.map((s) => s.label), ['poor', 'range_spanning']);
  });

  test('a dive carrying a measurement and a range counts once, as measured',
      () async {
    await seedDive(meters: 31, min: 2, max: 6);

    final segments = await repository.getVisibilityDistribution(
      scale: VisibilityScale.tropical,
    );

    expect(countsByLabel(segments), {'excellent': 1});
  });
```

In `focus_factor_rows_test.dart`, widen the `dive()` helper with `double? visibilityMinMeters, double? visibilityMaxMeters` written as `Value(...)` into the companion beside `visibilityMeters`, and add:

```dart
  test('a range dive gets its band, or range_spanning (issue #3226)',
      () async {
    await dive('fits', visibilityMinMeters: 6, visibilityMaxMeters: 12);
    await dive('spans', day: 2, visibilityMinMeters: 1, visibilityMaxMeters: 8);
    final byId = {
      for (final r in await repository.getFocusFactorRows(
        visibilityScale: VisibilityScale.coldWater,
      ))
        r.diveId: r,
    };
    expect(byId['fits']!.visibilityKey, 'good');
    expect(byId['spans']!.visibilityKey, 'range_spanning');
  });
```

(Match the existing test's `getFocusFactorRows` arguments and row id field name.)

In `visibility_display_test.dart`, in the `visibilityDistributionLabel` group:

```dart
    test('the spanning key reads Spans bands', () {
      expect(
        visibilityDistributionLabel('range_spanning', l10n, metricUnits),
        l10n.insights_conditions_visibility_spansBands,
      );
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/insights/visibility_distribution_test.dart test/features/insights/data/repositories/focus_factor_rows_test.dart`
Expected: FAIL (range dives excluded or keyed `legacy_`).

- [ ] **Step 3: Implement**

Create `lib/features/insights/data/repositories/visibility_band_sql.dart`:

```dart
import 'package:submersion/core/domain/visibility/visibility_range.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';

/// The CASE branches that turn a dive row's visibility into a distribution
/// key, shared by the visibility distribution and the Focus factor rows so
/// the two can never disagree (issue #3226).
///
/// Keys: a [VisibilityBand] name for a measured distance, and for a range
/// that sits wholly inside one band; [visibilityRangeSpanningKey] for a range
/// that crosses a band edge. A measured distance wins over a range on the
/// same row, as in every other reader. The caller adds the legacy `ELSE`.
///
/// The range branch is the SQL twin of [VisibilityScale.bandForRange]; keep
/// them in step. A NULL end makes its comparison NULL, which reads as false,
/// so an open end never satisfies a bound on that side.
abstract final class VisibilityBandSql {
  /// The WHEN branches over columns prefixed by [prefix] (`''` or `'d.'`).
  static String whenBranches(String prefix) {
    final p = prefix;
    return '''
      WHEN ${p}visibility_meters IS NOT NULL THEN
        CASE
          WHEN ${p}visibility_meters >= ? THEN 'excellent'
          WHEN ${p}visibility_meters >= ? THEN 'good'
          WHEN ${p}visibility_meters >= ? THEN 'moderate'
          ELSE 'poor'
        END
      WHEN ${p}visibility_min_meters IS NOT NULL
        OR ${p}visibility_max_meters IS NOT NULL THEN
        CASE
          WHEN ${p}visibility_min_meters >= ? THEN 'excellent'
          WHEN ${p}visibility_min_meters >= ?
            AND ${p}visibility_max_meters <= ? THEN 'good'
          WHEN ${p}visibility_min_meters >= ?
            AND ${p}visibility_max_meters <= ? THEN 'moderate'
          WHEN ${p}visibility_max_meters <= ? THEN 'poor'
          ELSE '$visibilityRangeSpanningKey'
        END''';
  }

  /// The values [whenBranches] binds, in placeholder order.
  static List<double> params(VisibilityScale s) => [
    s.excellentAtOrAboveM,
    s.goodAtOrAboveM,
    s.moderateAtOrAboveM,
    s.excellentAtOrAboveM,
    s.goodAtOrAboveM,
    s.excellentAtOrAboveM,
    s.moderateAtOrAboveM,
    s.goodAtOrAboveM,
    s.moderateAtOrAboveM,
  ];
}
```

`insights_repository.dart` `getVisibilityDistribution`: `scaleParams = VisibilityBandSql.params(scale)`; the inner SELECT becomes:

```sql
SELECT CASE
  ${VisibilityBandSql.whenBranches('')}
  ELSE 'legacy_' || visibility
END AS bucket
FROM dives
WHERE (
  visibility_meters IS NOT NULL
  OR visibility_min_meters IS NOT NULL
  OR visibility_max_meters IS NOT NULL
  OR (visibility IS NOT NULL AND visibility != '')
) $diverFilter ${df.clause}
```

and `ordered` becomes:

```dart
      final ordered = <String>[
        ...[
          VisibilityBand.excellent,
          VisibilityBand.good,
          VisibilityBand.moderate,
          VisibilityBand.poor,
        ].map((b) => b.name).where(counts.containsKey),
        if (counts.containsKey(visibilityRangeSpanningKey))
          visibilityRangeSpanningKey,
        ...counts.keys.where((k) => k.startsWith('legacy_')).toList()..sort(),
      ];
```

`insights_repository_focus.dart`: params start `...VisibilityBandSql.params(visibilityScale),` then `DiveRole.soloId,`; the CASE becomes `CASE ${VisibilityBandSql.whenBranches('d.')} ELSE 'legacy_' || NULLIF(d.visibility, '') END AS visibility_key,`.

`focus_factor_row.dart` doc for `visibilityKey`: "A `VisibilityBand` name, `range_spanning` for a range crossing a band edge, or `legacy_<Visibility>`, as `getVisibilityDistribution` emits."

`visibilityDistributionLabel`, before the band lookup:

```dart
  if (key == visibilityRangeSpanningKey) {
    return l10n.insights_conditions_visibility_spansBands;
  }
```

`insights_conditions_page.dart`: append `Colors.purple.shade300,` to the colours list, so a fifth segment does not reuse green.

ARBs: insert after the `insights_conditions_visibility_legacySuffix` entry (and after its `@` metadata block in `app_en.arb`):

| Locale | Value |
| --- | --- |
| en | `Spans bands` |
| ar | `يمتد عبر عدة فئات` |
| de | `Über mehrere Stufen` |
| es | `Abarca varias bandas` |
| fr | `Couvre plusieurs niveaux` |
| he | `חוצה כמה דרגות` |
| hu | `Több sávot átfog` |
| it | `Copre più fasce` |
| nl | `Beslaat meerdere klassen` |
| pt | `Abrange várias faixas` |
| zh | `跨多个等级` |

Then `flutter gen-l10n`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/insights/ test/features/dive_log/presentation/formatters/visibility_display_test.dart test/l10n/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/insights lib/features/dive_log/presentation/formatters/visibility_display.dart lib/l10n/arb test/features/insights test/features/dive_log/presentation/formatters/visibility_display_test.dart
git commit -m "feat(insights): bin visibility ranges by band, with a spans-bands segment"
```

---

### Task 6: Filters and the query language

**Files:**
- Modify: `lib/core/query/registry/query_field.dart` (new `rangeSql` field)
- Modify: `lib/core/query/compiler/query_compiler.dart:327-380` (`_fieldPredicate`)
- Modify: `lib/features/dive_log/query/dive_query_entity.dart:48-66` (`_num` gains `rangeSql`) and `:297-303`
- Modify: `lib/features/dive_log/domain/models/dive_filter_state.dart:106-107` (doc only)
- Test: `test/core/query/compiler/query_compiler_scalar_test.dart`, `test/features/dive_log/data/repositories/dive_repository_explore_axes_filter_test.dart`

**Interfaces:**
- Produces: `QueryField.rangeSql` of type `({String low, String high})?`, `_num(..., rangeSql: ...)`.

- [ ] **Step 1: Write the failing tests**

In `query_compiler_scalar_test.dart`, add a field to the fixture the file uses (read `test/core/query/fixtures/fixture_registry.dart`; add a `QueryField(key: 'vis', type: FieldType.number, sql: '{r}.vis', emptySql: '{r}.vis IS NULL', labelKey: 'x', rangeSql: (low: '{r}.vis_lo', high: '{r}.vis_hi'))` to that fixture registry) and test the SQL and params the compiler emits, using the file's existing compile helper:

```dart
  group('a number field with rangeSql (issue #3226)', () {
    test('>= matches the value, or a NULL value whose low end meets it', () {
      final (sql, params) = compileWhere('vis >= 10');
      expect(sql, contains('(r.vis >= ? OR (r.vis IS NULL AND r.vis_lo >= ?))'));
      expect(params, [10, 10]);
    });

    test('< needs the exclusive high end at or below the bound', () {
      final (sql, _) = compileWhere('vis < 10');
      expect(sql, contains('(r.vis < ? OR (r.vis IS NULL AND r.vis_hi <= ?))'));
    });

    test('between needs both ends inside', () {
      final (sql, params) = compileWhere('vis between 5 and 20');
      expect(sql, contains('r.vis_lo >= ?'));
      expect(sql, contains('r.vis_hi <= ?'));
      expect(params, [5, 20, 5, 20]);
    });

    test('equality never matches a range', () {
      final (sql, _) = compileWhere('vis = 10');
      expect(sql, isNot(contains('vis_lo')));
    });
  });
```

(Adapt `compileWhere` and the alias `r.` to the helper and alias that test file already uses; the assertions above state the required shape.)

In `dive_repository_explore_axes_filter_test.dart`, next to `'visibility bounds'`, add a test that inserts range dives through the file's `insertDive` helper (widen it with `visibilityMinMeters`/`visibilityMaxMeters`) and asserts with `expectParity`:

```dart
  test('visibility bounds match a range only when the whole range fits '
      '(issue #3226)', () async {
    await insertDive('poor', visibilityMaxMeters: 2);
    await insertDive('good', visibilityMinMeters: 6, visibilityMaxMeters: 12);
    await insertDive('excellent', visibilityMinMeters: 12);
    await insertDive('both', visibilityMeters: 3, visibilityMinMeters: 12);

    await expectParity(const DiveFilterState(minVisibility: 5), {
      'good',
      'excellent',
    });
    await expectParity(const DiveFilterState(maxVisibility: 20), {
      'poor',
      'good',
      'both',
    });
  });
```

(`both` carries a measurement of 3 m: it matches by the measurement only, so `>= 5` excludes it despite its range.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/query/compiler/query_compiler_scalar_test.dart test/features/dive_log/data/repositories/dive_repository_explore_axes_filter_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`query_field.dart`, new field plus constructor parameter `this.rangeSql,`:

```dart
  /// For a number field whose rows may hold a range instead of a value: the
  /// SQL of the range's inclusive low end and exclusive high end (issue
  /// #3226). An ordering comparison then also matches a row whose value is
  /// NULL and whose whole range satisfies it. Equality never matches a
  /// range. Null for ordinary fields.
  final ({String low, String high})? rangeSql;
```

`query_compiler.dart` `_fieldPredicate`, `between` branch:

```dart
      case QueryOp.between:
        // A reversed pair (from JSON or the builder) still means the range.
        final items = _ascending((value as ListValue).items);
        final exact =
            '(${_cmp(f, col, '>=', items[0])} '
            'AND ${_cmp(f, col, '<=', items[1])})';
        final range = f.rangeSql;
        if (range == null) return exact;
        return '($exact OR (${col()} IS NULL '
            'AND ${_cmp(f, () => _field(range.low, alias), '>=', items[0])} '
            'AND ${_cmp(f, () => _field(range.high, alias), '<=', items[1])}))';
```

ordering branch:

```dart
        final exact = '(${_cmp(f, col, sym, value!)})';
        final range = f.rangeSql;
        if (range == null) return exact;
        // The whole range must satisfy the bound: its low end for a lower
        // bound, its exclusive high end for an upper one (every value below
        // a high end of X is below X, so `< X` needs high <= X). Only a row
        // with no value is read as a range, as every other reader does.
        final (end, endSym) = switch (sym) {
          '>' || '>=' => (range.low, sym),
          _ => (range.high, '<='),
        };
        return '($exact OR (${col()} IS NULL '
            'AND ${_cmp(f, () => _field(end, alias), endSym, value)}))';
```

`dive_query_entity.dart`: `_num` gains `({String low, String high})? rangeSql,` passed as `rangeSql: rangeSql,`. The visibility field:

```dart
    _num(
      'visibility',
      '{r}.visibility_meters',
      dimension: FieldDimension.depth,
      // A band pick stores a range instead (issue #3226).
      rangeSql: (
        low: '{r}.visibility_min_meters',
        high: '{r}.visibility_max_meters',
      ),
      emptySql:
          '({r}.visibility_meters IS NULL '
          'AND {r}.visibility_min_meters IS NULL '
          'AND {r}.visibility_max_meters IS NULL '
          "AND ({r}.visibility IS NULL OR TRIM({r}.visibility) = ''))",
    ),
```

`dive_filter_state.dart` doc: "Visibility bounds in metres against `dives.visibility_meters`, or for a range dive its whole range (issue #3226); the legacy `visibility` bucket column is read-only and ignored."

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/query test/features/query test/features/dive_log/query test/features/dive_log/data/repositories/dive_repository_explore_axes_filter_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/core/query lib/features/dive_log/query/dive_query_entity.dart lib/features/dive_log/domain/models/dive_filter_state.dart test/core/query test/features/dive_log/data/repositories/dive_repository_explore_axes_filter_test.dart
git commit -m "feat(dive-log): visibility filters match a range only when all of it fits"
```

---

### Task 7: Visibility entry logic and the remembered mode

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/visibility_input/visibility_entry.dart`
- Create: `lib/features/dive_log/presentation/providers/visibility_input_mode_provider.dart`
- Test: `test/features/dive_log/presentation/widgets/visibility_input/visibility_entry_test.dart`, `test/features/dive_log/presentation/providers/visibility_input_mode_provider_test.dart`

**Interfaces:**
- Consumes: `VisibilityRange`, `VisibilityScale.rangeFor/bandMatching` (Task 1); `formatVisibilityRange`, `formatLegacyVisibilityBand`, `visibilityBandName` (Task 4 / existing).
- Produces:
  - `enum VisibilityInputMode { range, precise }`
  - `class StoredVisibility { final double? meters; final VisibilityRange? range; final Visibility? legacy; const StoredVisibility({...}); static const none; factory StoredVisibility.of(Dive dive); bool get isEmpty; VisibilityInputMode? get naturalMode; VisibilityInputMode? get modeToRemember; }`
  - `StoredVisibility resolveVisibilityEntry({required VisibilityInputMode mode, required double? preciseMeters, required VisibilityBand? band, required bool touched, required StoredVisibility original, required VisibilityScale scale})`
  - `VisibilityBand? effectiveVisibilityBand({required VisibilityBand? band, required bool touched, required StoredVisibility original, required VisibilityScale scale})`
  - `String? visibilityEntryCaption({required VisibilityInputMode mode, required double? preciseMeters, required VisibilityBand? band, required bool touched, required StoredVisibility original, required VisibilityScale scale, required AppLocalizations l10n, required UnitFormatter units})`
  - `visibilityInputModeProvider` (`StateNotifierProvider<VisibilityInputModeNotifier, VisibilityInputMode>`), `VisibilityInputModeNotifier.remember(VisibilityInputMode)`.

- [ ] **Step 1: Write the failing tests**

`visibility_entry_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/domain/visibility/visibility_range.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/features/dive_log/presentation/widgets/visibility_input/visibility_entry.dart';

void main() {
  const cold = VisibilityScale.coldWater;
  const tropical = VisibilityScale.tropical;
  const coldGood = VisibilityRange(minM: 6, maxM: 12);

  StoredVisibility resolve({
    VisibilityInputMode mode = VisibilityInputMode.range,
    double? precise,
    VisibilityBand? band,
    bool touched = true,
    StoredVisibility original = StoredVisibility.none,
    VisibilityScale scale = cold,
  }) => resolveVisibilityEntry(
    mode: mode,
    preciseMeters: precise,
    band: band,
    touched: touched,
    original: original,
    scale: scale,
  );

  group('resolveVisibilityEntry', () {
    test('a band pick saves its range on the current scale', () {
      expect(
        resolve(band: VisibilityBand.good).range,
        coldGood,
      );
    });

    test('a typed number in Precise saves a measurement', () {
      final saved = resolve(mode: VisibilityInputMode.precise, precise: 7);
      expect(saved.meters, 7);
      expect(saved.range, isNull);
    });

    test('only the active mode is saved', () {
      final saved = resolve(
        mode: VisibilityInputMode.range,
        precise: 7,
        band: VisibilityBand.good,
      );
      expect(saved.meters, isNull);
      expect(saved.range, coldGood);
    });

    test('an untouched dive keeps exactly what it had', () {
      for (final original in const [
        StoredVisibility(meters: 6.44),
        StoredVisibility(range: coldGood),
        StoredVisibility(legacy: Visibility.moderate),
      ]) {
        expect(
          resolve(
            mode: VisibilityInputMode.precise,
            precise: 6,
            touched: false,
            original: original,
            scale: tropical,
          ),
          original,
        );
      }
    });

    test('clearing the input after touching it saves nothing', () {
      expect(
        resolve(original: const StoredVisibility(range: coldGood)),
        StoredVisibility.none,
      );
    });
  });

  group('StoredVisibility modes', () {
    test('a dive opens in the shape it was saved in', () {
      expect(
        const StoredVisibility(meters: 6).naturalMode,
        VisibilityInputMode.precise,
      );
      expect(
        const StoredVisibility(range: coldGood).naturalMode,
        VisibilityInputMode.range,
      );
      expect(
        const StoredVisibility(legacy: Visibility.good).naturalMode,
        VisibilityInputMode.range,
      );
      expect(StoredVisibility.none.naturalMode, isNull);
    });

    test('only a new value is remembered as the last-used mode', () {
      expect(
        const StoredVisibility(range: coldGood).modeToRemember,
        VisibilityInputMode.range,
      );
      expect(
        const StoredVisibility(legacy: Visibility.good).modeToRemember,
        isNull,
      );
    });
  });

  group('effectiveVisibilityBand', () {
    test('a stored range selects the chip it equals on the current scale', () {
      expect(
        effectiveVisibilityBand(
          band: null,
          touched: false,
          original: const StoredVisibility(range: coldGood),
          scale: cold,
        ),
        VisibilityBand.good,
      );
    });

    test('after a scale change the stored range selects no chip', () {
      expect(
        effectiveVisibilityBand(
          band: null,
          touched: false,
          original: const StoredVisibility(range: coldGood),
          scale: tropical,
        ),
        isNull,
      );
    });
  });
}
```

Add a caption group to the same file once `l10n` / `UnitFormatter` setup is copied from `test/features/dive_log/presentation/formatters/visibility_display_test.dart`:

```dart
  group('visibilityEntryCaption', () {
    test('a picked band shows the range it will save', () {
      expect(
        visibilityEntryCaption(
          mode: VisibilityInputMode.range,
          preciseMeters: null,
          band: VisibilityBand.good,
          touched: true,
          original: StoredVisibility.none,
          scale: cold,
          l10n: l10n,
          units: metricUnits,
        ),
        '6-12 m',
      );
    });

    test('an off-scale stored range shows itself', () {
      expect(
        visibilityEntryCaption(
          mode: VisibilityInputMode.range,
          preciseMeters: null,
          band: null,
          touched: false,
          original: const StoredVisibility(range: coldGood),
          scale: tropical,
          l10n: l10n,
          units: metricUnits,
        ),
        '6-12 m',
      );
    });

    test('a typed number shows its band', () {
      expect(
        visibilityEntryCaption(
          mode: VisibilityInputMode.precise,
          preciseMeters: 6,
          band: null,
          touched: true,
          original: StoredVisibility.none,
          scale: cold,
          l10n: l10n,
          units: metricUnits,
        ),
        l10n.enum_visibilityBand_good,
      );
    });
  });
```

`visibility_input_mode_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_log/presentation/providers/visibility_input_mode_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/visibility_input/visibility_entry.dart';

void main() {
  test('starts at Precise when nothing is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = VisibilityInputModeNotifier(
      await SharedPreferences.getInstance(),
    );
    expect(notifier.state, VisibilityInputMode.precise);
  });

  test('remembers the last mode saved with', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await VisibilityInputModeNotifier(prefs).remember(VisibilityInputMode.range);
    expect(VisibilityInputModeNotifier(prefs).state, VisibilityInputMode.range);
  });

  test('an unknown stored value falls back to Precise', () async {
    SharedPreferences.setMockInitialValues({
      'dive_edit_visibility_input_mode': 'guess',
    });
    final notifier = VisibilityInputModeNotifier(
      await SharedPreferences.getInstance(),
    );
    expect(notifier.state, VisibilityInputMode.precise);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/visibility_input/ test/features/dive_log/presentation/providers/visibility_input_mode_provider_test.dart`
Expected: FAIL (files missing).

- [ ] **Step 3: Implement**

`visibility_entry.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/domain/visibility/visibility_range.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/formatters/visibility_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Which visibility input the edit form shows (issue #3226).
enum VisibilityInputMode { range, precise }

/// A dive's visibility as stored: at most one of a measured distance, a
/// range, or a pre-v144 bucket (issue #3226).
class StoredVisibility {
  final double? meters;
  final VisibilityRange? range;
  final Visibility? legacy;

  const StoredVisibility({this.meters, this.range, this.legacy});

  static const none = StoredVisibility();

  /// [dive]'s stored shape; [Visibility.unknown] counts as no bucket.
  factory StoredVisibility.of(Dive dive) => StoredVisibility(
    meters: dive.visibilityMeters,
    range: dive.visibilityRange,
    legacy: dive.visibility == Visibility.unknown ? null : dive.visibility,
  );

  bool get isEmpty => meters == null && range == null && legacy == null;

  /// The mode a dive opens in: the shape it was saved in. A legacy bucket
  /// is a range of sorts, so it opens in Range. Null for no visibility, so
  /// the caller falls back to the remembered mode.
  VisibilityInputMode? get naturalMode {
    if (meters != null) return VisibilityInputMode.precise;
    if (range != null || legacy != null) return VisibilityInputMode.range;
    return null;
  }

  /// The mode to remember after saving this: only a new value counts, never
  /// a legacy bucket carried through.
  VisibilityInputMode? get modeToRemember {
    if (meters != null) return VisibilityInputMode.precise;
    if (range != null) return VisibilityInputMode.range;
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is StoredVisibility &&
      other.meters == meters &&
      other.range == range &&
      other.legacy == legacy;

  @override
  int get hashCode => Object.hash(meters, range, legacy);
}

/// What a save writes for the visibility input.
///
/// Until the diver touches the input (types a number or taps a chip) the
/// dive keeps exactly what it had: re-saving to fix the notes must not
/// round a measurement or rewrite a range under a changed scale. Once
/// touched, only the active mode's value is saved, and an empty active mode
/// saves no visibility.
StoredVisibility resolveVisibilityEntry({
  required VisibilityInputMode mode,
  required double? preciseMeters,
  required VisibilityBand? band,
  required bool touched,
  required StoredVisibility original,
  required VisibilityScale scale,
}) {
  if (!touched) return original;
  if (mode == VisibilityInputMode.precise && preciseMeters != null) {
    return StoredVisibility(meters: preciseMeters);
  }
  if (mode == VisibilityInputMode.range && band != null) {
    return StoredVisibility(range: scale.rangeFor(band));
  }
  return StoredVisibility.none;
}

/// The chip shown selected: the diver's pick once touched, else the band
/// whose range equals the stored range on the current scale. Derived at
/// build time so it follows the scale once settings finish loading.
VisibilityBand? effectiveVisibilityBand({
  required VisibilityBand? band,
  required bool touched,
  required StoredVisibility original,
  required VisibilityScale scale,
}) {
  if (touched) return band;
  final range = original.range;
  return range == null ? null : scale.bandMatching(range);
}

/// The caption under the visibility input: the band a typed number falls
/// in, the range a picked chip saves, or, before the diver touches the
/// input, the stored range or legacy bucket it will keep.
String? visibilityEntryCaption({
  required VisibilityInputMode mode,
  required double? preciseMeters,
  required VisibilityBand? band,
  required bool touched,
  required StoredVisibility original,
  required VisibilityScale scale,
  required AppLocalizations l10n,
  required UnitFormatter units,
}) {
  switch (mode) {
    case VisibilityInputMode.precise:
      if (preciseMeters != null) {
        return visibilityBandName(scale.bandFor(preciseMeters), l10n);
      }
    case VisibilityInputMode.range:
      if (band != null) {
        return formatVisibilityRange(scale.rangeFor(band), l10n, units);
      }
  }
  if (touched) return null;
  if (original.range case final range?) {
    return formatVisibilityRange(range, l10n, units);
  }
  if (original.legacy case final legacy?) {
    return formatLegacyVisibilityBand(legacy, l10n, units);
  }
  return null;
}
```

`visibility_input_mode_provider.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/visibility_input/visibility_entry.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

const _kVisibilityInputModeKey = 'dive_edit_visibility_input_mode';

/// The visibility input a new dive's form opens with: the mode of the last
/// save that carried a new visibility value (issue #3226). A per-device
/// convenience, not diver data, so it lives in SharedPreferences and does
/// not sync. Starts at Precise, the form's behaviour before ranges existed.
class VisibilityInputModeNotifier extends StateNotifier<VisibilityInputMode> {
  VisibilityInputModeNotifier(this._prefs) : super(_read(_prefs));

  final SharedPreferences _prefs;

  static VisibilityInputMode _read(SharedPreferences prefs) =>
      VisibilityInputMode.values.asNameMap()[prefs.getString(
        _kVisibilityInputModeKey,
      )] ??
      VisibilityInputMode.precise;

  Future<void> remember(VisibilityInputMode mode) async {
    state = mode;
    await _prefs.setString(_kVisibilityInputModeKey, mode.name);
  }
}

final visibilityInputModeProvider =
    StateNotifierProvider<VisibilityInputModeNotifier, VisibilityInputMode>(
      (ref) => VisibilityInputModeNotifier(ref.watch(sharedPreferencesProvider)),
    );
```

- [ ] **Step 4: Run tests to verify they pass**

Run the Step 2 command, then `flutter test test/architecture/`.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/dive_log/presentation/widgets/visibility_input/visibility_entry.dart lib/features/dive_log/presentation/providers/visibility_input_mode_provider.dart test/features/dive_log/presentation/widgets/visibility_input test/features/dive_log/presentation/providers/visibility_input_mode_provider_test.dart
git commit -m "feat(dive-log): decide what the visibility input saves and remember its mode"
```

---

### Task 8: The Range | Precise input in the edit form and bulk edit

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/visibility_input/visibility_input.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (state :311 and :362-365, seed :958-961, `_collectScalarInputs` :1519, bulk row :2024-2032, `_saveBulk` after `service.apply`, `_visibilityMetersInput`/`_visibilityCaption`/`_conditionsSummary`/`_conditionsIsEmpty` :4787-4840, `_environmentRows` visibility block :4845-4866, `_saveDive` literal :5909-5917 and after the save call :6032-6044)
- Modify: `lib/features/dive_log/presentation/pages/bulk_edit_field_set.dart:75,118-121,176-181`
- Modify: all 11 ARBs (keys `diveLog_edit_visibility_modeRange`, `diveLog_edit_visibility_modePrecise`), regenerate l10n
- Test: `test/features/dive_log/presentation/widgets/visibility_input/visibility_input_test.dart` (create), `test/features/dive_log/presentation/pages/dive_edit_visibility_field_test.dart`, `test/features/dive_log/presentation/pages/bulk_edit_field_set_test.dart`

**Interfaces:**
- Consumes: everything in Task 7.
- Produces: `class VisibilityInput extends StatelessWidget` with `required VisibilityInputMode mode, required ValueChanged<VisibilityInputMode> onModeChanged, required TextEditingController controller, required String depthSymbol, required String? Function(String?)? inputValidator, required ValueChanged<String> onPreciseChanged, required VisibilityBand? band, required ValueChanged<VisibilityBand?> onBandChanged, required String? caption`. `BulkScalarInputs.visibilityMinMeters`, `.visibilityMaxMeters`.

- [ ] **Step 1: Write the failing tests**

`visibility_input_test.dart`: pump `VisibilityInput` in a `MaterialApp` with `AppLocalizations` delegates and assert:

```dart
  testWidgets('Range shows four band chips and reports a pick', (tester) async {
    VisibilityBand? picked;
    await pump(tester, mode: VisibilityInputMode.range, onBand: (b) => picked = b);
    for (final name in ['Poor', 'Moderate', 'Good', 'Excellent']) {
      expect(find.widgetWithText(ChoiceChip, name), findsOneWidget);
    }
    await tester.tap(find.widgetWithText(ChoiceChip, 'Good'));
    expect(picked, VisibilityBand.good);
  });

  testWidgets('tapping the selected chip clears the pick', (tester) async {
    VisibilityBand? picked = VisibilityBand.good;
    await pump(
      tester,
      mode: VisibilityInputMode.range,
      band: VisibilityBand.good,
      onBand: (b) => picked = b,
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Good'));
    expect(picked, isNull);
  });

  testWidgets('Precise shows the number field and no chips', (tester) async {
    await pump(tester, mode: VisibilityInputMode.precise);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Visibility'), findsOneWidget);
  });

  testWidgets('the segmented control switches mode', (tester) async {
    VisibilityInputMode? mode;
    await pump(
      tester,
      mode: VisibilityInputMode.precise,
      onMode: (m) => mode = m,
    );
    await tester.tap(find.text('Range'));
    expect(mode, VisibilityInputMode.range);
  });
```

with a local `pump(tester, {mode, band, onBand, onMode, caption})` helper that builds `VisibilityInput(mode: mode, onModeChanged: onMode ?? (_) {}, controller: TextEditingController(), depthSymbol: 'm', inputValidator: null, onPreciseChanged: (_) {}, band: band, onBandChanged: onBand ?? (_) {}, caption: caption)` inside `Scaffold(body: ListView(children: [...]))`.

In `dive_edit_visibility_field_test.dart` (existing harness; widen `buildDive` with `double? min, double? max`) add:

```dart
  testWidgets('picking a band saves its range on the diver scale', (
    tester,
  ) async {
    final created = await repository.createDive(buildDive());
    await pumpEditPage(tester, created.id);
    await expandConditions(tester);
    await tester.tap(find.text('Range'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Good'));
    await tester.pumpAndSettle();
    // Default scale is tropical: Good is 15-30 m.
    expect(find.text('15-30 m'), findsOneWidget);
    await tapSave(tester);

    final saved = (await repository.getDiveById(created.id))!;
    expect(saved.visibilityMeters, isNull);
    expect(saved.visibilityRange, const VisibilityRange(minM: 15, maxM: 30));
  });

  testWidgets('a range dive opens in Range with its chip selected', (
    tester,
  ) async {
    final created = await repository.createDive(buildDive(min: 15, max: 30));
    await pumpEditPage(tester, created.id);
    await expandConditions(tester);
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Good'),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('an off-scale range shows itself and survives an untouched '
      'save', (tester) async {
    // Cold water Good, viewed under the default tropical scale.
    final created = await repository.createDive(buildDive(min: 6, max: 12));
    await pumpEditPage(tester, created.id);
    await expandConditions(tester);
    for (final chip in tester.widgetList<ChoiceChip>(find.byType(ChoiceChip))) {
      expect(chip.selected, isFalse);
    }
    expect(find.text('6-12 m'), findsWidgets);
    await tapSave(tester);

    final saved = (await repository.getDiveById(created.id))!;
    expect(saved.visibilityRange, const VisibilityRange(minM: 6, maxM: 12));
  });

  testWidgets('an untouched measured dive keeps its unrounded value', (
    tester,
  ) async {
    final created = await repository.createDive(
      buildDive(visibilityMeters: 6.44),
    );
    await pumpEditPage(tester, created.id);
    await tapSave(tester);
    expect((await repository.getDiveById(created.id))!.visibilityMeters, 6.44);
  });

  testWidgets('a new dive opens in the last-used mode', (tester) async {
    SharedPreferences.setMockInitialValues({
      'dive_edit_visibility_input_mode': 'range',
    });
    await pumpEditPage(tester, null);
    await expandConditions(tester);
    expect(find.byType(ChoiceChip), findsNWidgets(4));
  });
```

(`pumpEditPage` must accept a nullable id for a new dive; check that `getBaseOverrides()` reads `SharedPreferences.getInstance()` after `setMockInitialValues`. If `getBaseOverrides` itself resets prefs to `{}`, pass the mock values through its parameter or override `visibilityInputModeProvider` in the `ProviderScope` with a notifier built on prefs seeded after it.)

In `bulk_edit_field_set_test.dart` add:

```dart
  test('a bulk range writes both ends and clears measurement and bucket', () {
    final c = buildScalarCompanion(
      {BulkField.visibility},
      const BulkScalarInputs(visibilityMinMeters: 6, visibilityMaxMeters: 12),
    );
    expect(c.visibilityMinMeters, const Value<double?>(6));
    expect(c.visibilityMaxMeters, const Value<double?>(12));
    expect(c.visibilityMeters, const Value<double?>(null));
    expect(c.visibility, const Value<String?>(null));
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/widgets/visibility_input/ test/features/dive_log/presentation/pages/dive_edit_visibility_field_test.dart test/features/dive_log/presentation/pages/bulk_edit_field_set_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

ARBs: insert after `diveLog_edit_label_visibility` in all 11 files:

| Locale | `diveLog_edit_visibility_modeRange` | `diveLog_edit_visibility_modePrecise` |
| --- | --- | --- |
| en | Range | Precise |
| ar | نطاق | دقيق |
| de | Bereich | Genau |
| es | Rango | Preciso |
| fr | Plage | Précis |
| he | טווח | מדויק |
| hu | Tartomány | Pontos |
| it | Intervallo | Preciso |
| nl | Bereik | Exact |
| pt | Faixa | Preciso |
| zh | 范围 | 精确 |

Then `flutter gen-l10n`.

`visibility_input.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/features/dive_log/presentation/formatters/visibility_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/visibility_input/visibility_entry.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';

/// The dive edit form's visibility input (issue #3226): a band pick or a
/// precise number, with a Range | Precise switch under it. Stateless; the
/// page owns the values and decides what a save writes
/// ([resolveVisibilityEntry]).
class VisibilityInput extends StatelessWidget {
  const VisibilityInput({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.controller,
    required this.depthSymbol,
    required this.inputValidator,
    required this.onPreciseChanged,
    required this.band,
    required this.onBandChanged,
    required this.caption,
  });

  final VisibilityInputMode mode;
  final ValueChanged<VisibilityInputMode> onModeChanged;
  final TextEditingController controller;
  final String depthSymbol;
  final String? Function(String?)? inputValidator;
  final ValueChanged<String> onPreciseChanged;
  final VisibilityBand? band;
  final ValueChanged<VisibilityBand?> onBandChanged;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = l10n.diveLog_edit_label_visibility;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        switch (mode) {
          VisibilityInputMode.precise => FormRow.text(
            label: label,
            controller: controller,
            suffixText: depthSymbol,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            // No input filter: stripping '-' would turn "-5", which saves as
            // unknown, into 5 m. Unreadable text would otherwise save as
            // "unknown" too and erase a measured visibility (#1900).
            inputValidator: inputValidator,
            onChanged: onPreciseChanged,
          ),
          VisibilityInputMode.range => FormRow.custom(
            label: label,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final b in VisibilityBand.values)
                  ChoiceChip(
                    label: Text(visibilityBandName(b, l10n)),
                    selected: band == b,
                    onSelected: (selected) => onBandChanged(selected ? b : null),
                  ),
              ],
            ),
          ),
        },
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  caption ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              SegmentedButton<VisibilityInputMode>(
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: VisibilityInputMode.range,
                    label: Text(l10n.diveLog_edit_visibility_modeRange),
                  ),
                  ButtonSegment(
                    value: VisibilityInputMode.precise,
                    label: Text(l10n.diveLog_edit_visibility_modePrecise),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (s) => onModeChanged(s.first),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

(Confirm the `context.l10n` extension import path used by `dive_edit_page.dart` and use the same one.)

`bulk_edit_field_set.dart`: add `this.visibilityMinMeters, this.visibilityMaxMeters,` to `BulkScalarInputs` with docs ("Low / high end of a visibility range (issue #3226); set only when the diver picked a band. Exclusive of [visibilityMeters]."), and the `BulkField.visibility` branch:

```dart
      BulkField.visibility => c.copyWith(
        visibilityMeters: Value(i.visibilityMeters),
        visibilityMinMeters: Value(
          i.visibilityMeters == null ? i.visibilityMinMeters : null,
        ),
        visibilityMaxMeters: Value(
          i.visibilityMeters == null ? i.visibilityMaxMeters : null,
        ),
        // Clear the legacy bucket so a bulk-set value cannot leave a dive
        // carrying a contradicting band.
        visibility: const Value(null),
      ),
```

`dive_edit_page.dart`:

1. Remove `Visibility _selectedVisibility` and the Task 3 `_storedVisibilityRange`; add:

```dart
  /// The dive's visibility as loaded (issue #3226), saved back untouched
  /// until the diver types a number or taps a chip.
  StoredVisibility _originalVisibility = StoredVisibility.none;
  late VisibilityInputMode _visibilityMode = ref.read(
    visibilityInputModeProvider,
  );
  VisibilityBand? _visibilityBand;
  bool _visibilityTouched = false;
```

Update the `_visibilityController` doc: "Precise visibility, entered in the diver's depth unit and converted to meters on save. The Range mode's pick lives in [_visibilityBand]."

2. Seed (replacing the `_selectedVisibility` line and the Task 3 carry):

```dart
          _originalVisibility = StoredVisibility.of(dive);
          _visibilityMode = _originalVisibility.naturalMode ?? _visibilityMode;
```

3. Helpers replacing `_visibilityCaption` (keep `_visibilityMetersInput`):

```dart
  VisibilityScale get _visibilityScale =>
      ref.read(settingsProvider).visibilityScale;

  /// What a save writes for visibility. See [resolveVisibilityEntry].
  StoredVisibility _resolvedVisibility(UnitFormatter units) =>
      resolveVisibilityEntry(
        mode: _visibilityMode,
        preciseMeters: _visibilityMetersInput(units),
        band: _visibilityBand,
        touched: _visibilityTouched,
        original: _originalVisibility,
        scale: _visibilityScale,
      );

  Widget _visibilityInput(UnitFormatter units, {String? Function(String?)? validator}) {
    final scale = ref.watch(settingsProvider).visibilityScale;
    final band = effectiveVisibilityBand(
      band: _visibilityBand,
      touched: _visibilityTouched,
      original: _originalVisibility,
      scale: scale,
    );
    return VisibilityInput(
      mode: _visibilityMode,
      onModeChanged: (m) => setState(() => _visibilityMode = m),
      controller: _visibilityController,
      depthSymbol: units.depthSymbol,
      inputValidator: validator ?? numberValidator(context),
      onPreciseChanged: (_) => setState(() => _visibilityTouched = true),
      band: band,
      onBandChanged: (b) => setState(() {
        _visibilityBand = b;
        _visibilityTouched = true;
      }),
      caption: visibilityEntryCaption(
        mode: _visibilityMode,
        preciseMeters: _visibilityMetersInput(units),
        band: band,
        touched: _visibilityTouched,
        original: _originalVisibility,
        scale: scale,
        l10n: context.l10n,
        units: units,
      ),
    );
  }
```

4. `_environmentRows`: replace the whole visibility `Column(...)` with `_visibilityInput(units),`.

5. `_conditionsSummary`: replace the visibility branch with:

```dart
      ...switch (_resolvedVisibility(units)) {
        StoredVisibility(:final meters?) => [units.formatDistance(meters)],
        StoredVisibility(:final range?) => [
          formatVisibilityRange(range, context.l10n, units),
        ],
        StoredVisibility(:final legacy?) => [
          ?formatLegacyVisibilityBand(legacy, context.l10n, units),
        ],
        _ => const <String>[],
      },
```

6. `_conditionsIsEmpty` takes `UnitFormatter units` (update its one caller in `_buildConditionsSection`) and replaces the two visibility terms with `_visibilityController.text.isEmpty && _resolvedVisibility(units).isEmpty &&`.

7. `_saveDive`: before the `Dive(` literal, `final savedVisibility = _resolvedVisibility(units);`; in the literal replace the `visibility:` / `visibilityMeters:` / Task 3 range lines with:

```dart
        // One visibility shape (issue #3226): what the diver entered, or the
        // stored shape when they left the input alone.
        visibility: savedVisibility.legacy,
        visibilityMeters: savedVisibility.meters,
        visibilityMinMeters: savedVisibility.range?.minM,
        visibilityMaxMeters: savedVisibility.range?.maxM,
```

and after the `if (widget.isEditing) { ... } else { ... }` save block completes:

```dart
      if (_visibilityTouched) {
        if (savedVisibility.modeToRemember case final mode?) {
          await ref.read(visibilityInputModeProvider.notifier).remember(mode);
        }
      }
```

8. Bulk: the `_gatedRow(BulkField.visibility, ...)` child becomes `_visibilityInput(units, validator: _bulkValidator(BulkField.visibility))` (pass `units` into `_buildBulkConditionsSection` if it lacks it). `_collectScalarInputs`:

```dart
    // Bulk has no stored shape to keep: the active mode's value is the input.
    final bulkVisibility = resolveVisibilityEntry(
      mode: _visibilityMode,
      preciseMeters: _visibilityMetersInput(units),
      band: _visibilityBand,
      touched: true,
      original: StoredVisibility.none,
      scale: _visibilityScale,
    );
```

passing `visibilityMeters: bulkVisibility.meters, visibilityMinMeters: bulkVisibility.range?.minM, visibilityMaxMeters: bulkVisibility.range?.maxM,`. After `service.apply(...)` succeeds, when `_bulkEnabled.contains(BulkField.visibility)` and `bulkVisibility.modeToRemember` is non-null, remember it the same way (compute `bulkVisibility` once in `_saveBulk` and pass it in, or recompute; both read the same state).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/presentation/ test/l10n/ test/architecture/`
Expected: PASS (existing visibility field, locale number input, bulk edit and save-census tests included).

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/dive_log/presentation lib/l10n/arb test/features/dive_log/presentation
git commit -m "feat(dive-log): offer a visibility range alongside the precise number"
```

---

### Task 9: CSV and Excel export and import

**Files:**
- Modify: `lib/core/services/export/csv/codec/csv_column.dart:54-58`, `lib/core/services/export/csv/dive_csv_columns.dart:27-28,81-121`, `lib/core/services/export/csv/csv_dives_writer.dart` (header after `diveTypeIds` :87-89, row at the matching slot)
- Modify: `lib/features/universal_import/data/parsers/submersion_csv/submersion_dives_csv_parser.dart:30-41,119,139-147`
- Modify: `lib/features/universal_import/data/parsers/csv_import_parser.dart:290-292`
- Modify: `lib/features/universal_import/data/csv/pipeline/csv_transformer.dart:529-546`
- Modify: `lib/features/universal_import/data/csv/extractors/dive_extractor.dart:19-20`
- Modify: `lib/features/universal_import/data/csv/presets/built_in_presets.dart:638-646`
- Modify: `lib/features/dive_import/data/services/uddf_entity_importer.dart:2767-2768`
- Modify: `lib/core/services/export/excel/excel_export_service.dart:235-236,280-281`
- Test: `test/core/services/export/csv/csv_round_trip_test.dart`, `test/core/services/export/csv/csv_dive_types_test.dart:83`, `test/core/services/export/csv/goldens/dives_metric.csv`, `test/features/universal_import/data/parsers/csv_import_parser_test.dart`, `test/core/services/export/excel/excel_export_service_test.dart`

**Interfaces:**
- Consumes: `VisibilityRange.tryParse` (Task 1), `Dive.visibilityMinMeters/MaxMeters` (Task 3).
- Produces: `CsvColumns.visibilityMin`, `CsvColumns.visibilityMax`, `DiveCsvColumns.visibilityMin` (`'Visibility Min (m)'`), `DiveCsvColumns.visibilityMax` (`'Visibility Max (m)'`); import map keys `visibilityMinMeters`, `visibilityMaxMeters`.

- [ ] **Step 1: Write the failing tests**

In `csv_round_trip_test.dart`, following its existing export-then-parse pattern, add a case that exports a dive with `visibilityMinMeters: 6, visibilityMaxMeters: 12` and one with only `visibilityMinMeters: 12`, re-imports, and asserts both ranges come back and `visibilityMeters` is null; and in imperial "My units" mode that 6-12 m round-trips within 0.05 m.

Add an import case that a row whose Visibility Min is `12` and Visibility Max is `6` (inverted) imports with no range (Review Focus 5).

In `csv_import_parser_test.dart`:

```dart
  test('visibility min/max headers map to the range, not the measurement '
      '(issue #3226)', () {
    // Use the file's existing helper that runs _guessTargetField on headers.
    expect(guessTarget('Visibility Min (m)'), 'visibilityMinMeters');
    expect(guessTarget('Visibility Max (m)'), 'visibilityMaxMeters');
    expect(guessTarget('Visibility (m)'), 'visibilityMeters');
  });
```

Update `csv_dive_types_test.dart:83` to:

```dart
    // Later columns append after the dive types, so position-addressed
    // spreadsheets keep their offsets.
    expect(
      DiveCsvColumns.fixed.sublist(DiveCsvColumns.fixed.length - 3),
      [
        DiveCsvColumns.diveTypeIds,
        DiveCsvColumns.visibilityMin,
        DiveCsvColumns.visibilityMax,
      ],
    );
```

In `excel_export_service_test.dart` add a case that a range dive writes `6.0` and `12.0` under `Visibility Min (m)` / `Visibility Max (m)` and an empty `Visibility (m)` cell.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/export/csv test/core/services/export/excel test/features/universal_import`
Expected: FAIL.

- [ ] **Step 3: Implement**

`csv_column.dart`:

```dart
  /// Low end of a visibility range (issue #3226), inclusive; empty for a
  /// measured or legacy dive.
  static const visibilityMin = CsvColumn(
    'Visibility Min',
    CsvQuantity.depth,
    metricDecimals: 1,
  );

  /// High end of a visibility range, exclusive.
  static const visibilityMax = CsvColumn(
    'Visibility Max',
    CsvQuantity.depth,
    metricDecimals: 1,
  );
```

`dive_csv_columns.dart`: `static const visibilityMin = 'Visibility Min (m)';`, `static const visibilityMax = 'Visibility Max (m)';`, appended to `fixed` right after `diveTypeIds`.

`csv_dives_writer.dart`: header `units.header(CsvColumns.visibilityMin), units.header(CsvColumns.visibilityMax),` right after the `diveTypeIds` header; row `units.value(CsvColumns.visibilityMin, dive.visibilityMinMeters), units.value(CsvColumns.visibilityMax, dive.visibilityMaxMeters),` at the matching slot (before the custom-field spread in both).

`submersion_dives_csv_parser.dart`: add both columns to `_unitColumns`; next to `visibilityMeters`:

```dart
    // A hand-edited inverted or negative range imports as no range.
    final visibilityRange = VisibilityRange.tryParse(
      table.quantity(row, CsvColumns.visibilityMin),
      table.quantity(row, CsvColumns.visibilityMax),
    );
```

and in the map `'visibilityMinMeters': visibilityRange?.minM, 'visibilityMaxMeters': visibilityRange?.maxM,`.

`csv_import_parser.dart`, before the existing visibility branch:

```dart
  // A range end (issue #3226) must not be auto-mapped onto the measurement.
  if (header.contains('visibility') && header.contains('min')) {
    return 'visibilityMinMeters';
  }
  if (header.contains('visibility') && header.contains('max')) {
    return 'visibilityMaxMeters';
  }
```

(confirm `header` is already lower-cased there.)

`csv_transformer.dart` `_isDoubleField`: add `base == 'visibilityminmeters' || base == 'visibilitymaxmeters' ||`.

`dive_extractor.dart` `_diveFields`: add `'visibilityMinMeters', 'visibilityMaxMeters',`.

`built_in_presets.dart` Submersion native preset mappings:

```dart
        ColumnMapping(
          sourceColumn: DiveCsvColumns.visibilityMin,
          targetField: 'visibilityMinMeters',
        ),
        ColumnMapping(
          sourceColumn: DiveCsvColumns.visibilityMax,
          targetField: 'visibilityMaxMeters',
        ),
```

`uddf_entity_importer.dart`, after `visibilityMeters:`:

```dart
        visibilityMinMeters: asDoubleOrNull(diveData['visibilityMinMeters']),
        visibilityMaxMeters: asDoubleOrNull(diveData['visibilityMaxMeters']),
```

(use whatever numeric coercion helper that file already uses for doubles if `asDoubleOrNull` is not in scope.)

`excel_export_service.dart`: headers `'Visibility Min (m)', 'Visibility Max (m)',` after `'Visibility Rating',`; values `dive.visibilityMinMeters?.toStringAsFixed(1) ?? '', dive.visibilityMaxMeters?.toStringAsFixed(1) ?? '',` after the rating value.

Regenerate the CSV golden the way `csv_metric_golden_test.dart` documents (read its header comment); check the diff shows only the two new columns.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/export test/features/universal_import test/features/dive_import`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/core/services/export/csv lib/core/services/export/excel lib/features/universal_import lib/features/dive_import/data/services/uddf_entity_importer.dart test/core/services/export test/features/universal_import
git commit -m "feat(dive-log): export and import visibility ranges in CSV and Excel"
```

---

### Task 10: UDDF range block

**Files:**
- Create: `lib/core/services/export/uddf/uddf_visibility_range.dart`
- Modify: `lib/core/services/export/uddf/uddf_export_builders.dart` (`buildApplicationData` params :791-795, `hasData` :829, write after tissue :1474)
- Modify: `lib/core/services/export/uddf/uddf_full_export_service.dart:407-409`, `lib/core/services/export/uddf/uddf_export_service.dart:660-661`
- Modify: `lib/core/services/export/uddf/uddf_full_import_service.dart:571-583`
- Test: `test/core/services/export/uddf/uddf_visibility_range_test.dart` (create), `test/core/services/export/uddf/uddf_import_visibility_test.dart`

**Interfaces:**
- Consumes: `VisibilityRange.tryParse` (Task 1), `Dive.visibilityRange` (Task 3), importer keys (Task 9).
- Produces: `abstract final class UddfVisibilityRange { static const sectionName = 'visibilityranges'; static bool hasData(Dive); static void write(XmlBuilder, Iterable<Dive>); static Map<String, VisibilityRange> parse(XmlElement); static void apply(Map<String, dynamic>, VisibilityRange); }`; `buildApplicationData(..., List<Dive>? visibilityRangeDives)`.

- [ ] **Step 1: Write the failing tests**

`uddf_visibility_range_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:submersion/core/domain/visibility/visibility_range.dart';
import 'package:submersion/core/services/export/uddf/uddf_visibility_range.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  Dive dive(String id, {double? meters, double? min, double? max}) => Dive(
    id: id,
    dateTime: DateTime.utc(2026, 1, 1),
    visibilityMeters: meters,
    visibilityMinMeters: min,
    visibilityMaxMeters: max,
  );

  XmlElement written(List<Dive> dives) {
    final builder = XmlBuilder();
    builder.element(
      'root',
      nest: () => UddfVisibilityRange.write(builder, dives),
    );
    return builder.buildDocument().rootElement;
  }

  test('writes one dive ref per range dive, open ends omitted', () {
    final root = written([
      dive('a', min: 6, max: 12),
      dive('b', min: 12),
      dive('c', meters: 8),
      dive('d'),
    ]);
    final refs = root
        .findAllElements('dive')
        .map((e) => e.getAttribute('ref'))
        .toList();
    expect(refs, ['dive_a', 'dive_b']);
    final b = root.findAllElements('dive').last;
    expect(b.getAttribute('min'), '12.0');
    expect(b.getAttribute('max'), isNull);
  });

  test('writes nothing when no dive has a range', () {
    expect(written([dive('c', meters: 8)]).children, isEmpty);
  });

  test('parse round-trips and drops unreadable entries', () {
    final block = XmlDocument.parse(
      '<visibilityranges>'
      '<dive ref="dive_a" min="6.0" max="12.0"/>'
      '<dive ref="dive_b" min="12.0"/>'
      '<dive ref="dive_c" min="12" max="6"/>'
      '<dive ref="dive_d" min="-1"/>'
      '<dive min="1"/>'
      '</visibilityranges>',
    ).rootElement;
    expect(UddfVisibilityRange.parse(block), {
      'dive_a': const VisibilityRange(minM: 6, maxM: 12),
      'dive_b': const VisibilityRange(minM: 12),
    });
  });

  test('apply sets the importer keys unless the dive has a measurement', () {
    final plain = <String, dynamic>{};
    UddfVisibilityRange.apply(plain, const VisibilityRange(minM: 6, maxM: 12));
    expect(plain['visibilityMinMeters'], 6);
    expect(plain['visibilityMaxMeters'], 12);

    final measured = <String, dynamic>{'visibilityMeters': 8.0};
    UddfVisibilityRange.apply(measured, const VisibilityRange(minM: 6));
    expect(measured.containsKey('visibilityMinMeters'), isFalse);
  });
}
```

In `uddf_import_visibility_test.dart` (or the tissue round-trip test it sits beside), add a full export-then-import round trip of a range dive through `UddfFullExportService` and `importAllDataFromUddf`, asserting the imported dive map has `visibilityMinMeters: 6.0`, `visibilityMaxMeters: 12.0`, and no `visibilityMeters`. Mirror `test/core/services/export/uddf/uddf_computer_tissue_round_trip_test.dart` for the harness.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/services/export/uddf/uddf_visibility_range_test.dart test/core/services/export/uddf/uddf_import_visibility_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`uddf_visibility_range.dart`:

```dart
import 'package:xml/xml.dart';

import 'package:submersion/core/domain/visibility/visibility_range.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A dive's visibility range in UDDF (issue #3226).
///
/// UDDF's `<visibility>` holds one distance, so a dive logged as a band
/// ("Good", saved as 6-12 m) writes nothing there rather than an invented
/// number. Both writers put the range in the private
/// `<applicationdata><submersion><visibilityranges>` block instead, one
/// `<dive ref>` per dive that has one, so a Submersion backup round-trips:
///
/// ```xml
/// <visibilityranges>
///   <dive ref="dive_ID" min="6.0" max="12.0"/>
/// </visibilityranges>
/// ```
///
/// An open end omits its attribute. Values are meters, unrounded.
abstract final class UddfVisibilityRange {
  static const sectionName = 'visibilityranges';

  /// Whether [dive] has a range to carry. A dive that also has a
  /// measurement is read as measured everywhere, so its range is not
  /// written.
  static bool hasData(Dive dive) =>
      dive.visibilityMeters == null && dive.visibilityRange != null;

  /// Writes the block for the [dives] that have a range; writes nothing when
  /// none has.
  static void write(XmlBuilder builder, Iterable<Dive> dives) {
    final withData = dives.where(hasData).toList();
    if (withData.isEmpty) return;
    builder.element(
      sectionName,
      nest: () {
        for (final dive in withData) {
          final range = dive.visibilityRange!;
          builder.element(
            'dive',
            attributes: {
              'ref': 'dive_${dive.id}',
              if (range.minM case final min?) 'min': min.toString(),
              if (range.maxM case final max?) 'max': max.toString(),
            },
          );
        }
      },
    );
  }

  /// Reads the block: per dive ref, its range. An entry with no ref, or
  /// whose range is unreadable ([VisibilityRange.tryParse]), is skipped.
  static Map<String, VisibilityRange> parse(XmlElement block) {
    final byDive = <String, VisibilityRange>{};
    for (final dive in block.findElements('dive')) {
      final ref = dive.getAttribute('ref');
      if (ref == null || ref.isEmpty) continue;
      final range = VisibilityRange.tryParse(
        double.tryParse(dive.getAttribute('min') ?? ''),
        double.tryParse(dive.getAttribute('max') ?? ''),
      );
      if (range != null) byDive[ref] = range;
    }
    return byDive;
  }

  /// Puts [range] on the parsed [dive] map under the keys
  /// `UddfEntityImporter` reads. A measurement on the same dive wins, as in
  /// the repository's one-shape rule, so nothing is applied then.
  static void apply(Map<String, dynamic> dive, VisibilityRange range) {
    if (dive['visibilityMeters'] != null) return;
    dive['visibilityMinMeters'] = range.minM;
    dive['visibilityMaxMeters'] = range.maxM;
  }
}
```

`uddf_export_builders.dart` `buildApplicationData`: parameter after `computerTissueDives`:

```dart
    // The dives whose visibility range goes in the <visibilityranges> block
    // (issue #3226); a dive without one writes none.
    List<Dive>? visibilityRangeDives,
```

`hasData` gains `(visibilityRangeDives?.any(UddfVisibilityRange.hasData) ?? false) ||` after the tissue clause; after `UddfComputerTissue.write(...)`:

```dart
            // Each band-picked dive's visibility range, which the standard
            // <visibility> element cannot hold.
            UddfVisibilityRange.write(
              builder,
              visibilityRangeDives ?? const <Dive>[],
            );
```

Both callers pass `visibilityRangeDives: dives,` next to `computerTissueDives:`.

`uddf_full_import_service.dart`, after the computertissue block:

```dart
        // Each dive's visibility range (issue #3226), matched the same way.
        final visibilityRangeSection = submersionElement
            .findElements(UddfVisibilityRange.sectionName)
            .firstOrNull;
        if (visibilityRangeSection != null) {
          final byDive = UddfVisibilityRange.parse(visibilityRangeSection);
          for (final dive in dives) {
            final range = byDive[dive['sourceUuid']];
            if (range != null) UddfVisibilityRange.apply(dive, range);
          }
        }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/services/export test/features/dive_import`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/core/services/export/uddf test/core/services/export/uddf
git commit -m "feat(dive-log): carry visibility ranges through UDDF backups"
```

---

### Task 11: Whole-branch verification and after screenshots

- [ ] **Step 1:** `dart format .` then `flutter analyze` (expect "No issues found").
- [ ] **Step 2:** `flutter test test/architecture/ test/shared/ test/l10n/ test/core/database/` (guards scan all of `lib/`).
- [ ] **Step 3:** Run every test directory touched: `flutter test test/core test/features/dive_log test/features/insights test/features/universal_import test/features/dive_import test/features/settings test/features/dive_computer test/features/query`.
- [ ] **Step 4:** Confirm `flutter gen-l10n` leaves `git status --porcelain -- 'lib/l10n/arb/app_localizations*.dart'` empty.
- [ ] **Step 5:** After screenshots with the scratchpad harness (`tmp_vis_shots_test.dart`, copied into `test/features/dive_log/presentation/pages/` and run with `--dart-define=SHOT_TAG=after`, then removed): edit form Conditions in light, dark and phone width, in both Range (Good selected) and Precise modes; bulk edit visibility row in Range mode.
