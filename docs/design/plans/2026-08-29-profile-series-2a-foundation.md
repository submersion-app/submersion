# Profile Series 2a: Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the two packed-series tables with their v182 rung, the packer that fills them from the legacy row-per-sample tables with deterministic ids, and the two repositories that read and write series rows, leaving the legacy tables and every existing consumer untouched.

**Architecture:** `dive_profile_series` and `tank_pressure_series` are ordinary Drift tables declared next to their legacy siblings, created by an idempotent `_assertProfileSeriesSchema()` helper that the v182 rung and the `beforeOpen` backstop both call. `packLegacyProfileRows` (its own file under `lib/core/database/`, raw SQL only so it survives the later removal of the legacy table classes) groups legacy rows by identity tuple, drops exact duplicates, encodes each group with the PR 1 codecs, and inserts with uuid v5 ids derived from the tuple, so every device converges. `ProfileSeriesRepository` and `TankPressureSeriesRepository` follow the `TankPressureRepository` shape (zero-arg, singleton database getter, private `SyncRepository`) and are the only production code that encodes or decodes. Plans 2b to 2e move the writers, readers, sync, and retirement onto this foundation.

**Tech Stack:** Drift 2.34 (raw `customSelect`/`customUpdate` in the packer; generated companions in the repositories), `package:uuid` v5, the PR 1 codecs under `lib/features/dive_log/domain/codecs/`, `flutter_test` with `NativeDatabase.memory(setup:)` fixtures.

**Spec:** `docs/superpowers/specs/2026-08-28-profile-sample-storage-design.md`, sections 3 (architecture), 4 (schema), 6 (write and read API), 8 (migration: the rung, deterministic ids), 10 (migration tests). Section 8's "drop the old tables", "purge retired tombstones", and the `VACUUM` belong to plan 2e; section 7 (sync) to plan 2d.

## Global Constraints

- Work only in the worktree `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/profile-sample-storage-2` on branch `worktree-profile-sample-storage-2` (stacked on PR #1387's branch, merged with `origin/main` at schema v180). The shell's working directory does not persist between commands; prefix every command with `cd` into that directory.
- Schema rung is **182**: `origin/main` is at 180 and open PR #1390 (profile photos) holds 181, so 181 is absent from this branch's ladder until that PR lands. Re-check every open PR head (`git fetch origin`, then `git show "origin/${h}:lib/core/database/database.dart"`; in zsh the braces matter, `$h:l` is a modifier) immediately before the PR opens. `currentSchemaVersion` becomes 182; `migrationVersions` gains `182`; `minimumCompatibleSchemaVersion` stays at 170 in this plan (the tables are additive; plan 2d raises it when the legacy sync entities retire).
- Never use an em-dash (U+2014) or an en-dash as punctuation anywhere: code, comments, tests, commit messages, this plan. No emojis.
- Lints: `package:flutter_lints/flutter.yaml` plus `prefer_const_constructors`, `prefer_const_declarations`, `prefer_final_fields`, `prefer_final_locals`, `avoid_print`, `require_trailing_commas`, `always_use_package_imports`. Project imports use `package:submersion/...`; test helpers use the relative `../../../helpers/test_database.dart` form as every existing repository test does.
- `lib/core/database/database.dart` and everything it imports stay Flutter-free. `profile_series_pack.dart` imports only `package:drift` (which re-exports `dart:typed_data`), the codecs, `profile_series.dart`, `profile_sample_dedupe.dart`, and `hlc.dart`.
- Legacy tables `dive_profiles` and `tank_pressure_profiles`, their Drift classes, their indexes, and every existing consumer are NOT modified in this plan. The packer reads them by raw SQL and never by their Drift classes.
- Series identity columns mirror the legacy tables exactly: profile series `(dive_id, computer_id, source_id, is_primary)`; tank series `(dive_id, tank_id, computer_id)`. Summary scalars are exactly spec section 4's set.
- Migrated series ids are uuid v5 over the identity tuple with the literal `null` for absent members (spec section 8). Repository-minted ids are uuid v4.
- Both series tables carry an `hlc` column, so `SyncRepository.hlcTargets` must gain `diveProfileSeries` and `tankPressureSeries` entries, or `sync_hlc_target_registration_test` fails. The sync serializer, `parentRefs`, and `SyncData` are NOT touched in this plan (plan 2d); in this intermediate state a pending `sync_records` row for a series is inert.
- Under `PRAGMA foreign_keys = ON` (set in `beforeOpen`), inserting a series row requires its FK parents to exist. Every fixture that inserts series rows creates `dives`, `dive_computers`, `dive_data_sources`, and `dive_tanks` tables and the parent rows it references.
- Run tests per file (`flutter test <one file>`), never a directory; never pipe `flutter test` through grep, tail, or head. Before every commit: `dart format .` from the worktree root and `flutter analyze` (must report "No issues found!"). After editing `database.dart`, run `dart run build_runner build` before tests (the `--delete-conflicting-outputs` flag is ignored by this build_runner version and prints a warning; that is fine).
- Commit with `git add` of explicit paths only (never `-A` or `.`). Conventional prefixes, no `Co-Authored-By` trailer, no session URL. No push in this plan.
- No new file over 400 lines. `database.dart` is already 9,600 lines; add only the two table classes, the helper, the rung lines, and the backstop line there.

---

## File structure

Create:

| file | responsibility |
|---|---|
| `lib/features/dive_log/domain/entities/profile_series.dart` | `ProfileSeries`, `TankPressureSeries` entities; the two uuid v5 namespaces and `profileSeriesMigratedId` / `tankPressureSeriesMigratedId` |
| `lib/features/dive_log/domain/services/profile_sample_dedupe.dart` | `dedupeExactSamples` / `dedupeExactPressureSamples`, the write-side exact-duplicate drop |
| `lib/core/database/profile_series_pack.dart` | `packLegacyProfileRows`: legacy rows to series rows, raw SQL, idempotent |
| `lib/features/dive_log/data/repositories/profile_series_repository.dart` | `ProfileSeriesRepository` |
| `lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart` | `TankPressureSeriesRepository` |
| `test/features/dive_log/domain/entities/profile_series_test.dart` | |
| `test/features/dive_log/domain/services/profile_sample_dedupe_test.dart` | |
| `test/core/database/migration_v182_profile_series_test.dart` | schema on upgrade and fresh; rung registered; packing on upgrade; fleet convergence |
| `test/core/database/profile_series_pack_test.dart` | the packer in isolation |
| `test/features/dive_log/data/repositories/profile_series_repository_test.dart` | |
| `test/features/dive_log/data/repositories/tank_pressure_series_repository_test.dart` | |

Modify:

| file | change |
|---|---|
| `lib/core/database/database.dart` | two table classes after `TankPressureProfiles`; registration in `@DriftDatabase(tables:)`; `currentSchemaVersion = 182`; `migrationVersions` entry; `_assertProfileSeriesSchema()`; v182 rung; backstop line |
| `lib/core/database/performance_indexes.dart` | two entries |
| `lib/core/data/repositories/sync_repository.dart` | two `hlcTargets` entries |
| `test/core/database/query_plan_test.dart` | two plan assertions |

---

### Task 1: Series entities, deterministic ids, and exact-duplicate dedupe

**Files:**
- Create: `lib/features/dive_log/domain/entities/profile_series.dart`
- Create: `lib/features/dive_log/domain/services/profile_sample_dedupe.dart`
- Test: `test/features/dive_log/domain/entities/profile_series_test.dart`
- Test: `test/features/dive_log/domain/services/profile_sample_dedupe_test.dart`

**Interfaces:**
- Consumes: `ProfileSample` (`lib/features/dive_log/domain/codecs/profile_sample.dart`), `ProfileSeriesSummary` (`.../profile_series_summary.dart`), `TankPressureSample` and `TankPressureSeriesSummary` (`.../tank_pressure_series_codec.dart`), `DiveProfilePoint` (`.../entities/dive.dart`), `package:uuid`.
- Produces:
  - `class ProfileSeries extends Equatable { id, diveId, computerId, sourceId, isPrimary, summary, samples, codecVersion, createdAt, updatedAt, hlc; List<DiveProfilePoint> get points; copyWith }`
  - `class TankPressureSeries extends Equatable { id, diveId, tankId, computerId, summary, samples, codecVersion, createdAt, updatedAt, hlc; copyWith }`
  - `const String kProfileSeriesNamespace`, `const String kTankPressureSeriesNamespace`
  - `String profileSeriesMigratedId({required String diveId, required String? computerId, required String? sourceId, required bool isPrimary})`
  - `String tankPressureSeriesMigratedId({required String diveId, required String tankId, required String? computerId})`
  - `List<ProfileSample> dedupeExactSamples(List<ProfileSample> samples)`
  - `List<TankPressureSample> dedupeExactPressureSamples(List<TankPressureSample> samples)`

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_log/domain/entities/profile_series_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_summary.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('profileSeriesMigratedId', () {
    test('is deterministic over the identity tuple', () {
      final a = profileSeriesMigratedId(
        diveId: 'd1',
        computerId: 'c1',
        sourceId: 's1',
        isPrimary: true,
      );
      final b = profileSeriesMigratedId(
        diveId: 'd1',
        computerId: 'c1',
        sourceId: 's1',
        isPrimary: true,
      );
      expect(a, b);
      expect(a, hasLength(36));
      expect(a[14], '5', reason: 'uuid v5 version nibble');
    });

    test('every tuple member changes the id', () {
      final base = profileSeriesMigratedId(
        diveId: 'd1',
        computerId: 'c1',
        sourceId: 's1',
        isPrimary: true,
      );
      expect(
        profileSeriesMigratedId(
          diveId: 'd2',
          computerId: 'c1',
          sourceId: 's1',
          isPrimary: true,
        ),
        isNot(base),
      );
      expect(
        profileSeriesMigratedId(
          diveId: 'd1',
          computerId: null,
          sourceId: 's1',
          isPrimary: true,
        ),
        isNot(base),
      );
      expect(
        profileSeriesMigratedId(
          diveId: 'd1',
          computerId: 'c1',
          sourceId: null,
          isPrimary: true,
        ),
        isNot(base),
      );
      expect(
        profileSeriesMigratedId(
          diveId: 'd1',
          computerId: 'c1',
          sourceId: 's1',
          isPrimary: false,
        ),
        isNot(base),
      );
    });

    test('absent members are spelled null in the key, per the spec', () {
      // Spec section 8: uuid v5 over `dive_id|computer_id|source_id|
      // is_primary` with the literal `null` for absent members. Pinning the
      // key format keeps every device deriving the same id.
      expect(
        profileSeriesMigratedId(
          diveId: 'd1',
          computerId: null,
          sourceId: null,
          isPrimary: true,
        ),
        const Uuid().v5(kProfileSeriesNamespace, 'd1|null|null|1'),
      );
    });
  });

  group('tankPressureSeriesMigratedId', () {
    test('is deterministic and distinct from the profile namespace', () {
      final a = tankPressureSeriesMigratedId(
        diveId: 'd1',
        tankId: 't1',
        computerId: null,
      );
      final b = tankPressureSeriesMigratedId(
        diveId: 'd1',
        tankId: 't1',
        computerId: null,
      );
      expect(a, b);
      expect(
        a,
        isNot(
          profileSeriesMigratedId(
            diveId: 'd1',
            computerId: null,
            sourceId: 't1',
            isPrimary: true,
          ),
        ),
      );
    });
  });

  group('ProfileSeries', () {
    const samples = [
      ProfileSample(timestamp: 0, depth: 0.0),
      ProfileSample(timestamp: 10, depth: 12.5, temperature: 20.0),
    ];
    final series = ProfileSeries(
      id: 'ps1',
      diveId: 'd1',
      computerId: 'c1',
      sourceId: 's1',
      isPrimary: true,
      summary: ProfileSeriesSummary.of(samples),
      samples: samples,
      codecVersion: 1,
      createdAt: 1000,
      updatedAt: 1000,
    );

    test('points converts every sample to a DiveProfilePoint', () {
      final points = series.points;
      expect(points, hasLength(2));
      expect(points[1].timestamp, 10);
      expect(points[1].depth, 12.5);
      expect(points[1].temperature, 20.0);
    });

    test('copyWith replaces only what is given', () {
      final demoted = series.copyWith(isPrimary: false, updatedAt: 2000);
      expect(demoted.isPrimary, isFalse);
      expect(demoted.updatedAt, 2000);
      expect(demoted.id, 'ps1');
      expect(demoted.samples, samples);
      expect(demoted, isNot(series));
    });

    test('copyWith can clear nullable members', () {
      final cleared = series.copyWith(clearComputerId: true, clearSourceId: true);
      expect(cleared.computerId, isNull);
      expect(cleared.sourceId, isNull);
    });
  });
}
```

Create `test/features/dive_log/domain/services/profile_sample_dedupe_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/services/profile_sample_dedupe.dart';

void main() {
  test('exact duplicates are dropped, first occurrence kept, order kept', () {
    const samples = [
      ProfileSample(timestamp: 0, depth: 1.0),
      ProfileSample(timestamp: 10, depth: 2.0, temperature: 20.0),
      ProfileSample(timestamp: 10, depth: 2.0, temperature: 20.0),
      ProfileSample(timestamp: 20, depth: 3.0),
      ProfileSample(timestamp: 0, depth: 1.0),
    ];
    expect(dedupeExactSamples(samples), [
      const ProfileSample(timestamp: 0, depth: 1.0),
      const ProfileSample(timestamp: 10, depth: 2.0, temperature: 20.0),
      const ProfileSample(timestamp: 20, depth: 3.0),
    ]);
  });

  test('samples that share a timestamp but differ are all kept', () {
    const samples = [
      ProfileSample(timestamp: 10, depth: 2.0),
      ProfileSample(timestamp: 10, depth: 2.5),
      ProfileSample(timestamp: 10, depth: 2.0, temperature: 19.0),
    ];
    expect(dedupeExactSamples(samples), samples);
  });

  test('an empty list stays empty', () {
    expect(dedupeExactSamples(const []), isEmpty);
  });

  test('pressure duplicates are dropped the same way', () {
    const samples = [
      TankPressureSample(timestamp: 0, pressure: 200.0),
      TankPressureSample(timestamp: 0, pressure: 200.0),
      TankPressureSample(timestamp: 5, pressure: 199.0),
    ];
    expect(dedupeExactPressureSamples(samples), [
      const TankPressureSample(timestamp: 0, pressure: 200.0),
      const TankPressureSample(timestamp: 5, pressure: 199.0),
    ]);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/dive_log/domain/entities/profile_series_test.dart` and `flutter test test/features/dive_log/domain/services/profile_sample_dedupe_test.dart`
Expected: compilation failures, the two new library files not found.

- [ ] **Step 3: Create the entities and identity helpers**

Create `lib/features/dive_log/domain/entities/profile_series.dart`:

```dart
import 'package:equatable/equatable.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_summary.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:uuid/uuid.dart';

/// Namespace for [profileSeriesMigratedId]. Fixed forever: changing it would
/// make two devices that migrate the same rows disagree on the series id.
const String kProfileSeriesNamespace = '7c2d9b1e-4f3a-4e8b-9c5d-2a1f6e8b3d47';

/// Namespace for [tankPressureSeriesMigratedId].
const String kTankPressureSeriesNamespace =
    'b8e1f2c3-5d6a-4b7c-8e9f-1a2b3c4d5e6f';

/// The series id the v182 migration assigns to a packed
/// (dive, computer, source, is_primary) group.
///
/// Every device runs the migration independently. A random id per device
/// would let sync union two primary series per dive, the duplicate
/// dive-types shape of issue #1360. Deriving the id from the identity tuple
/// makes devices that hold the same synced sample rows converge on upsert.
/// Only the migration uses this; repository writes mint uuid v4, because a
/// fresh download or edit genuinely is a new series.
///
/// Absent members are spelled `null` in the key (spec section 8). A member
/// that is literally the string "null" would collide with absence, and
/// cannot occur: every member is a uuid.
String profileSeriesMigratedId({
  required String diveId,
  required String? computerId,
  required String? sourceId,
  required bool isPrimary,
}) => const Uuid().v5(
  kProfileSeriesNamespace,
  '$diveId|${computerId ?? 'null'}|${sourceId ?? 'null'}|${isPrimary ? 1 : 0}',
);

/// The series id the v182 migration assigns to a packed
/// (dive, tank, computer) pressure group. See [profileSeriesMigratedId].
String tankPressureSeriesMigratedId({
  required String diveId,
  required String tankId,
  required String? computerId,
}) => const Uuid().v5(
  kTankPressureSeriesNamespace,
  '$diveId|$tankId|${computerId ?? 'null'}',
);

/// One packed profile series: the identity columns of a
/// `dive_profile_series` row, its summary scalars, and its decoded samples.
class ProfileSeries extends Equatable {
  const ProfileSeries({
    required this.id,
    required this.diveId,
    this.computerId,
    this.sourceId,
    required this.isPrimary,
    required this.summary,
    required this.samples,
    required this.codecVersion,
    required this.createdAt,
    required this.updatedAt,
    this.hlc,
  });

  final String id;
  final String diveId;
  final String? computerId;
  final String? sourceId;
  final bool isPrimary;
  final ProfileSeriesSummary summary;
  final List<ProfileSample> samples;
  final int codecVersion;
  final int createdAt;
  final int updatedAt;
  final String? hlc;

  /// The samples as the chart and analysis pipeline consume them.
  List<DiveProfilePoint> get points => [
    for (final sample in samples) sample.toPoint(),
  ];

  ProfileSeries copyWith({
    String? id,
    String? diveId,
    String? computerId,
    bool clearComputerId = false,
    String? sourceId,
    bool clearSourceId = false,
    bool? isPrimary,
    ProfileSeriesSummary? summary,
    List<ProfileSample>? samples,
    int? codecVersion,
    int? createdAt,
    int? updatedAt,
    String? hlc,
    bool clearHlc = false,
  }) {
    return ProfileSeries(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      computerId: clearComputerId ? null : (computerId ?? this.computerId),
      sourceId: clearSourceId ? null : (sourceId ?? this.sourceId),
      isPrimary: isPrimary ?? this.isPrimary,
      summary: summary ?? this.summary,
      samples: samples ?? this.samples,
      codecVersion: codecVersion ?? this.codecVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hlc: clearHlc ? null : (hlc ?? this.hlc),
    );
  }

  @override
  List<Object?> get props => [
    id,
    diveId,
    computerId,
    sourceId,
    isPrimary,
    summary,
    samples,
    codecVersion,
    createdAt,
    updatedAt,
    hlc,
  ];
}

/// One packed tank pressure series: a `tank_pressure_series` row decoded.
class TankPressureSeries extends Equatable {
  const TankPressureSeries({
    required this.id,
    required this.diveId,
    required this.tankId,
    this.computerId,
    required this.summary,
    required this.samples,
    required this.codecVersion,
    required this.createdAt,
    required this.updatedAt,
    this.hlc,
  });

  final String id;
  final String diveId;
  final String tankId;
  final String? computerId;
  final TankPressureSeriesSummary summary;
  final List<TankPressureSample> samples;
  final int codecVersion;
  final int createdAt;
  final int updatedAt;
  final String? hlc;

  TankPressureSeries copyWith({
    String? id,
    String? diveId,
    String? tankId,
    String? computerId,
    bool clearComputerId = false,
    TankPressureSeriesSummary? summary,
    List<TankPressureSample>? samples,
    int? codecVersion,
    int? createdAt,
    int? updatedAt,
    String? hlc,
    bool clearHlc = false,
  }) {
    return TankPressureSeries(
      id: id ?? this.id,
      diveId: diveId ?? this.diveId,
      tankId: tankId ?? this.tankId,
      computerId: clearComputerId ? null : (computerId ?? this.computerId),
      summary: summary ?? this.summary,
      samples: samples ?? this.samples,
      codecVersion: codecVersion ?? this.codecVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      hlc: clearHlc ? null : (hlc ?? this.hlc),
    );
  }

  @override
  List<Object?> get props => [
    id,
    diveId,
    tankId,
    computerId,
    summary,
    samples,
    codecVersion,
    createdAt,
    updatedAt,
    hlc,
  ];
}
```

Create `lib/features/dive_log/domain/services/profile_sample_dedupe.dart`:

```dart
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

/// Drops samples that repeat one already seen, comparing every field.
///
/// This is the write-side home of what `DiveRepository._dropDuplicateSamples`
/// does on every read today: a repeated import stored the same sample twice,
/// and analysis curves are index-aligned against the list, so the duplicate
/// has to go before the series is packed. Samples that share a timestamp but
/// differ in any field are all kept, in insertion order.
List<ProfileSample> dedupeExactSamples(List<ProfileSample> samples) {
  final seen = <ProfileSample>{};
  return [
    for (final sample in samples)
      if (seen.add(sample)) sample,
  ];
}

/// [dedupeExactSamples] for tank pressure readings.
List<TankPressureSample> dedupeExactPressureSamples(
  List<TankPressureSample> samples,
) {
  final seen = <TankPressureSample>{};
  return [
    for (final sample in samples)
      if (seen.add(sample)) sample,
  ];
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run both test files. Expected: 7 and 4 tests pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/domain/entities/profile_series.dart lib/features/dive_log/domain/services/profile_sample_dedupe.dart test/features/dive_log/domain/entities/profile_series_test.dart test/features/dive_log/domain/services/profile_sample_dedupe_test.dart
git commit -m "feat: ProfileSeries entities, deterministic migrated ids, exact-duplicate dedupe"
```

---

### Task 2: Series tables, v182 rung, indexes, HLC registration

**Files:**
- Modify: `lib/core/database/database.dart` (table classes after `class TankPressureProfiles`; `@DriftDatabase(tables:)` list; `currentSchemaVersion`; `migrationVersions`; a new `_assertProfileSeriesSchema()` next to `_assertTripDayWeatherSchema()`; the rung after the v180 rung; the backstop line after the v180 backstop)
- Modify: `lib/core/database/performance_indexes.dart` (after the `idx_tank_pressure_dive_tank` entry)
- Modify: `lib/core/data/repositories/sync_repository.dart` (`hlcTargets`)
- Modify: `test/core/database/query_plan_test.dart`
- Test: `test/core/database/migration_v182_profile_series_test.dart` (schema half; Task 4 adds the packing half)

**Interfaces:**
- Consumes: nothing from Task 1 (the rung's packing call is added in Task 4).
- Produces: Drift tables `DiveProfileSeries` (data class `DiveProfileSeriesRow`, companion `DiveProfileSeriesCompanion`, accessor `db.diveProfileSeries`) and `TankPressureSeries` (`TankPressureSeriesRow`, `TankPressureSeriesCompanion`, `db.tankPressureSeries`); SQL tables `dive_profile_series` and `tank_pressure_series`; indexes `idx_dive_profile_series_dive_primary` and `idx_tank_pressure_series_dive_tank`; `AppDatabase.currentSchemaVersion == 182`; `hlcTargets['diveProfileSeries']` and `hlcTargets['tankPressureSeries']`.

- [ ] **Step 1: Write the failing test (schema half)**

Create `test/core/database/migration_v182_profile_series_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:submersion/core/database/database.dart';

/// Minimal pre-v182 shape stamped at v180 so only the 182 rung runs. The FK
/// parents exist because the series tables reference them and foreign keys
/// are on once the database opens. Shared by [dbAt180] and the two-open
/// tests, which need the same DDL on a raw handle.
///
/// is_primary/imported_at/created_at on dive_data_sources are not part of
/// the series schema, but the unconditional beforeOpen self-heal
/// _backfillMissingDataSources (test/core/database/
/// backfill_missing_data_sources_test.dart) runs on every open once all of
/// dives, dive_profiles, and dive_data_sources exist, and needs them.
void legacyDdlAt180(dynamic rawDb) {
  rawDb.execute('PRAGMA user_version = 180');
  rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
  rawDb.execute('CREATE TABLE dive_computers (id TEXT NOT NULL PRIMARY KEY)');
  rawDb.execute('''
    CREATE TABLE dive_data_sources (
      id TEXT NOT NULL PRIMARY KEY,
      dive_id TEXT NOT NULL,
      computer_id TEXT,
      is_primary INTEGER NOT NULL DEFAULT 0,
      imported_at INTEGER NOT NULL,
      created_at INTEGER NOT NULL
    )
  ''');
  rawDb.execute(
    'CREATE TABLE dive_tanks (id TEXT NOT NULL PRIMARY KEY, '
    'dive_id TEXT NOT NULL)',
  );
  rawDb.execute('''
    CREATE TABLE dive_profiles (
      id TEXT NOT NULL PRIMARY KEY,
      dive_id TEXT NOT NULL,
      computer_id TEXT,
      source_id TEXT,
      is_primary INTEGER NOT NULL DEFAULT 1,
      timestamp INTEGER NOT NULL,
      depth REAL NOT NULL,
      temperature REAL,
      ndl INTEGER,
      ceiling REAL,
      deco_type INTEGER,
      heart_rate_source TEXT
    )
  ''');
  rawDb.execute('''
    CREATE TABLE tank_pressure_profiles (
      id TEXT NOT NULL PRIMARY KEY,
      dive_id TEXT NOT NULL,
      tank_id TEXT NOT NULL,
      timestamp INTEGER NOT NULL,
      pressure REAL NOT NULL,
      computer_id TEXT
    )
  ''');
}

NativeDatabase dbAt180({void Function(dynamic rawDb)? seed}) {
  return NativeDatabase.memory(
    setup: (rawDb) {
      legacyDdlAt180(rawDb);
      seed?.call(rawDb);
    },
  );
}

Future<Set<String>> tableNames(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<Set<String>> indexNames(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<Set<String>> columnsOf(AppDatabase db, String table) async {
  final cols = await db.customSelect("PRAGMA table_info('$table')").get();
  return cols.map((c) => c.read<String>('name')).toSet();
}

const profileSeriesColumns = {
  'id',
  'dive_id',
  'computer_id',
  'source_id',
  'is_primary',
  'sample_count',
  'start_timestamp',
  'end_timestamp',
  'max_depth',
  'first_depth',
  'last_depth',
  'has_deco_type',
  'has_deco_stop',
  'has_positive_ceiling',
  'codec_version',
  'samples',
  'created_at',
  'updated_at',
  'hlc',
};

const tankSeriesColumns = {
  'id',
  'dive_id',
  'tank_id',
  'computer_id',
  'sample_count',
  'start_timestamp',
  'end_timestamp',
  'codec_version',
  'samples',
  'created_at',
  'updated_at',
  'hlc',
};

void main() {
  group('schema', () {
    test('v182 creates both series tables and their indexes on upgrade', () async {
      final db = AppDatabase(dbAt180());
      addTearDown(db.close);

      final tables = await tableNames(db);
      expect(tables, containsAll(['dive_profile_series', 'tank_pressure_series']));
      expect(await columnsOf(db, 'dive_profile_series'), profileSeriesColumns);
      expect(await columnsOf(db, 'tank_pressure_series'), tankSeriesColumns);
      final indexes = await indexNames(db);
      expect(
        indexes,
        containsAll([
          'idx_dive_profile_series_dive_primary',
          'idx_tank_pressure_series_dive_tank',
        ]),
      );
      // The legacy tables survive this plan untouched.
      expect(tables, containsAll(['dive_profiles', 'tank_pressure_profiles']));
    });

    test('a fresh database has the tables with the same columns', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();

      expect(await columnsOf(db, 'dive_profile_series'), profileSeriesColumns);
      expect(await columnsOf(db, 'tank_pressure_series'), tankSeriesColumns);
      // The Drift declaration and the raw DDL must agree, or a fresh install
      // and an upgraded one would diverge.
      final driftProfile = db.diveProfileSeries.$columns
          .map((c) => c.$name)
          .toSet();
      final driftTank = db.tankPressureSeries.$columns
          .map((c) => c.$name)
          .toSet();
      expect(driftProfile, profileSeriesColumns);
      expect(driftTank, tankSeriesColumns);
    });

    test('the backstop is idempotent across a second open of one database', () async {
      // Two Drift executors over one SQLite handle: the first open runs the
      // ladder, the second runs only beforeOpen, so the backstop's IF NOT
      // EXISTS DDL genuinely executes a second time. A second query on the
      // same executor would never re-enter beforeOpen.
      final raw = sqlite3.sqlite3.openInMemory();
      addTearDown(raw.close);
      legacyDdlAt180(raw);

      final first = AppDatabase(
        NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
      );
      await first.customSelect('SELECT 1').get();
      await first.close();

      final second = AppDatabase(
        NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
      );
      addTearDown(second.close);
      await expectLater(second.customSelect('SELECT 1').get(), completes);
      expect(
        await tableNames(second),
        containsAll(['dive_profile_series', 'tank_pressure_series']),
      );
      final version = await second
          .customSelect('PRAGMA user_version')
          .getSingle();
      expect(version.data.values.first, 182);
    });

    test('v182 is present in the migration ladder', () {
      expect(AppDatabase.currentSchemaVersion, 182);
      expect(AppDatabase.migrationVersions, contains(182));
      expect(AppDatabase.minimumCompatibleSchemaVersion, 170);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/database/migration_v182_profile_series_test.dart`
Expected: compilation failure (`db.diveProfileSeries` undefined) or, before codegen, the tables missing.

- [ ] **Step 3: Declare the tables**

In `lib/core/database/database.dart`, immediately after the closing brace of `class TankPressureProfiles extends Table { ... }`, add:

```dart
/// One packed series of profile samples: every sample a
/// (dive, computer, source, is_primary) group holds, encoded by
/// `ProfileSeriesCodec` (spec 2026-08-28-profile-sample-storage). Replaces
/// row-per-sample `dive_profiles`, which stays until plan 2e retires it.
///
/// The identity columns mirror `dive_profiles` exactly so every ownership
/// predicate ports one for one. The summary scalars are the values the SQL
/// consumers read instead of decoding the blob; they are computed from the
/// same samples the blob packs, so they can never disagree with it.
@DataClassName('DiveProfileSeriesRow')
class DiveProfileSeries extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get computerId => text().nullable().references(
    DiveComputers,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get sourceId => text().nullable().references(
    DiveDataSources,
    #id,
    onDelete: KeyAction.setNull,
  )();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(true))();
  IntColumn get sampleCount => integer()();

  /// Seconds from dive start of the first and last sample.
  IntColumn get startTimestamp => integer()();
  IntColumn get endTimestamp => integer()();

  /// Metres.
  RealColumn get maxDepth => real()();
  RealColumn get firstDepth => real()();
  RealColumn get lastDepth => real()();

  /// Any sample carries deco_type; any carries deco_type = 2; any carries
  /// ceiling > 0. The deco classification and deco-signal predicates read
  /// these instead of scanning samples.
  BoolColumn get hasDecoType => boolean().withDefault(const Constant(false))();
  BoolColumn get hasDecoStop => boolean().withDefault(const Constant(false))();
  BoolColumn get hasPositiveCeiling =>
      boolean().withDefault(const Constant(false))();
  IntColumn get codecVersion => integer()();

  /// `ProfileSeriesCodec` output.
  BlobColumn get samples => blob()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}

/// One packed series of tank pressure readings for a (dive, tank, computer)
/// group, encoded by `TankPressureSeriesCodec`. Replaces row-per-sample
/// `tank_pressure_profiles`, which stays until plan 2e retires it.
@DataClassName('TankPressureSeriesRow')
class TankPressureSeries extends Table {
  // coverage:ignore-start
  TextColumn get id => text()();
  TextColumn get diveId =>
      text().references(Dives, #id, onDelete: KeyAction.cascade)();
  TextColumn get tankId =>
      text().references(DiveTanks, #id, onDelete: KeyAction.cascade)();
  TextColumn get computerId => text().nullable().references(
    DiveComputers,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get sampleCount => integer()();
  IntColumn get startTimestamp => integer()();
  IntColumn get endTimestamp => integer()();
  IntColumn get codecVersion => integer()();
  BlobColumn get samples => blob()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
  // coverage:ignore-end
}
```

In the `@DriftDatabase(tables: [...])` list, add `DiveProfileSeries,` on the line after `DiveProfiles,` and `TankPressureSeries,` on the line after `TankPressureProfiles,`.

- [ ] **Step 4: Bump the version and register the rung**

Change `static const int currentSchemaVersion = 180;` to `182`.

In `migrationVersions`, after the `180,` entry and before `];`, add:

```dart
    // v182 (packed profile series, spec 2026-08-28-profile-sample-storage):
    // dive_profile_series and tank_pressure_series, one zlib columnar blob
    // per (dive, computer, source, is_primary) group and per (dive, tank,
    // computer) group, packed from the row-per-sample tables by
    // packLegacyProfileRows with ids derived from the identity tuple so every
    // device converges (the #1360 lesson). The legacy tables stay until the
    // consumers move; the same PR retires them in a later plan. 176 remains
    // skipped; the ladder is non-contiguous by design.
    182,
```

Next to `_assertTripDayWeatherSchema()`, add:

```dart
  /// v182: the packed profile series tables.
  ///
  /// Raw idempotent DDL so it doubles as the beforeOpen backstop for a
  /// database stranded at 182 by a parallel branch. The DDL must agree with
  /// the Drift declarations column for column; the v182 migration test
  /// compares the two on a fresh database.
  Future<void> _assertProfileSeriesSchema() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS dive_profile_series (
        id TEXT NOT NULL PRIMARY KEY,
        dive_id TEXT NOT NULL REFERENCES dives (id) ON DELETE CASCADE,
        computer_id TEXT REFERENCES dive_computers (id) ON DELETE SET NULL,
        source_id TEXT REFERENCES dive_data_sources (id) ON DELETE SET NULL,
        is_primary INTEGER NOT NULL DEFAULT 1 CHECK (is_primary IN (0, 1)),
        sample_count INTEGER NOT NULL,
        start_timestamp INTEGER NOT NULL,
        end_timestamp INTEGER NOT NULL,
        max_depth REAL NOT NULL,
        first_depth REAL NOT NULL,
        last_depth REAL NOT NULL,
        has_deco_type INTEGER NOT NULL DEFAULT 0
          CHECK (has_deco_type IN (0, 1)),
        has_deco_stop INTEGER NOT NULL DEFAULT 0
          CHECK (has_deco_stop IN (0, 1)),
        has_positive_ceiling INTEGER NOT NULL DEFAULT 0
          CHECK (has_positive_ceiling IN (0, 1)),
        codec_version INTEGER NOT NULL,
        samples BLOB NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_dive_profile_series_dive_primary '
      'ON dive_profile_series (dive_id, is_primary)',
    );
    await customStatement('''
      CREATE TABLE IF NOT EXISTS tank_pressure_series (
        id TEXT NOT NULL PRIMARY KEY,
        dive_id TEXT NOT NULL REFERENCES dives (id) ON DELETE CASCADE,
        tank_id TEXT NOT NULL REFERENCES dive_tanks (id) ON DELETE CASCADE,
        computer_id TEXT REFERENCES dive_computers (id) ON DELETE SET NULL,
        sample_count INTEGER NOT NULL,
        start_timestamp INTEGER NOT NULL,
        end_timestamp INTEGER NOT NULL,
        codec_version INTEGER NOT NULL,
        samples BLOB NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        hlc TEXT
      )
    ''');
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_tank_pressure_series_dive_tank '
      'ON tank_pressure_series (dive_id, tank_id)',
    );
  }
```

In `onUpgrade`, immediately after `if (from < 180) await reportProgress();`, add:

```dart
        // v182: packed profile series tables. Idempotent DDL; the packing
        // step that fills them from the legacy tables is added by plan 2a
        // Task 4 and is idempotent too (INSERT OR IGNORE on derived ids).
        if (from < 182) {
          await _assertProfileSeriesSchema();
        }
        if (from < 182) await reportProgress();
```

In `beforeOpen`, immediately after the v180 backstop's `await _assertDiveStatsExclusionColumns();`, add:

```dart
        // v182 backstop: re-assert the packed profile series tables (same
        // parallel-branch version-collision self-heal). Schema only: packing
        // is not re-run on open.
        await _assertProfileSeriesSchema();
```

- [ ] **Step 5: Register the indexes and the HLC targets**

In `lib/core/database/performance_indexes.dart`, after the `idx_tank_pressure_dive_tank` entry, add:

```dart
  (
    name: 'idx_dive_profile_series_dive_primary',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_dive_profile_series_dive_primary '
        'ON dive_profile_series (dive_id, is_primary)',
  ),
  (
    name: 'idx_tank_pressure_series_dive_tank',
    ddl:
        'CREATE INDEX IF NOT EXISTS idx_tank_pressure_series_dive_tank '
        'ON tank_pressure_series (dive_id, tank_id)',
  ),
```

In `lib/core/data/repositories/sync_repository.dart`, inside `hlcTargets`, after the `'tripDayWeather'` entry, add:

```dart
    'diveProfileSeries': (table: 'dive_profile_series', pk: 'id'),
    'tankPressureSeries': (table: 'tank_pressure_series', pk: 'id'),
```

In `test/core/database/query_plan_test.dart`, after the `per-dive pressure fetch` test, add:

```dart
  test('per-dive series fetch uses idx_dive_profile_series_dive_primary', () async {
    final p = await plan(
      db,
      "SELECT * FROM dive_profile_series WHERE dive_id = 'x' AND is_primary = 1",
    );
    expect(p, contains('idx_dive_profile_series_dive_primary'));
  });

  test('per-tank series fetch uses idx_tank_pressure_series_dive_tank', () async {
    final p = await plan(
      db,
      "SELECT * FROM tank_pressure_series WHERE dive_id = 'x' AND tank_id = 't'",
    );
    expect(p, contains('idx_tank_pressure_series_dive_tank'));
  });
```

- [ ] **Step 6: Regenerate and run the tests**

```bash
dart run build_runner build
flutter test test/core/database/migration_v182_profile_series_test.dart
flutter test test/core/database/query_plan_test.dart
flutter test test/core/database/performance_indexes_test.dart
flutter test test/core/services/sync/sync_hlc_target_registration_test.dart
flutter test test/core/database/migration_v180_stats_exclusion_test.dart
```

Expected: all pass. If the fresh-database column comparison fails, the raw DDL and the Drift class disagree on a column name; fix the DDL, never the Drift class. If `performance_indexes_test` fails on a fresh database, the index DDL references a column name that differs from the table DDL.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/database/database.dart lib/core/database/performance_indexes.dart lib/core/data/repositories/sync_repository.dart test/core/database/query_plan_test.dart test/core/database/migration_v182_profile_series_test.dart
git commit -m "feat(db): dive_profile_series and tank_pressure_series tables at schema v182"
```

Do not add `database.g.dart`; it is generated and gitignored.

---

### Task 3: The packer

**Files:**
- Create: `lib/core/database/profile_series_pack.dart`
- Test: `test/core/database/profile_series_pack_test.dart`

**Interfaces:**
- Consumes: `ProfileSeriesCodec`, `ProfileSample`, `TankPressureSeriesCodec`, `TankPressureSample` (PR 1); `profileSeriesMigratedId`, `tankPressureSeriesMigratedId`, `dedupeExactSamples`, `dedupeExactPressureSamples` (Task 1); `Hlc` (`lib/core/services/sync/hlc.dart`); tables from Task 2.
- Produces: `typedef ProfilePackReport = ({int profileSeries, int tankSeries, int droppedSamples});` and `Future<ProfilePackReport> packLegacyProfileRows(DatabaseConnectionUser db, {int? nowMs})`.

- [ ] **Step 1: Write the failing test**

Create `test/core/database/profile_series_pack_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/profile_series_pack.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';

/// A database already at v182 (no ladder runs) with the legacy tables and
/// the FK parents the series tables reference. `beforeOpen` creates the
/// series tables through the backstop.
NativeDatabase legacyFixture({void Function(dynamic rawDb)? seed}) {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 182');
      rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
      rawDb.execute(
        'CREATE TABLE dive_computers (id TEXT NOT NULL PRIMARY KEY)',
      );
      // is_primary/imported_at/created_at are not part of what the packer
      // reads, but the unconditional beforeOpen self-heal
      // _backfillMissingDataSources runs once dives, dive_profiles, and
      // dive_data_sources all exist and inserts rows naming those columns.
      // It never touches dive_profiles.source_id, so the packer's
      // expectations below are unaffected.
      rawDb.execute('''
        CREATE TABLE dive_data_sources (
          id TEXT NOT NULL PRIMARY KEY,
          dive_id TEXT NOT NULL,
          computer_id TEXT,
          is_primary INTEGER NOT NULL DEFAULT 0,
          imported_at INTEGER NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');
      rawDb.execute(
        'CREATE TABLE dive_tanks (id TEXT NOT NULL PRIMARY KEY, '
        'dive_id TEXT NOT NULL)',
      );
      rawDb.execute('''
        CREATE TABLE dive_profiles (
          id TEXT NOT NULL PRIMARY KEY,
          dive_id TEXT NOT NULL,
          computer_id TEXT,
          source_id TEXT,
          is_primary INTEGER NOT NULL DEFAULT 1,
          timestamp INTEGER NOT NULL,
          depth REAL NOT NULL,
          temperature REAL,
          ndl INTEGER,
          ceiling REAL,
          deco_type INTEGER,
          heart_rate_source TEXT
        )
      ''');
      rawDb.execute('''
        CREATE TABLE tank_pressure_profiles (
          id TEXT NOT NULL PRIMARY KEY,
          dive_id TEXT NOT NULL,
          tank_id TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          pressure REAL NOT NULL,
          computer_id TEXT
        )
      ''');
      seed?.call(rawDb);
    },
  );
}

void seedParents(dynamic rawDb) {
  rawDb.execute("INSERT INTO dives (id) VALUES ('d1'), ('d2')");
  rawDb.execute("INSERT INTO dive_computers (id) VALUES ('c1'), ('c2')");
  rawDb.execute(
    "INSERT INTO dive_data_sources (id, dive_id, computer_id, imported_at, "
    "created_at) VALUES ('s1', 'd1', 'c1', 0, 0), ('s2', 'd1', 'c2', 0, 0)",
  );
  rawDb.execute(
    "INSERT INTO dive_tanks (id, dive_id) VALUES ('t1', 'd1'), ('t2', 'd1')",
  );
}

/// dive d1: computer c1 / source s1, primary, 3 samples with the second
/// duplicated exactly and a third row at the same timestamp that differs;
/// computer c2 / source s2, non-primary, 2 samples (a multi-source dive);
/// a manual edit (null computer, source s1, primary), 2 samples.
/// dive d2: legacy rows with null computer and null source, 2 samples.
void seedProfiles(dynamic rawDb) {
  void row(
    String id,
    String dive,
    String? computer,
    String? source,
    int primary,
    int ts,
    double depth, {
    double? temp,
    int? ndl,
    double? ceiling,
    int? decoType,
    String? hrs,
  }) {
    rawDb.execute(
      'INSERT INTO dive_profiles (id, dive_id, computer_id, source_id, '
      'is_primary, timestamp, depth, temperature, ndl, ceiling, deco_type, '
      'heart_rate_source) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [id, dive, computer, source, primary, ts, depth, temp, ndl, ceiling, decoType, hrs],
    );
  }

  row('p1', 'd1', 'c1', 's1', 1, 0, 0.0, temp: 20.0, ndl: 3000);
  row('p2', 'd1', 'c1', 's1', 1, 10, 12.5, temp: 19.5, ndl: 2900);
  row('p3', 'd1', 'c1', 's1', 1, 10, 12.5, temp: 19.5, ndl: 2900);
  row('p4', 'd1', 'c1', 's1', 1, 10, 12.7, temp: 19.5, ndl: 2900);
  row('p5', 'd1', 'c1', 's1', 1, 20, 18.0, ceiling: 3.0, decoType: 2);
  row('p6', 'd1', 'c2', 's2', 0, 0, 0.0);
  row('p7', 'd1', 'c2', 's2', 0, 10, 12.4);
  row('p8', 'd1', null, 's1', 1, 0, 0.0, hrs: 'appleWatch');
  row('p9', 'd1', null, 's1', 1, 10, 12.0, hrs: 'appleWatch');
  row('p10', 'd2', null, null, 1, 0, 0.0);
  row('p11', 'd2', null, null, 1, 30, 9.0);
}

void seedPressures(dynamic rawDb) {
  void row(String id, String tank, String? computer, int ts, double bar) {
    rawDb.execute(
      'INSERT INTO tank_pressure_profiles (id, dive_id, tank_id, timestamp, '
      'pressure, computer_id) VALUES (?, ?, ?, ?, ?, ?)',
      [id, 'd1', tank, ts, bar, computer],
    );
  }

  row('q1', 't1', 'c1', 0, 200.0);
  row('q2', 't1', 'c1', 0, 200.0);
  row('q3', 't1', 'c1', 60, 190.0);
  row('q4', 't2', null, 0, 210.0);
}

Future<List<Map<String, Object?>>> rows(AppDatabase db, String sql) async {
  final result = await db.customSelect(sql).get();
  return result.map((r) => r.data).toList();
}

void main() {
  const codec = ProfileSeriesCodec();
  const tankCodec = TankPressureSeriesCodec();

  test('packs each identity group into one series with derived ids', () async {
    final db = AppDatabase(
      legacyFixture(
        seed: (raw) {
          seedParents(raw);
          seedProfiles(raw);
          seedPressures(raw);
        },
      ),
    );
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    final report = await packLegacyProfileRows(db, nowMs: 1700000000000);
    expect(report.profileSeries, 4);
    expect(report.tankSeries, 2);
    expect(report.droppedSamples, 2, reason: 'p3 and q2 are exact duplicates');

    final series = await rows(
      db,
      'SELECT * FROM dive_profile_series ORDER BY dive_id, computer_id, '
      'source_id, is_primary',
    );
    expect(series, hasLength(4));

    final c1 = series.singleWhere(
      (r) => r['computer_id'] == 'c1' && r['dive_id'] == 'd1',
    );
    expect(
      c1['id'],
      profileSeriesMigratedId(
        diveId: 'd1',
        computerId: 'c1',
        sourceId: 's1',
        isPrimary: true,
      ),
    );
    expect(c1['is_primary'], 1);
    expect(c1['sample_count'], 4);
    expect(c1['start_timestamp'], 0);
    expect(c1['end_timestamp'], 20);
    expect(c1['max_depth'], 18.0);
    expect(c1['first_depth'], 0.0);
    expect(c1['last_depth'], 18.0);
    expect(c1['has_deco_type'], 1);
    expect(c1['has_deco_stop'], 1);
    expect(c1['has_positive_ceiling'], 1);
    expect(c1['codec_version'], 1);
    expect(c1['created_at'], 1700000000000);
    expect(c1['updated_at'], 1700000000000);
    final decoded = codec.decode(c1['samples'] as dynamic);
    expect(decoded, [
      const ProfileSample(timestamp: 0, depth: 0.0, temperature: 20.0, ndl: 3000),
      const ProfileSample(timestamp: 10, depth: 12.5, temperature: 19.5, ndl: 2900),
      const ProfileSample(timestamp: 10, depth: 12.7, temperature: 19.5, ndl: 2900),
      const ProfileSample(timestamp: 20, depth: 18.0, ceiling: 3.0, decoType: 2),
    ]);

    final edit = series.singleWhere(
      (r) => r['computer_id'] == null && r['dive_id'] == 'd1',
    );
    expect(edit['source_id'], 's1');
    expect(edit['is_primary'], 1);
    expect(
      codec.decode(edit['samples'] as dynamic).map((s) => s.heartRateSource),
      ['appleWatch', 'appleWatch'],
    );

    final legacy = series.singleWhere((r) => r['dive_id'] == 'd2');
    expect(legacy['computer_id'], isNull);
    expect(legacy['source_id'], isNull);
    expect(
      legacy['id'],
      profileSeriesMigratedId(
        diveId: 'd2',
        computerId: null,
        sourceId: null,
        isPrimary: true,
      ),
    );

    final tanks = await rows(
      db,
      'SELECT * FROM tank_pressure_series ORDER BY tank_id',
    );
    expect(tanks, hasLength(2));
    expect(
      tanks[0]['id'],
      tankPressureSeriesMigratedId(diveId: 'd1', tankId: 't1', computerId: 'c1'),
    );
    expect(tanks[0]['sample_count'], 2);
    expect(tankCodec.decode(tanks[0]['samples'] as dynamic), [
      const TankPressureSample(timestamp: 0, pressure: 200.0),
      const TankPressureSample(timestamp: 60, pressure: 190.0),
    ]);
    expect(tanks[1]['computer_id'], isNull);
  });

  test('re-running the packer inserts nothing new', () async {
    final db = AppDatabase(
      legacyFixture(
        seed: (raw) {
          seedParents(raw);
          seedProfiles(raw);
          seedPressures(raw);
        },
      ),
    );
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    await packLegacyProfileRows(db, nowMs: 1);
    final again = await packLegacyProfileRows(db, nowMs: 2);
    expect(again.profileSeries, 0);
    expect(again.tankSeries, 0);
    final count = await db
        .customSelect('SELECT COUNT(*) AS n FROM dive_profile_series')
        .getSingle();
    expect(count.read<int>('n'), 4);
  });

  test('two independently packed copies produce identical series ids', () async {
    Future<Set<String>> idsOf() async {
      final db = AppDatabase(
        legacyFixture(
          seed: (raw) {
            seedParents(raw);
            seedProfiles(raw);
            seedPressures(raw);
          },
        ),
      );
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();
      await packLegacyProfileRows(db, nowMs: 5);
      final a = await rows(db, 'SELECT id FROM dive_profile_series');
      final b = await rows(db, 'SELECT id FROM tank_pressure_series');
      return {for (final r in [...a, ...b]) r['id'] as String};
    }

    expect(await idsOf(), await idsOf());
  });

  test('stamps the migration hlc from sync_metadata when a device id exists', () async {
    final db = AppDatabase(
      legacyFixture(
        seed: (raw) {
          seedParents(raw);
          seedProfiles(raw);
          // A fixture stamped at 182 never runs onCreate, so the table a
          // synced device would have is created here with its global row.
          raw.execute(
            'CREATE TABLE sync_metadata (id TEXT NOT NULL PRIMARY KEY, '
            'device_id TEXT NOT NULL, created_at INTEGER NOT NULL, '
            'updated_at INTEGER NOT NULL)',
          );
          raw.execute(
            "INSERT INTO sync_metadata (id, device_id, created_at, updated_at) "
            "VALUES ('global', 'dev-1', 0, 0)",
          );
        },
      ),
    );
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    await packLegacyProfileRows(db, nowMs: 1700000000000);
    final row = await db
        .customSelect('SELECT hlc FROM dive_profile_series LIMIT 1')
        .getSingle();
    expect(
      row.read<String>('hlc'),
      const Hlc(1700000000000, 0, 'dev-1').toString(),
    );
  });

  test('leaves hlc null when the device has never synced', () async {
    final db = AppDatabase(
      legacyFixture(
        seed: (raw) {
          seedParents(raw);
          seedProfiles(raw);
        },
      ),
    );
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    await packLegacyProfileRows(db, nowMs: 1);
    final row = await db
        .customSelect('SELECT hlc FROM dive_profile_series LIMIT 1')
        .getSingle();
    expect(row.readNullable<String>('hlc'), isNull);
  });

  test('no-ops when the legacy tables are absent', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA user_version = 182'),
      ),
    );
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    final report = await packLegacyProfileRows(db, nowMs: 1);
    expect(report.profileSeries, 0);
    expect(report.tankSeries, 0);
    expect(report.droppedSamples, 0);
  });

  test('tolerates legacy tables that lack optional sample columns', () async {
    // A minimal fixture like the older migration tests: the identity columns
    // and the two required sample columns only. The identity columns are
    // always present by the time the v182 rung runs (earlier rungs add
    // source_id first, and rungs run in order), so the packer may name them
    // in ORDER BY; every optional sample column is absent here and must
    // decode as null.
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute('PRAGMA user_version = 182');
          raw.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
          raw.execute("INSERT INTO dives (id) VALUES ('d1')");
          // Under PRAGMA foreign_keys = ON (set by beforeOpen) SQLite resolves
          // an INSERT's foreign keys when the statement is prepared, so the
          // series tables' parents must exist even when no row references
          // them; dive_data_sources carries the columns the beforeOpen
          // self-heal _backfillMissingDataSources writes.
          raw.execute(
            'CREATE TABLE dive_computers (id TEXT NOT NULL PRIMARY KEY)',
          );
          raw.execute('''
            CREATE TABLE dive_data_sources (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL,
              computer_id TEXT,
              is_primary INTEGER NOT NULL DEFAULT 0,
              imported_at INTEGER NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          raw.execute(
            'CREATE TABLE dive_profiles (id TEXT NOT NULL PRIMARY KEY, '
            'dive_id TEXT NOT NULL, computer_id TEXT, source_id TEXT, '
            'is_primary INTEGER NOT NULL DEFAULT 1, '
            'timestamp INTEGER NOT NULL, depth REAL NOT NULL)',
          );
          raw.execute(
            "INSERT INTO dive_profiles (id, dive_id, timestamp, depth) "
            "VALUES ('p1', 'd1', 0, 0), ('p2', 'd1', 5, 4)",
          );
        },
      ),
    );
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    final report = await packLegacyProfileRows(db, nowMs: 1);
    expect(report.profileSeries, 1);
    final row = await db
        .customSelect('SELECT samples FROM dive_profile_series')
        .getSingle();
    expect(codec.decode(row.read('samples')), [
      const ProfileSample(timestamp: 0, depth: 0.0),
      const ProfileSample(timestamp: 5, depth: 4.0),
    ]);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/database/profile_series_pack_test.dart`
Expected: compilation failure, `profile_series_pack.dart` not found.

- [ ] **Step 3: Create the packer**

Create `lib/core/database/profile_series_pack.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';
import 'package:submersion/features/dive_log/domain/services/profile_sample_dedupe.dart';

/// What one packing pass inserted and dropped.
typedef ProfilePackReport = ({
  int profileSeries,
  int tankSeries,
  int droppedSamples,
});

/// Packs every legacy `dive_profiles` and `tank_pressure_profiles` row into
/// the series tables (v182, spec 2026-08-28-profile-sample-storage).
///
/// Raw SQL throughout, never the legacy Drift classes: plan 2e removes those
/// classes and drops the tables, and this function must keep compiling and
/// keep no-oping on a database that has already lost them.
///
/// Memory is bounded by one dive's rows, never the table. Each identity
/// group becomes one row whose id is derived from the tuple
/// ([profileSeriesMigratedId]), so a second run, a retry after a failed
/// ladder, or a second device migrating the same synced rows all converge:
/// the insert is `INSERT OR IGNORE`.
///
/// Exact duplicate samples (a repeated import) are dropped before packing,
/// which is what every read did on the way out until now.
///
/// [nowMs] stamps `created_at` and `updated_at`. `hlc` is minted from the
/// device id in `sync_metadata` when one exists, so the first sync after the
/// upgrade publishes the rows; a device that never synced has nothing to
/// publish to and its rows stay unstamped until a base publish, which
/// exports everything regardless.
Future<ProfilePackReport> packLegacyProfileRows(
  DatabaseConnectionUser db, {
  int? nowMs,
}) async {
  final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
  final hlc = await _migrationHlc(db, now);
  var profileSeries = 0;
  var tankSeries = 0;
  var dropped = 0;

  if (await _tableExists(db, 'dive_profiles')) {
    const codec = ProfileSeriesCodec();
    for (final diveId in await _diveIds(db, 'dive_profiles')) {
      final rows = await db
          .customSelect(
            'SELECT * FROM dive_profiles WHERE dive_id = ? '
            'ORDER BY computer_id, source_id, is_primary, timestamp, rowid',
            variables: [Variable<String>(diveId)],
          )
          .get();
      final groups = <_ProfileKey, List<ProfileSample>>{};
      for (final row in rows) {
        final key = _ProfileKey(
          computerId: row.data['computer_id'] as String?,
          sourceId: row.data['source_id'] as String?,
          isPrimary: _boolOf(row.data['is_primary'], fallback: true),
        );
        groups.putIfAbsent(key, () => []).add(_profileSampleOf(row.data));
      }
      for (final entry in groups.entries) {
        final key = entry.key;
        final samples = dedupeExactSamples(entry.value);
        dropped += entry.value.length - samples.length;
        final encoded = codec.encode(samples);
        final summary = encoded.summary;
        final inserted = await db.customUpdate(
          'INSERT OR IGNORE INTO dive_profile_series ('
          'id, dive_id, computer_id, source_id, is_primary, sample_count, '
          'start_timestamp, end_timestamp, max_depth, first_depth, last_depth, '
          'has_deco_type, has_deco_stop, has_positive_ceiling, codec_version, '
          'samples, created_at, updated_at, hlc) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          variables: [
            Variable<String>(
              profileSeriesMigratedId(
                diveId: diveId,
                computerId: key.computerId,
                sourceId: key.sourceId,
                isPrimary: key.isPrimary,
              ),
            ),
            Variable<String>(diveId),
            Variable<String>(key.computerId),
            Variable<String>(key.sourceId),
            Variable<int>(key.isPrimary ? 1 : 0),
            Variable<int>(summary.sampleCount),
            Variable<int>(summary.startTimestamp),
            Variable<int>(summary.endTimestamp),
            Variable<double>(summary.maxDepth),
            Variable<double>(summary.firstDepth),
            Variable<double>(summary.lastDepth),
            Variable<int>(summary.hasDecoType ? 1 : 0),
            Variable<int>(summary.hasDecoStop ? 1 : 0),
            Variable<int>(summary.hasPositiveCeiling ? 1 : 0),
            Variable<int>(encoded.codecVersion),
            Variable<Uint8List>(encoded.bytes),
            Variable<int>(now),
            Variable<int>(now),
            Variable<String>(hlc),
          ],
          updateKind: UpdateKind.insert,
        );
        profileSeries += inserted;
      }
    }
  }

  if (await _tableExists(db, 'tank_pressure_profiles')) {
    const codec = TankPressureSeriesCodec();
    for (final diveId in await _diveIds(db, 'tank_pressure_profiles')) {
      final rows = await db
          .customSelect(
            'SELECT * FROM tank_pressure_profiles WHERE dive_id = ? '
            'ORDER BY tank_id, computer_id, timestamp, rowid',
            variables: [Variable<String>(diveId)],
          )
          .get();
      final groups = <_TankKey, List<TankPressureSample>>{};
      for (final row in rows) {
        final key = _TankKey(
          tankId: row.data['tank_id'] as String,
          computerId: row.data['computer_id'] as String?,
        );
        groups
            .putIfAbsent(key, () => [])
            .add(
              TankPressureSample(
                timestamp: (row.data['timestamp'] as num).toInt(),
                pressure: (row.data['pressure'] as num).toDouble(),
              ),
            );
      }
      for (final entry in groups.entries) {
        final key = entry.key;
        final samples = dedupeExactPressureSamples(entry.value);
        dropped += entry.value.length - samples.length;
        final encoded = codec.encode(samples);
        final inserted = await db.customUpdate(
          'INSERT OR IGNORE INTO tank_pressure_series ('
          'id, dive_id, tank_id, computer_id, sample_count, start_timestamp, '
          'end_timestamp, codec_version, samples, created_at, updated_at, hlc) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          variables: [
            Variable<String>(
              tankPressureSeriesMigratedId(
                diveId: diveId,
                tankId: key.tankId,
                computerId: key.computerId,
              ),
            ),
            Variable<String>(diveId),
            Variable<String>(key.tankId),
            Variable<String>(key.computerId),
            Variable<int>(encoded.summary.sampleCount),
            Variable<int>(encoded.summary.startTimestamp),
            Variable<int>(encoded.summary.endTimestamp),
            Variable<int>(encoded.codecVersion),
            Variable<Uint8List>(encoded.bytes),
            Variable<int>(now),
            Variable<int>(now),
            Variable<String>(hlc),
          ],
          updateKind: UpdateKind.insert,
        );
        tankSeries += inserted;
      }
    }
  }

  return (
    profileSeries: profileSeries,
    tankSeries: tankSeries,
    droppedSamples: dropped,
  );
}

class _ProfileKey {
  const _ProfileKey({
    required this.computerId,
    required this.sourceId,
    required this.isPrimary,
  });

  final String? computerId;
  final String? sourceId;
  final bool isPrimary;

  @override
  bool operator ==(Object other) =>
      other is _ProfileKey &&
      other.computerId == computerId &&
      other.sourceId == sourceId &&
      other.isPrimary == isPrimary;

  @override
  int get hashCode => Object.hash(computerId, sourceId, isPrimary);
}

class _TankKey {
  const _TankKey({required this.tankId, required this.computerId});

  final String tankId;
  final String? computerId;

  @override
  bool operator ==(Object other) =>
      other is _TankKey &&
      other.tankId == tankId &&
      other.computerId == computerId;

  @override
  int get hashCode => Object.hash(tankId, computerId);
}

Future<bool> _tableExists(DatabaseConnectionUser db, String table) async {
  final rows = await db
      .customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
        variables: [Variable<String>(table)],
      )
      .get();
  return rows.isNotEmpty;
}

Future<List<String>> _diveIds(DatabaseConnectionUser db, String table) async {
  final rows = await db
      .customSelect('SELECT DISTINCT dive_id FROM $table ORDER BY dive_id')
      .get();
  return [for (final row in rows) row.read<String>('dive_id')];
}

/// The clock value migrated rows carry. Null when this device has never
/// synced: there is no device id to stamp with, and nothing to publish to.
Future<String?> _migrationHlc(DatabaseConnectionUser db, int nowMs) async {
  if (!await _tableExists(db, 'sync_metadata')) return null;
  final rows = await db
      .customSelect(
        "SELECT device_id FROM sync_metadata WHERE id = 'global' LIMIT 1",
      )
      .get();
  if (rows.isEmpty) return null;
  final deviceId = rows.first.readNullable<String>('device_id');
  if (deviceId == null || deviceId.isEmpty) return null;
  return Hlc(nowMs, 0, deviceId).toString();
}

bool _boolOf(Object? value, {required bool fallback}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  return fallback;
}

double? _realOf(Object? value) => (value as num?)?.toDouble();

int? _intOf(Object? value) => (value as num?)?.toInt();

/// Reads a legacy `dive_profiles` row by column name. Absent columns (an
/// older fixture or a partially migrated table) read as null.
ProfileSample _profileSampleOf(Map<String, Object?> data) {
  return ProfileSample(
    timestamp: (data['timestamp'] as num).toInt(),
    depth: (data['depth'] as num).toDouble(),
    pressure: _realOf(data['pressure']),
    temperature: _realOf(data['temperature']),
    heartRate: _intOf(data['heart_rate']),
    ascentRate: _realOf(data['ascent_rate']),
    ceiling: _realOf(data['ceiling']),
    ndl: _intOf(data['ndl']),
    setpoint: _realOf(data['setpoint']),
    ppO2: _realOf(data['pp_o2']),
    o2Sensor1: _realOf(data['o2_sensor1']),
    o2Sensor2: _realOf(data['o2_sensor2']),
    o2Sensor3: _realOf(data['o2_sensor3']),
    o2Sensor4: _realOf(data['o2_sensor4']),
    o2Sensor5: _realOf(data['o2_sensor5']),
    o2Sensor6: _realOf(data['o2_sensor6']),
    cns: _realOf(data['cns']),
    tts: _intOf(data['tts']),
    rbt: _intOf(data['rbt']),
    decoType: _intOf(data['deco_type']),
    heartRateSource: data['heart_rate_source'] as String?,
    heading: _realOf(data['heading']),
    o2SensorMv1: _intOf(data['o2_sensor_mv1']),
    o2SensorMv2: _intOf(data['o2_sensor_mv2']),
    o2SensorMv3: _intOf(data['o2_sensor_mv3']),
    o2SensorMv4: _intOf(data['o2_sensor_mv4']),
    o2SensorMv5: _intOf(data['o2_sensor_mv5']),
    o2SensorMv6: _intOf(data['o2_sensor_mv6']),
  );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/database/profile_series_pack_test.dart`
Expected: 7 tests pass. If `customUpdate` complains that `updates` is required, pass `updates: const {}` in addition to `updateKind`. If the `samples` column comes back as a `List<int>` rather than `Uint8List` in the test's raw row map, wrap it with `Uint8List.fromList` in the test helper rather than changing the packer.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/database/profile_series_pack.dart test/core/database/profile_series_pack_test.dart
git commit -m "feat(db): packLegacyProfileRows, legacy sample rows to packed series"
```

---

### Task 4: Wire the packer into the v182 rung

**Files:**
- Modify: `lib/core/database/database.dart` (the v182 rung; the import)
- Test: `test/core/database/migration_v182_profile_series_test.dart` (packing half)

**Interfaces:**
- Consumes: `packLegacyProfileRows` (Task 3).
- Produces: a v182 upgrade that leaves every legacy row packed.

- [ ] **Step 1: Write the failing tests**

Append a second group to `test/core/database/migration_v182_profile_series_test.dart`, inside `main()` after the `schema` group:

```dart
  group('packing on upgrade', () {
    void seed(dynamic rawDb) {
      rawDb.execute("INSERT INTO dives (id) VALUES ('d1')");
      rawDb.execute("INSERT INTO dive_computers (id) VALUES ('c1')");
      rawDb.execute(
        "INSERT INTO dive_data_sources (id, dive_id, computer_id, "
        "imported_at, created_at) VALUES ('s1', 'd1', 'c1', 0, 0)",
      );
      rawDb.execute("INSERT INTO dive_tanks (id, dive_id) VALUES ('t1', 'd1')");
      rawDb.execute(
        "INSERT INTO dive_profiles (id, dive_id, computer_id, source_id, "
        "is_primary, timestamp, depth) VALUES "
        "('p1', 'd1', 'c1', 's1', 1, 0, 0.0), "
        "('p2', 'd1', 'c1', 's1', 1, 10, 15.0), "
        "('p3', 'd1', 'c1', 's1', 1, 10, 15.0)",
      );
      rawDb.execute(
        "INSERT INTO tank_pressure_profiles (id, dive_id, tank_id, timestamp, "
        "pressure, computer_id) VALUES ('q1', 'd1', 't1', 0, 200.0, 'c1')",
      );
    }

    test('upgrading from 180 packs the legacy rows', () async {
      final db = AppDatabase(dbAt180(seed: seed));
      addTearDown(db.close);
      await db.customSelect('SELECT 1').get();

      final series = await db
          .customSelect('SELECT * FROM dive_profile_series')
          .get();
      expect(series, hasLength(1));
      expect(series.single.read<int>('sample_count'), 2);
      expect(series.single.read<double>('max_depth'), 15.0);
      final tanks = await db
          .customSelect('SELECT * FROM tank_pressure_series')
          .get();
      expect(tanks, hasLength(1));
      expect(tanks.single.read<String>('tank_id'), 't1');
      // Legacy rows are untouched in this plan.
      final legacy = await db
          .customSelect('SELECT COUNT(*) AS n FROM dive_profiles')
          .getSingle();
      expect(legacy.read<int>('n'), 3);
    });

    test('two devices upgrading the same rows converge on the same ids', () async {
      Future<List<String>> idsAfterUpgrade() async {
        final db = AppDatabase(dbAt180(seed: seed));
        addTearDown(db.close);
        await db.customSelect('SELECT 1').get();
        final a = await db
            .customSelect('SELECT id FROM dive_profile_series ORDER BY id')
            .get();
        final b = await db
            .customSelect('SELECT id FROM tank_pressure_series ORDER BY id')
            .get();
        return [for (final r in [...a, ...b]) r.read<String>('id')];
      }

      expect(await idsAfterUpgrade(), await idsAfterUpgrade());
    });

    test('a database already at 182 is not packed again on open', () async {
      // Two executors over one handle (see the schema group): the first
      // open runs the ladder and packs; a legacy row written afterwards must
      // survive the second open unpacked, because the backstop is schema
      // only.
      final raw = sqlite3.sqlite3.openInMemory();
      addTearDown(raw.close);
      legacyDdlAt180(raw);
      seed(raw);

      final first = AppDatabase(
        NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
      );
      await first.customSelect('SELECT 1').get();
      await first.close();

      raw.execute(
        "INSERT INTO dive_profiles (id, dive_id, computer_id, source_id, "
        "is_primary, timestamp, depth) VALUES ('p9', 'd1', NULL, NULL, 1, 0, 1.0)",
      );

      final second = AppDatabase(
        NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
      );
      addTearDown(second.close);
      await second.customSelect('SELECT 1').get();
      final series = await second
          .customSelect('SELECT COUNT(*) AS n FROM dive_profile_series')
          .getSingle();
      expect(series.read<int>('n'), 1);
    });
  });
```

- [ ] **Step 2: Run the test to verify the new group fails**

Run: `flutter test test/core/database/migration_v182_profile_series_test.dart`
Expected: the `packing on upgrade` tests fail (zero series rows); the `schema` group still passes.

- [ ] **Step 3: Call the packer from the rung**

In `lib/core/database/database.dart`, add the import next to the other `package:submersion/core/database/...` imports:

```dart
import 'package:submersion/core/database/profile_series_pack.dart';
```

Change the v182 rung to:

```dart
        // v182: packed profile series tables, then pack every legacy
        // row-per-sample row into them. Both steps are idempotent (IF NOT
        // EXISTS DDL; INSERT OR IGNORE on ids derived from the identity
        // tuple), so a retry after a failed ladder, or a collision re-run,
        // is safe. The legacy tables stay until plan 2e retires them.
        if (from < 182) {
          await _assertProfileSeriesSchema();
          await packLegacyProfileRows(this);
        }
        if (from < 182) await reportProgress();
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
flutter test test/core/database/migration_v182_profile_series_test.dart
flutter test test/core/database/profile_series_pack_test.dart
```

Expected: all pass (7 in the migration file, 7 in the packer file).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/core/database/database.dart test/core/database/migration_v182_profile_series_test.dart
git commit -m "feat(db): v182 packs legacy profile and pressure rows into series"
```

---

### Task 5: ProfileSeriesRepository

**Files:**
- Create: `lib/features/dive_log/data/repositories/profile_series_repository.dart`
- Test: `test/features/dive_log/data/repositories/profile_series_repository_test.dart`

**Interfaces:**
- Consumes: `db.diveProfileSeries`, `DiveProfileSeriesCompanion`, `DiveProfileSeriesRow` (Task 2); `ProfileSeries`, `dedupeExactSamples` (Task 1); codec and summary (PR 1); `SyncRepository.markRecordPending` / `logDeletion`; `SyncEventBus.notifyLocalChange`.
- Produces:
  - `class ProfileSeriesRepository { ProfileSeriesRepository({SyncRepository? syncRepository}); static const String entityType = 'diveProfileSeries'; }`
  - `Future<String> insertSeries({required String diveId, String? computerId, String? sourceId, bool isPrimary = true, required List<ProfileSample> samples, String? id, int? now})`
  - `Future<List<ProfileSeries>> getSeriesForDive(String diveId, {bool primaryOnly = false})`
  - `Future<ProfileSeries?> getSeriesById(String id)`
  - `Future<int> demoteAll(String diveId, {int? now})`
  - `Future<int> promoteOwnedBy(String diveId, {required String? sourceId, required String? computerId, int? now})`
  - `Future<List<String>> deleteOwnedBy(String diveId, {required String? sourceId, required String? computerId})`
  - `Future<List<String>> deleteForDive(String diveId)`
  - Plan 2b calls these from every write site.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/data/repositories/profile_series_repository_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProfileSeriesRepository repo;
  const now = 1750000000000;

  const samples = [
    ProfileSample(timestamp: 0, depth: 0.0),
    ProfileSample(timestamp: 10, depth: 12.0, temperature: 21.0, ndl: 2000),
    ProfileSample(timestamp: 20, depth: 18.5, ceiling: 3.0, decoType: 2),
    ProfileSample(timestamp: 30, depth: 5.0),
  ];

  setUp(() async {
    db = await setUpTestDatabase();
    repo = ProfileSeriesRepository();
    await db
        .into(db.dives)
        .insert(
          const DivesCompanion(
            id: Value('dive-1'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'comp-1',
            name: 'Perdix',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  group('insert and read', () {
    test('insertSeries stores the encoded samples and summary', () async {
      final id = await repo.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        samples: samples,
        now: now,
      );

      final row = await (db.select(db.diveProfileSeries)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(row.diveId, 'dive-1');
      expect(row.computerId, 'comp-1');
      expect(row.sourceId, isNull);
      expect(row.isPrimary, isTrue);
      expect(row.sampleCount, 4);
      expect(row.startTimestamp, 0);
      expect(row.endTimestamp, 30);
      expect(row.maxDepth, 18.5);
      expect(row.firstDepth, 0.0);
      expect(row.lastDepth, 5.0);
      expect(row.hasDecoType, isTrue);
      expect(row.hasDecoStop, isTrue);
      expect(row.hasPositiveCeiling, isTrue);
      expect(row.codecVersion, 1);
      expect(row.createdAt, now);
      expect(row.updatedAt, now);

      final read = await repo.getSeriesForDive('dive-1');
      expect(read, hasLength(1));
      expect(read.single.id, id);
      expect(read.single.samples, samples);
      expect(read.single.summary.sampleCount, 4);
      expect(read.single.points.map((p) => p.depth), [0.0, 12.0, 18.5, 5.0]);
    });

    test('insertSeries stamps an hlc through the sync repository', () async {
      final id = await repo.insertSeries(
        diveId: 'dive-1',
        samples: samples,
        now: now,
      );
      final row = await (db.select(db.diveProfileSeries)
            ..where((t) => t.id.equals(id)))
          .getSingle();
      expect(row.hlc, isNotNull);
      final pending = await (db.select(db.syncRecords)
            ..where((t) => t.recordId.equals(id)))
          .getSingle();
      expect(pending.entityType, ProfileSeriesRepository.entityType);
    });

    test('insertSeries drops exact duplicate samples', () async {
      final id = await repo.insertSeries(
        diveId: 'dive-1',
        samples: [samples[0], samples[1], samples[1], samples[2]],
        now: now,
      );
      final read = await repo.getSeriesById(id);
      expect(read!.samples, [samples[0], samples[1], samples[2]]);
      expect(read.summary.sampleCount, 3);
    });

    test('insertSeries accepts a caller-supplied id', () async {
      final id = await repo.insertSeries(
        diveId: 'dive-1',
        samples: samples,
        id: 'fixed-id',
        now: now,
      );
      expect(id, 'fixed-id');
      expect(await repo.getSeriesById('fixed-id'), isNotNull);
    });

    test('an empty sample list is refused', () async {
      expect(
        () => repo.insertSeries(diveId: 'dive-1', samples: const []),
        throwsArgumentError,
      );
    });

    test('getSeriesForDive orders by start then id and can filter primary', () async {
      await repo.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: false,
        samples: const [ProfileSample(timestamp: 5, depth: 1.0)],
        id: 'b',
        now: now,
      );
      await repo.insertSeries(
        diveId: 'dive-1',
        samples: samples,
        id: 'a',
        now: now,
      );
      final all = await repo.getSeriesForDive('dive-1');
      expect(all.map((s) => s.id), ['a', 'b']);
      final primary = await repo.getSeriesForDive('dive-1', primaryOnly: true);
      expect(primary.map((s) => s.id), ['a']);
    });

    test('getSeriesById returns null for an unknown id', () async {
      expect(await repo.getSeriesById('nope'), isNull);
    });
  });

  group('flags and deletes', () {
    late String computerSeries;
    late String editSeries;

    setUp(() async {
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion.insert(
              id: 'src-1',
              diveId: 'dive-1',
              computerId: const Value('comp-1'),
              isPrimary: const Value(true),
              importedAt: DateTime.fromMillisecondsSinceEpoch(now),
              createdAt: DateTime.fromMillisecondsSinceEpoch(now),
            ),
          );
      computerSeries = await repo.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        sourceId: 'src-1',
        samples: samples,
        now: now,
      );
      editSeries = await repo.insertSeries(
        diveId: 'dive-1',
        sourceId: 'src-1',
        samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
        now: now,
      );
    });

    test('demoteAll clears is_primary on every series of the dive', () async {
      expect(await repo.demoteAll('dive-1', now: now + 1), 2);
      final rows = await repo.getSeriesForDive('dive-1');
      expect(rows.map((s) => s.isPrimary), everyElement(isFalse));
      expect(rows.map((s) => s.updatedAt), everyElement(now + 1));
    });

    test('promoteOwnedBy matches the source FK first', () async {
      await repo.demoteAll('dive-1');
      final promoted = await repo.promoteOwnedBy(
        'dive-1',
        sourceId: 'src-1',
        computerId: 'comp-1',
        now: now + 2,
      );
      expect(promoted, 2, reason: 'both series carry source src-1');
    });

    test('promoteOwnedBy falls back to computer id for rows without a source', () async {
      final legacy = await repo.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: false,
        samples: const [ProfileSample(timestamp: 0, depth: 3.0)],
        now: now,
      );
      await repo.demoteAll('dive-1');
      final promoted = await repo.promoteOwnedBy(
        'dive-1',
        sourceId: 'other-source',
        computerId: 'comp-1',
      );
      expect(promoted, 1);
      final row = await repo.getSeriesById(legacy);
      expect(row!.isPrimary, isTrue);
    });

    test('promoteOwnedBy with a null computer matches null, not everything', () async {
      final manual = await repo.insertSeries(
        diveId: 'dive-1',
        isPrimary: false,
        samples: const [ProfileSample(timestamp: 0, depth: 4.0)],
        now: now,
      );
      await repo.demoteAll('dive-1');
      final promoted = await repo.promoteOwnedBy(
        'dive-1',
        sourceId: 'other-source',
        computerId: null,
      );
      expect(promoted, 1);
      expect((await repo.getSeriesById(manual))!.isPrimary, isTrue);
      expect((await repo.getSeriesById(computerSeries))!.isPrimary, isFalse);
    });

    test('deleteOwnedBy removes the matching series and logs tombstones', () async {
      final deleted = await repo.deleteOwnedBy(
        'dive-1',
        sourceId: 'src-1',
        computerId: 'comp-1',
      );
      expect(deleted.toSet(), {computerSeries, editSeries});
      expect(await repo.getSeriesForDive('dive-1'), isEmpty);
      final tombstones = await (db.select(db.deletionLog)
            ..where((t) => t.entityType.equals(ProfileSeriesRepository.entityType)))
          .get();
      expect(tombstones.map((t) => t.recordId).toSet(), {computerSeries, editSeries});
    });

    test('deleteForDive removes every series of the dive', () async {
      final deleted = await repo.deleteForDive('dive-1');
      expect(deleted, hasLength(2));
      expect(await repo.getSeriesForDive('dive-1'), isEmpty);
    });
  });
}
```

If `DiveComputersCompanion.insert` or `DiveDataSourcesCompanion.insert` require other fields, read the generated companion in `database.g.dart` and supply the minimum required arguments; do not change the assertions.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/profile_series_repository_test.dart`
Expected: compilation failure, repository file not found.

- [ ] **Step 3: Create the repository**

Create `lib/features/dive_log/data/repositories/profile_series_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_summary.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart';
import 'package:submersion/features/dive_log/domain/services/profile_sample_dedupe.dart';

/// Every read and write of `dive_profile_series`. The only production code
/// that encodes or decodes profile samples, apart from the migration packer.
///
/// Zero-arg like `TankPressureRepository`: the database is the
/// `DatabaseService` singleton, so `setUpTestDatabase()` composes with it.
class ProfileSeriesRepository {
  ProfileSeriesRepository({SyncRepository? syncRepository})
    : _syncRepository = syncRepository ?? SyncRepository();

  /// The sync entity type; also the `hlcTargets` key.
  static const String entityType = 'diveProfileSeries';

  static const ProfileSeriesCodec _codec = ProfileSeriesCodec();

  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository;
  final _uuid = const Uuid();

  /// Inserts one series and marks it pending so it gets an HLC.
  ///
  /// [samples] must be non-empty and timestamp-ordered; exact duplicates are
  /// dropped. Throws [ArgumentError] on an empty list. Returns the row id.
  Future<String> insertSeries({
    required String diveId,
    String? computerId,
    String? sourceId,
    bool isPrimary = true,
    required List<ProfileSample> samples,
    String? id,
    int? now,
  }) async {
    final encoded = _codec.encode(dedupeExactSamples(samples));
    final summary = encoded.summary;
    final rowId = id ?? _uuid.v4();
    final nowMs = now ?? DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.diveProfileSeries)
        .insert(
          DiveProfileSeriesCompanion.insert(
            id: rowId,
            diveId: diveId,
            computerId: Value(computerId),
            sourceId: Value(sourceId),
            isPrimary: Value(isPrimary),
            sampleCount: summary.sampleCount,
            startTimestamp: summary.startTimestamp,
            endTimestamp: summary.endTimestamp,
            maxDepth: summary.maxDepth,
            firstDepth: summary.firstDepth,
            lastDepth: summary.lastDepth,
            hasDecoType: Value(summary.hasDecoType),
            hasDecoStop: Value(summary.hasDecoStop),
            hasPositiveCeiling: Value(summary.hasPositiveCeiling),
            codecVersion: encoded.codecVersion,
            samples: encoded.bytes,
            createdAt: nowMs,
            updatedAt: nowMs,
          ),
        );
    await _markPending(rowId, nowMs);
    SyncEventBus.notifyLocalChange();
    return rowId;
  }

  /// Every series of [diveId], decoded, oldest start first and then by id
  /// so the order is stable. [primaryOnly] keeps only `is_primary` rows.
  Future<List<ProfileSeries>> getSeriesForDive(
    String diveId, {
    bool primaryOnly = false,
  }) async {
    final query = _db.select(_db.diveProfileSeries)
      ..where((t) => t.diveId.equals(diveId))
      ..orderBy([
        (t) => OrderingTerm.asc(t.startTimestamp),
        (t) => OrderingTerm.asc(t.id),
      ]);
    if (primaryOnly) {
      query.where((t) => t.isPrimary.equals(true));
    }
    final rows = await query.get();
    return [for (final row in rows) _decode(row)];
  }

  Future<ProfileSeries?> getSeriesById(String id) async {
    final row = await (_db.select(_db.diveProfileSeries)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _decode(row);
  }

  /// Clears `is_primary` on every series of [diveId]. Returns how many rows
  /// changed; each changed row is marked pending.
  Future<int> demoteAll(String diveId, {int? now}) async {
    final nowMs = now ?? DateTime.now().millisecondsSinceEpoch;
    final ids = await _ids((t) => t.diveId.equals(diveId));
    if (ids.isEmpty) return 0;
    await (_db.update(_db.diveProfileSeries)
          ..where((t) => t.id.isIn(ids)))
        .write(
          DiveProfileSeriesCompanion(
            isPrimary: const Value(false),
            updatedAt: Value(nowMs),
          ),
        );
    for (final id in ids) {
      await _markPending(id, nowMs);
    }
    SyncEventBus.notifyLocalChange();
    return ids.length;
  }

  /// Sets `is_primary` on the series [sourceId] or [computerId] own.
  ///
  /// Ownership is the FK first, then the pre-v154 computer convention for
  /// rows that carry no source: `source_id = ?` OR (`source_id IS NULL` AND
  /// `computer_id IS ?`). The IS-semantics on the computer id are load
  /// bearing: `=` never matches NULL, which is how issue #1149 began.
  Future<int> promoteOwnedBy(
    String diveId, {
    required String? sourceId,
    required String? computerId,
    int? now,
  }) async {
    final nowMs = now ?? DateTime.now().millisecondsSinceEpoch;
    final ids = await _ids(
      (t) =>
          t.diveId.equals(diveId) &
          _ownedBy(t, sourceId: sourceId, computerId: computerId),
    );
    if (ids.isEmpty) return 0;
    await (_db.update(_db.diveProfileSeries)
          ..where((t) => t.id.isIn(ids)))
        .write(
          DiveProfileSeriesCompanion(
            isPrimary: const Value(true),
            updatedAt: Value(nowMs),
          ),
        );
    for (final id in ids) {
      await _markPending(id, nowMs);
    }
    SyncEventBus.notifyLocalChange();
    return ids.length;
  }

  /// Deletes the series [sourceId] or [computerId] own (see
  /// [promoteOwnedBy] for the predicate), one tombstone per series.
  /// Returns the deleted ids.
  Future<List<String>> deleteOwnedBy(
    String diveId, {
    required String? sourceId,
    required String? computerId,
  }) => _delete(
    (t) =>
        t.diveId.equals(diveId) &
        _ownedBy(t, sourceId: sourceId, computerId: computerId),
  );

  /// Deletes every series of [diveId], one tombstone per series.
  Future<List<String>> deleteForDive(String diveId) =>
      _delete((t) => t.diveId.equals(diveId));

  Expression<bool> _ownedBy(
    $DiveProfileSeriesTable t, {
    required String? sourceId,
    required String? computerId,
  }) {
    final bySource = sourceId == null
        ? const Constant<bool>(false)
        : t.sourceId.equals(sourceId);
    final byComputer =
        t.sourceId.isNull() &
        (computerId == null
            ? t.computerId.isNull()
            : t.computerId.equals(computerId));
    return bySource | byComputer;
  }

  Future<List<String>> _ids(
    Expression<bool> Function($DiveProfileSeriesTable t) where,
  ) async {
    final query = _db.selectOnly(_db.diveProfileSeries)
      ..addColumns([_db.diveProfileSeries.id])
      ..where(where(_db.diveProfileSeries));
    final rows = await query.get();
    return [for (final row in rows) row.read(_db.diveProfileSeries.id)!];
  }

  Future<List<String>> _delete(
    Expression<bool> Function($DiveProfileSeriesTable t) where,
  ) async {
    final ids = await _ids(where);
    if (ids.isEmpty) return ids;
    for (final id in ids) {
      await _syncRepository.logDeletion(entityType: entityType, recordId: id);
    }
    await (_db.delete(_db.diveProfileSeries)..where((t) => t.id.isIn(ids)))
        .go();
    SyncEventBus.notifyLocalChange();
    return ids;
  }

  Future<void> _markPending(String id, int nowMs) =>
      _syncRepository.markRecordPending(
        entityType: entityType,
        recordId: id,
        localUpdatedAt: nowMs,
      );

  ProfileSeries _decode(DiveProfileSeriesRow row) {
    return ProfileSeries(
      id: row.id,
      diveId: row.diveId,
      computerId: row.computerId,
      sourceId: row.sourceId,
      isPrimary: row.isPrimary,
      summary: ProfileSeriesSummary(
        sampleCount: row.sampleCount,
        startTimestamp: row.startTimestamp,
        endTimestamp: row.endTimestamp,
        maxDepth: row.maxDepth,
        firstDepth: row.firstDepth,
        lastDepth: row.lastDepth,
        hasDecoType: row.hasDecoType,
        hasDecoStop: row.hasDecoStop,
        hasPositiveCeiling: row.hasPositiveCeiling,
      ),
      samples: _codec.decode(row.samples),
      codecVersion: row.codecVersion,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      hlc: row.hlc,
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/data/repositories/profile_series_repository_test.dart`
Expected: 13 tests pass. If `row.read(_db.diveProfileSeries.id)` in `_ids` does not compile, use `row.read<String>(_db.diveProfileSeries.id)`.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/data/repositories/profile_series_repository.dart test/features/dive_log/data/repositories/profile_series_repository_test.dart
git commit -m "feat: ProfileSeriesRepository over dive_profile_series"
```

---

### Task 6: TankPressureSeriesRepository

**Files:**
- Create: `lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart`
- Test: `test/features/dive_log/data/repositories/tank_pressure_series_repository_test.dart`

**Interfaces:**
- Consumes: `db.tankPressureSeries`, `TankPressureSeriesCompanion`, `TankPressureSeriesRow` (Task 2); `TankPressureSeries`, `dedupeExactPressureSamples` (Task 1); `TankPressureSeriesCodec`, `TankPressureSample`, `TankPressureSeriesSummary` (PR 1).
- Produces:
  - `class TankPressureSeriesRepository { TankPressureSeriesRepository({SyncRepository? syncRepository}); static const String entityType = 'tankPressureSeries'; }`
  - `Future<String> insertSeries({required String diveId, required String tankId, String? computerId, required List<TankPressureSample> samples, String? id, int? now})`
  - `Future<List<domain.TankPressureSeries>> getSeriesForDive(String diveId)`
  - `Future<List<domain.TankPressureSeries>> getSeriesForTank(String diveId, String tankId)`
  - `Future<List<String>> deleteForDive(String diveId)`
  - `Future<List<String>> deleteForTank(String diveId, String tankId)`
  - `Future<List<String>> deleteOwnedByComputer(String diveId, String? computerId)`

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/data/repositories/tank_pressure_series_repository_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TankPressureSeriesRepository repo;
  const now = 1750000000000;

  const samples = [
    TankPressureSample(timestamp: 0, pressure: 200.0),
    TankPressureSample(timestamp: 60, pressure: 190.5),
    TankPressureSample(timestamp: 120, pressure: 182.0),
  ];

  setUp(() async {
    db = await setUpTestDatabase();
    repo = TankPressureSeriesRepository();
    await db
        .into(db.dives)
        .insert(
          const DivesCompanion(
            id: Value('dive-1'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'comp-1',
            name: 'Perdix',
            createdAt: now,
            updatedAt: now,
          ),
        );
    for (final tank in ['tank-a', 'tank-b']) {
      await db
          .into(db.diveTanks)
          .insert(DiveTanksCompanion.insert(id: tank, diveId: 'dive-1'));
    }
  });

  tearDown(tearDownTestDatabase);

  test('insertSeries stores the encoded readings and summary', () async {
    final id = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      computerId: 'comp-1',
      samples: samples,
      now: now,
    );
    final row = await (db.select(db.tankPressureSeries)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    expect(row.tankId, 'tank-a');
    expect(row.computerId, 'comp-1');
    expect(row.sampleCount, 3);
    expect(row.startTimestamp, 0);
    expect(row.endTimestamp, 120);
    expect(row.hlc, isNotNull);

    final read = await repo.getSeriesForTank('dive-1', 'tank-a');
    expect(read.single.samples, samples);
    expect(read.single.summary.sampleCount, 3);
  });

  test('exact duplicates are dropped and an empty list is refused', () async {
    final id = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      samples: [samples[0], samples[0], samples[1]],
      now: now,
    );
    final read = await repo.getSeriesForTank('dive-1', 'tank-a');
    expect(read.single.id, id);
    expect(read.single.samples, [samples[0], samples[1]]);
    expect(
      () => repo.insertSeries(diveId: 'dive-1', tankId: 'tank-a', samples: const []),
      throwsArgumentError,
    );
  });

  test('getSeriesForDive orders by tank then start', () async {
    await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-b',
      samples: samples,
      id: 'b',
      now: now,
    );
    await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      samples: samples,
      id: 'a',
      now: now,
    );
    final all = await repo.getSeriesForDive('dive-1');
    expect(all.map((s) => s.id), ['a', 'b']);
  });

  test('deleteForTank and deleteOwnedByComputer tombstone what they remove', () async {
    final a = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-a',
      computerId: 'comp-1',
      samples: samples,
      now: now,
    );
    final b = await repo.insertSeries(
      diveId: 'dive-1',
      tankId: 'tank-b',
      samples: samples,
      now: now,
    );

    expect(await repo.deleteForTank('dive-1', 'tank-a'), [a]);
    expect((await repo.getSeriesForDive('dive-1')).map((s) => s.id), [b]);

    expect(await repo.deleteOwnedByComputer('dive-1', null), [b]);
    expect(await repo.getSeriesForDive('dive-1'), isEmpty);

    final tombstones = await (db.select(db.deletionLog)
          ..where(
            (t) => t.entityType.equals(TankPressureSeriesRepository.entityType),
          ))
        .get();
    expect(tombstones.map((t) => t.recordId).toSet(), {a, b});
  });

  test('deleteForDive removes every series of the dive', () async {
    await repo.insertSeries(diveId: 'dive-1', tankId: 'tank-a', samples: samples);
    await repo.insertSeries(diveId: 'dive-1', tankId: 'tank-b', samples: samples);
    expect(await repo.deleteForDive('dive-1'), hasLength(2));
    expect(await repo.getSeriesForDive('dive-1'), isEmpty);
  });
}
```

If `DiveTanksCompanion.insert` requires more fields, supply the minimum from `database.g.dart`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/tank_pressure_series_repository_test.dart`
Expected: compilation failure, repository file not found.

- [ ] **Step 3: Create the repository**

Create `lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
// The Drift table class and the domain entity are both named
// TankPressureSeries; the project resolves that with an alias.
import 'package:submersion/features/dive_log/domain/entities/profile_series.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/services/profile_sample_dedupe.dart';

/// Every read and write of `tank_pressure_series`. See
/// `ProfileSeriesRepository` for the conventions; this is its two-field
/// sibling keyed by (dive, tank, computer).
class TankPressureSeriesRepository {
  TankPressureSeriesRepository({SyncRepository? syncRepository})
    : _syncRepository = syncRepository ?? SyncRepository();

  static const String entityType = 'tankPressureSeries';

  static const TankPressureSeriesCodec _codec = TankPressureSeriesCodec();

  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository;
  final _uuid = const Uuid();

  /// Inserts one series and marks it pending. [samples] must be non-empty
  /// and timestamp-ordered; exact duplicates are dropped. Returns the id.
  Future<String> insertSeries({
    required String diveId,
    required String tankId,
    String? computerId,
    required List<TankPressureSample> samples,
    String? id,
    int? now,
  }) async {
    final encoded = _codec.encode(dedupeExactPressureSamples(samples));
    final rowId = id ?? _uuid.v4();
    final nowMs = now ?? DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.tankPressureSeries)
        .insert(
          TankPressureSeriesCompanion.insert(
            id: rowId,
            diveId: diveId,
            tankId: tankId,
            computerId: Value(computerId),
            sampleCount: encoded.summary.sampleCount,
            startTimestamp: encoded.summary.startTimestamp,
            endTimestamp: encoded.summary.endTimestamp,
            codecVersion: encoded.codecVersion,
            samples: encoded.bytes,
            createdAt: nowMs,
            updatedAt: nowMs,
          ),
        );
    await _syncRepository.markRecordPending(
      entityType: entityType,
      recordId: rowId,
      localUpdatedAt: nowMs,
    );
    SyncEventBus.notifyLocalChange();
    return rowId;
  }

  /// Every series of [diveId], by tank then start then id.
  Future<List<domain.TankPressureSeries>> getSeriesForDive(String diveId) async {
    final rows =
        await (_db.select(_db.tankPressureSeries)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.tankId),
                (t) => OrderingTerm.asc(t.startTimestamp),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return [for (final row in rows) _decode(row)];
  }

  Future<List<domain.TankPressureSeries>> getSeriesForTank(
    String diveId,
    String tankId,
  ) async {
    final rows =
        await (_db.select(_db.tankPressureSeries)
              ..where((t) => t.diveId.equals(diveId) & t.tankId.equals(tankId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.startTimestamp),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
    return [for (final row in rows) _decode(row)];
  }

  Future<List<String>> deleteForDive(String diveId) =>
      _delete((t) => t.diveId.equals(diveId));

  Future<List<String>> deleteForTank(String diveId, String tankId) =>
      _delete((t) => t.diveId.equals(diveId) & t.tankId.equals(tankId));

  /// Deletes the series [computerId] contributed; a null [computerId]
  /// matches the null-computer (manual or primary-source) rows only.
  Future<List<String>> deleteOwnedByComputer(String diveId, String? computerId) =>
      _delete(
        (t) =>
            t.diveId.equals(diveId) &
            (computerId == null
                ? t.computerId.isNull()
                : t.computerId.equals(computerId)),
      );

  Future<List<String>> _delete(
    Expression<bool> Function($TankPressureSeriesTable t) where,
  ) async {
    final query = _db.selectOnly(_db.tankPressureSeries)
      ..addColumns([_db.tankPressureSeries.id])
      ..where(where(_db.tankPressureSeries));
    final ids = [
      for (final row in await query.get())
        row.read(_db.tankPressureSeries.id)!,
    ];
    if (ids.isEmpty) return ids;
    for (final id in ids) {
      await _syncRepository.logDeletion(entityType: entityType, recordId: id);
    }
    await (_db.delete(_db.tankPressureSeries)..where((t) => t.id.isIn(ids)))
        .go();
    SyncEventBus.notifyLocalChange();
    return ids;
  }

  domain.TankPressureSeries _decode(TankPressureSeriesRow row) {
    return domain.TankPressureSeries(
      id: row.id,
      diveId: row.diveId,
      tankId: row.tankId,
      computerId: row.computerId,
      summary: TankPressureSeriesSummary(
        sampleCount: row.sampleCount,
        startTimestamp: row.startTimestamp,
        endTimestamp: row.endTimestamp,
      ),
      samples: _codec.decode(row.samples),
      codecVersion: row.codecVersion,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      hlc: row.hlc,
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/dive_log/data/repositories/tank_pressure_series_repository_test.dart`
Expected: 5 tests pass.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart test/features/dive_log/data/repositories/tank_pressure_series_repository_test.dart
git commit -m "feat: TankPressureSeriesRepository over tank_pressure_series"
```

---

### Task 7: Verification

**Files:** none new.

**Interfaces:** consumes everything above; produces a green branch ready for plan 2b. No push, no PR: plans 2b to 2e continue on this branch.

- [ ] **Step 1: Run every test file this plan touched, individually**

```bash
flutter test test/features/dive_log/domain/entities/profile_series_test.dart
flutter test test/features/dive_log/domain/services/profile_sample_dedupe_test.dart
flutter test test/core/database/migration_v182_profile_series_test.dart
flutter test test/core/database/profile_series_pack_test.dart
flutter test test/features/dive_log/data/repositories/profile_series_repository_test.dart
flutter test test/features/dive_log/data/repositories/tank_pressure_series_repository_test.dart
flutter test test/core/database/query_plan_test.dart
flutter test test/core/database/performance_indexes_test.dart
flutter test test/core/services/sync/sync_hlc_target_registration_test.dart
flutter test test/core/data/repositories/sync_repository_hlc_stamp_test.dart
flutter test test/core/database/migration_v180_stats_exclusion_test.dart
flutter test test/core/database/pre_migration_backup_integration_test.dart
```

Expected: every file reports `All tests passed!`.

- [ ] **Step 2: Format and analyze project-wide**

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
```

Expected: both exit 0; analyze reports `No issues found!`.

- [ ] **Step 3: Confirm the layering constraints**

```bash
grep -l "package:flutter" lib/core/database/profile_series_pack.dart lib/features/dive_log/domain/entities/profile_series.dart lib/features/dive_log/domain/services/profile_sample_dedupe.dart
grep -c "diveProfiles\b\|tankPressureProfiles\b" lib/core/database/profile_series_pack.dart
wc -l lib/core/database/profile_series_pack.dart lib/features/dive_log/data/repositories/profile_series_repository.dart lib/features/dive_log/data/repositories/tank_pressure_series_repository.dart lib/features/dive_log/domain/entities/profile_series.dart
```

Expected: the first grep prints nothing; the second prints `0` (the packer never names the legacy Drift accessors); every file is under 400 lines.

- [ ] **Step 4: Run the full suite once**

```bash
flutter test --reporter compact --concurrency=16 > /private/tmp/claude-501/-Users-ericgriffin-repos-submersion-app-submersion/5b0068b6-136c-4277-89c4-30a25ed89d1c/scratchpad/full-suite-2a.log 2>&1; echo "exit=$?" >> /private/tmp/claude-501/-Users-ericgriffin-repos-submersion-app-submersion/5b0068b6-136c-4277-89c4-30a25ed89d1c/scratchpad/full-suite-2a.log
```

Run with `run_in_background: true` and a 600000 ms timeout, then read the last 40 lines. Expected: `exit=0` or failures limited to documented flakes, each green when rerun alone (`test/features/media/data/resolvers/local_file_resolver_test.dart` fails on this machine because `$TMPDIR` is a mounted volume; it passes with `TMPDIR=/private/tmp/claude-501/sysvol-tmp flutter test <file>`). Any failure in a file this plan touched, or any failure that repeats alone, is real.

- [ ] **Step 5: Report**

Reply with: the commit list (`git log --oneline origin/worktree-profile-sample-storage..HEAD`), the per-file test counts, the full-suite summary line and exit, any flake reruns, and the line counts from Step 3.

---

## Post-review amendments (2026-08-29)

The whole-plan review after Task 7 changed the following on top of the
tasks above. They are recorded here so the plan matches the branch.

- Rung renumbered 181 to 182: open PR #1390 (profile photos) holds 181.
  The migration test is `migration_v182_profile_series_test.dart`.
- The `beforeOpen` backstop now calls `packLegacyProfileRows` after the
  schema helper. The packer visits only dives that have legacy rows and no
  series row (an indexed `NOT EXISTS`), so it is cheap once packed and a
  no-op after the legacy tables are gone; a device that took a parallel
  branch's rung number self-heals instead of losing its samples.
- The packer reads both legacy tables through `PRAGMA table_info`: missing
  identity columns read as null computer, null source, primary; a table
  missing `dive_id`, `timestamp`, or `depth` (or `tank_id`, `pressure`) is
  skipped. Nine older migration tests build such minimal fixtures and let
  the ladder run to the top.
- The packer resolves FK parents before inserting: a group whose dive (or
  tank) is gone is skipped and counted in `ProfilePackReport.skippedOrphans`;
  an unresolvable `computer_id` or `source_id` becomes null. `INSERT OR
  IGNORE` does not swallow FK violations, and one orphan would otherwise
  abort every retry of the ladder.
- The migration HLC advances the persisted `sync_metadata.hlc`
  (`Hlc.parse(persisted).increment(nowMs)`) and falls back to a fresh clock
  from the device id; a wall-clock stamp can sort below the publish
  watermark after a peer merge and never ride a changeset.
- `database.dart`'s import graph stays Flutter-free: the `DiveProfilePoint`
  conversions moved to `codecs/profile_sample_point.dart`, the id helpers
  moved to `entities/profile_series_identity.dart`, and
  `test/core/database/database_import_graph_test.dart` walks the transitive
  graph.
- `ProfileSeriesRepository` gained `promoteWinnerOwnedBy` (null computer
  first, then greatest id, one series; the primary-swap rule),
  `deleteEditedSeries`, `promoteByComputer`, `promoteAll`,
  `hasPrimarySeries`, and `restoreSeriesRow`; `TankPressureSeriesRepository`
  gained `restoreSeriesRow`. Multi-step writes run in a transaction;
  `demoteAll` touches only primary rows.
- Shared fixtures live in `test/helpers/legacy_profile_fixtures.dart`.
- The `TankPressureSeries` name is shared by the Drift table class and the
  domain entity by decision: the table name is fixed by the spec and the
  entity mirrors `ProfileSeries`; consumers import the entity `as domain`.

Carried into plan 2b (from the review): `_ownedBy` is `_ownedBySourceSql`,
not `isPrimaryFamily` (the dangling-source rule is ported separately in 2c);
a computer delete must stamp the affected series so the `SET NULL` syncs; a
group split across `is_primary` values packs into two series and 2c's read
must reach the same answer as `_dropSupersededOriginals`; consider wrapping
the pack in a transaction for the benchmark; the per-series LWW window
during a mixed-version fleet needs an explicit decision in 2d.

## Self-review

**Spec coverage.** Section 4's two tables with exactly the listed columns, FKs, and indexes: Task 2 (Drift classes and raw DDL agree, tested on a fresh database). Section 8's rung, its idempotence, deterministic uuid v5 ids over the identity tuple with `null` for absent members, `created_at`/`updated_at` from the migration time, and the HLC from the local device: Tasks 1, 3, 4 (the HLC is minted from `sync_metadata.device_id` because `SyncClock` is not configured inside the ladder; a never-synced device stays unstamped and is covered by base publish). Section 8's "memory bounded by one dive": the packer selects per dive. Section 6's dedupe moving to encode time: Task 1's `dedupeExactSamples`, used by the packer and both repositories. Section 6's repository API surface (`insertSeries`, `demoteAll`, `promote`, `deleteSeriesOwnedBy`, `deleteSeriesForDive`, reads): Tasks 5 and 6, with `replaceSeriesOwnedBy` deliberately deferred to plan 2b where its first caller (reparse) lands. Section 10's migration tests (upgrade fixture with duplicates, null source and computer, a multi-source dive, a manual-edit series; two independently migrated copies produce identical ids; `query_plan_test` and `performance_indexes_test` updated): Tasks 2, 3, 4. The registration test for `hlcTargets`: Task 2.

Deliberately not in this plan, by the 2a/2b/2c/2d/2e split: any change to the legacy tables or their consumers, sync serializer registration, dropping tables, purging retired tombstones, `VACUUM`, the fixture script, benchmarks.

**Placeholder scan.** Every code step carries the full file or test. The conditional instructions ("if `customUpdate` requires `updates`", "if a companion requires more fields") name the exact fix and forbid changing assertions.

**Type consistency.** `profileSeriesMigratedId({diveId, computerId, sourceId, isPrimary})` and `tankPressureSeriesMigratedId({diveId, tankId, computerId})` are defined in Task 1 and called with those names in Task 3 and its tests. `ProfilePackReport` fields `profileSeries`, `tankSeries`, `droppedSamples` match Task 3's test. `ProfileSeriesRepository.entityType` and `TankPressureSeriesRepository.entityType` equal the `hlcTargets` keys added in Task 2. `DiveProfileSeriesCompanion.insert` required arguments in Task 5 are exactly the non-defaulted, non-nullable columns declared in Task 2; the same holds for `TankPressureSeriesCompanion.insert` in Task 6. `ProfileSeries.copyWith` flags `clearComputerId` and `clearSourceId` are used by Task 1's test. `dedupeExactPressureSamples` is named identically in Tasks 1, 3, 6.
