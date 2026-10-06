# Decompression Obligation Statistic Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Statistics tab's "Decompression Obligation" card report the same deco determination the dive detail page shows, instead of reading a computer-reported column that most import sources never populate.

**Architecture:** Classify each dive from recorded profile signals first (`deco_type = 2`, `decoStopStart` events, then `ceiling > 0` only for sources that write no `deco_type`), fall back to the app's own Buhlmann analysis via `profileAnalysisProvider` for dives with a profile but no recorded signal, and report dives with no profile as "not recorded" rather than counting them as no-deco. Computed answers are memoized in `local_cache_database.dart`, which is never synced or backed up, keyed by an inputs fingerprint so a changed profile or changed gradient factors recompute.

**Tech Stack:** Flutter, Drift ORM (SQLite), Riverpod, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-18-deco-obligation-statistic.md`

## Global Constraints

- No em-dashes (U+2014) in any output, including code, comments, docs, and commit messages. En-dashes as sentence punctuation and spaced hyphens are equally forbidden. Numeric ranges (`2020-2024`) and CLI flags keep hyphens.
- No emojis in code, comments, or documentation.
- `dart format .` must produce no changes before any commit.
- `flutter analyze` must be clean across the whole project. Infos are fatal in CI.
- Anything displaying units must respect the active diver's unit settings.
- New user-facing strings go in `lib/l10n/arb/app_en.arb` and must be translated into every locale present in `lib/l10n/arb/`: ar, de, es, fr, he, hu, it, nl, pt, zh.
- Immutability: never mutate objects or arrays in place.
- Run all commands from the worktree root. Do not `cd` to the main checkout.
- Re-derivable data belongs in `local_cache_database.dart`, never the synced main DB.

---

### Task 1: Correct the recorded-signal classification and stop asserting a false zero

Today `getDecoObligationStats` counts a deco dive as any dive with a sample where `ceiling > 0`. That over-counts (a 5 m safety stop writes `ceiling = 5`, because the mappers set `ceiling` for any non-zero `deco_type`, and `1 = safetystop`) and under-counts (dives from sources that never write `ceiling` are silently reported as no-deco). This task fixes the predicate and introduces the "not recorded" bucket so the card stops claiming certainty it does not have.

**Files:**
- Modify: `lib/features/statistics/data/repositories/statistics_repository.dart:2195-2227`
- Modify: `lib/features/statistics/presentation/providers/statistics_providers.dart:498-508`
- Modify: `lib/features/statistics/presentation/pages/statistics_profile_page.dart:191-281`
- Modify: `lib/l10n/arb/app_en.arb` and the ten locale ARB files
- Test: `test/features/statistics/data/repositories/statistics_repository_deco_test.dart` (create)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `DecoSignalScan` typedef in `statistics_repository.dart`:
    ```dart
    typedef DecoSignalScan = ({
      Set<String> recordedDeco,
      Set<String> recordedNoDeco,
      Map<String, int> needsCompute,
      Set<String> noProfile,
    });
    ```
    `needsCompute` maps dive id to that dive's `dives.updated_at`, which the
    computed step uses as the profile revision in its cache fingerprint. The
    `Dive` entity returned by `getDiveForAnalysis` carries no `updatedAt`, so
    the scan is the only place that value is cheaply available.
  - `Future<DecoSignalScan> StatisticsRepository.scanRecordedDecoSignals({String? diverId, DiveFilterState filter})`
  - `Future<({int decoCount, int noDecoCount, int unknownCount})> StatisticsRepository.getDecoObligationStats({String? diverId, DiveFilterState filter})`

- [ ] **Step 1: Write the failing test**

Create `test/features/statistics/data/repositories/statistics_repository_deco_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late StatisticsRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = StatisticsRepository();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  Future<void> dive(String id) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  /// Inserts profile samples as (timestamp, depth, decoType, ceiling) tuples.
  Future<void> profile(
    String diveId,
    List<(int, double, int?, double?)> samples,
  ) async {
    var index = 0;
    for (final (ts, depth, decoType, ceiling) in samples) {
      await db
          .into(db.diveProfiles)
          .insert(
            DiveProfilesCompanion(
              id: Value('$diveId-row-${index++}'),
              diveId: Value(diveId),
              timestamp: Value(ts),
              depth: Value(depth),
              decoType: Value(decoType),
              ceiling: Value(ceiling),
            ),
          );
    }
  }

  Future<void> decoStopEvent(String diveId) async {
    await db
        .into(db.diveProfileEvents)
        .insert(
          DiveProfileEventsCompanion(
            id: Value('$diveId-evt'),
            diveId: Value(diveId),
            timestamp: const Value(600),
            eventType: const Value('decoStopStart'),
            createdAt: Value(now),
          ),
        );
  }

  group('scanRecordedDecoSignals', () {
    test('a safety stop is not a decompression obligation', () async {
      await dive('safety');
      // deco_type 1 is DC_DECO_SAFETYSTOP; the mapper writes ceiling for it.
      await profile('safety', [
        (0, 10.0, 0, null),
        (300, 30.0, 0, null),
        (600, 5.0, 1, 5.0),
      ]);

      final scan = await repo.scanRecordedDecoSignals();

      expect(scan.recordedDeco, isEmpty);
      expect(scan.recordedNoDeco, {'safety'});
    });

    test('a deco stop sample is a decompression obligation', () async {
      await dive('deco');
      await profile('deco', [
        (0, 10.0, 0, null),
        (300, 45.0, 2, 9.0),
      ]);

      final scan = await repo.scanRecordedDecoSignals();

      expect(scan.recordedDeco, {'deco'});
      expect(scan.recordedNoDeco, isEmpty);
    });

    test('a decoStopStart event is a decompression obligation', () async {
      await dive('evt');
      await profile('evt', [(0, 10.0, null, null)]);
      await decoStopEvent('evt');

      final scan = await repo.scanRecordedDecoSignals();

      expect(scan.recordedDeco, {'evt'});
      expect(scan.needsCompute, isEmpty);
    });

    test('ceiling alone counts only when the source wrote no decoType',
        () async {
      await dive('ceilingOnly');
      // Subsurface XML and DAN DL7 write ceiling without any decoType.
      await profile('ceilingOnly', [
        (0, 10.0, null, null),
        (300, 45.0, null, 9.0),
      ]);

      final scan = await repo.scanRecordedDecoSignals();

      expect(scan.recordedDeco, {'ceilingOnly'});
    });

    test('a profile with no deco signal at all needs computing', () async {
      await dive('bare');
      await profile('bare', [
        (0, 10.0, null, null),
        (300, 45.0, null, null),
      ]);

      final scan = await repo.scanRecordedDecoSignals();

      expect(scan.needsCompute.keys, {'bare'});
      expect(scan.recordedNoDeco, isEmpty);
      expect(scan.noProfile, isEmpty);
    });

    test('a dive with no profile is unclassifiable', () async {
      await dive('manual');

      final scan = await repo.scanRecordedDecoSignals();

      expect(scan.noProfile, {'manual'});
      expect(scan.needsCompute, isEmpty);
    });
  });

  group('getDecoObligationStats', () {
    test('unclassifiable dives are reported separately, not as no-deco',
        () async {
      await dive('deco');
      await profile('deco', [(300, 45.0, 2, 9.0)]);
      await dive('manual');

      final stats = await repo.getDecoObligationStats();

      expect(stats.decoCount, 1);
      expect(stats.noDecoCount, 0);
      expect(stats.unknownCount, 1);
    });

    test('honours the diver filter', () async {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion(
              id: const Value('diver-a'),
              name: const Value('A'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await db
          .into(db.dives)
          .insert(
            DivesCompanion(
              id: const Value('mine'),
              diveDateTime: Value(now),
              diverId: const Value('diver-a'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await profile('mine', [(300, 45.0, 2, 9.0)]);
      await dive('theirs');
      await profile('theirs', [(300, 45.0, 2, 9.0)]);

      final stats = await repo.getDecoObligationStats(diverId: 'diver-a');

      expect(stats.decoCount, 1);
      expect(stats.unknownCount, 0);
      expect(stats.noDecoCount, 0);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/statistics/data/repositories/statistics_repository_deco_test.dart`
Expected: FAIL. `scanRecordedDecoSignals` is not defined, and `getDecoObligationStats` returns a record without `noDecoCount` or `unknownCount`.

- [ ] **Step 3: Replace the repository method**

In `lib/features/statistics/data/repositories/statistics_repository.dart`, add the typedef near the top of the file, after the imports:

```dart
/// Per-dive outcome of the recorded (non-computed) deco classification.
///
/// The four sets partition the filtered dive library. `needsCompute` holds
/// dives that have a profile but no recorded deco signal, which is the input
/// to the computed fallback; `noProfile` holds dives that can never be
/// classified from stored data.
typedef DecoSignalScan = ({
  Set<String> recordedDeco,
  Set<String> recordedNoDeco,
  Map<String, int> needsCompute,
  Set<String> noProfile,
});
```

Replace the whole of `getDecoObligationStats` (currently at `:2195-2227`) with:

```dart
  /// Classifies each filtered dive's decompression obligation from recorded
  /// profile data alone.
  ///
  /// Resolution order, highest confidence first:
  ///
  /// 1. `deco_type = 2` (DC_DECO_DECOSTOP per libdc_wrapper.h) or a
  ///    `decoStopStart` profile event means deco. Types 1 and 3 are safety
  ///    and deep stops, which are not decompression obligations; the old
  ///    `ceiling > 0` test counted both, because both mappers write
  ///    `ceiling = decoDepth` for any non-zero deco type.
  /// 2. A profile that carries `deco_type` values, none of which is 2, means
  ///    no deco. The computer was recording obligations and reported none.
  /// 3. `ceiling > 0` on a profile with no `deco_type` at all means deco.
  ///    Subsurface XML, DAN DL7 and FIT write a stop depth without a type,
  ///    so this clause keeps them working without re-admitting safety stops.
  /// 4. Anything else with a profile needs the computed fallback: many
  ///    sources (MacDive, Shearwater Cloud, generic UDDF, CSV, OCR) record
  ///    no deco columns at all, and for those the app's own analysis is the
  ///    only evidence there is. It is also what the dive detail page shows.
  /// 5. A dive with no profile is unclassifiable and must not be counted as
  ///    no-deco.
  Future<DecoSignalScan> scanRecordedDecoSignals({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final df = _diveFilter(filter, alias: 'd');
      final params = diverId != null ? [diverId, ...df.params] : [...df.params];

      final results = await _db.customSelect('''
        WITH scoped AS (
          SELECT d.id AS dive_id
          FROM dives d
          WHERE 1=1 $diverFilter ${df.clause}
        ),
        signals AS (
          SELECT
            s.dive_id AS dive_id,
            MAX(CASE WHEN p.id IS NOT NULL THEN 1 ELSE 0 END) AS has_profile,
            MAX(CASE WHEN p.deco_type IS NOT NULL THEN 1 ELSE 0 END)
              AS has_deco_type,
            MAX(CASE WHEN p.deco_type = 2 THEN 1 ELSE 0 END) AS deco_stop,
            MAX(CASE WHEN p.ceiling > 0 THEN 1 ELSE 0 END) AS positive_ceiling
          FROM scoped s
          LEFT JOIN dive_profiles p ON p.dive_id = s.dive_id
          GROUP BY s.dive_id
        ),
        stop_events AS (
          SELECT DISTINCT e.dive_id AS dive_id
          FROM dive_profile_events e
          JOIN scoped s ON s.dive_id = e.dive_id
          WHERE e.event_type = 'decoStopStart'
        )
        SELECT
          sig.dive_id AS dive_id,
          d.updated_at AS updated_at,
          CASE
            WHEN sig.deco_stop = 1 OR ev.dive_id IS NOT NULL THEN 'deco'
            WHEN sig.has_deco_type = 1 THEN 'no_deco'
            WHEN sig.positive_ceiling = 1 THEN 'deco'
            WHEN sig.has_profile = 1 THEN 'compute'
            ELSE 'no_profile'
          END AS classification
        FROM signals sig
        JOIN dives d ON d.id = sig.dive_id
        LEFT JOIN stop_events ev ON ev.dive_id = sig.dive_id
        ''', variables: params.map((p) => Variable(p)).toList()).get();

      final recordedDeco = <String>{};
      final recordedNoDeco = <String>{};
      final needsCompute = <String, int>{};
      final noProfile = <String>{};
      for (final row in results) {
        final id = row.read<String>('dive_id');
        switch (row.read<String>('classification')) {
          case 'deco':
            recordedDeco.add(id);
          case 'no_deco':
            recordedNoDeco.add(id);
          case 'compute':
            needsCompute[id] = row.read<int?>('updated_at') ?? 0;
          default:
            noProfile.add(id);
        }
      }
      return (
        recordedDeco: recordedDeco,
        recordedNoDeco: recordedNoDeco,
        needsCompute: needsCompute,
        noProfile: noProfile,
      );
    } catch (e, stackTrace) {
      _log.error(
        'Failed to scan recorded deco signals',
        error: e,
        stackTrace: stackTrace,
      );
      return (
        recordedDeco: const <String>{},
        recordedNoDeco: const <String>{},
        needsCompute: const <String, int>{},
        noProfile: const <String>{},
      );
    }
  }

  /// Deco obligation counts from recorded data alone.
  ///
  /// Dives needing the computed fallback are reported as unknown here. The
  /// statistics provider composes this with the computed classification
  /// cache; this method is the recorded-only view used by tests and by any
  /// caller that must not trigger analysis work.
  Future<({int decoCount, int noDecoCount, int unknownCount})>
  getDecoObligationStats({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
  }) async {
    final scan = await scanRecordedDecoSignals(
      diverId: diverId,
      filter: filter,
    );
    return (
      decoCount: scan.recordedDeco.length,
      noDecoCount: scan.recordedNoDeco.length,
      unknownCount: scan.needsCompute.length + scan.noProfile.length,
    );
  }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/statistics/data/repositories/statistics_repository_deco_test.dart`
Expected: PASS, 8 tests.

- [ ] **Step 5: Update the provider's type**

In `lib/features/statistics/presentation/providers/statistics_providers.dart`, change the `decoObligationStatsProvider` declaration's type argument only:

```dart
final decoObligationStatsProvider =
    FutureProvider<({int decoCount, int noDecoCount, int unknownCount})>((
      ref,
    ) async {
      _keepAliveWithExpiry(ref);
      final repository = ref.watch(statisticsRepositoryProvider);
      final currentDiverId = ref.watch(currentDiverIdProvider);
      final filter = ref.watch(statisticsFilterProvider);
      return repository.getDecoObligationStats(
        diverId: currentDiverId,
        filter: filter,
      );
    });
```

- [ ] **Step 6: Add the "not recorded" string to English**

In `lib/l10n/arb/app_en.arb`, add alongside the existing `statistics_profile_deco_*` keys (keep the file's alphabetical ordering):

```json
  "statistics_profile_deco_notRecorded": "Not Recorded",
```

And immediately after the existing `"@statistics_profile_deco_semanticLabel"` block, add:

```json
  "statistics_profile_deco_notRecordedHint": "{count} dives have no recorded or computable deco data and are excluded from the rate",
  "@statistics_profile_deco_notRecordedHint": {
    "placeholders": {
      "count": { "type": "int" }
    }
  },
```

- [ ] **Step 7: Translate into every locale**

Add both keys to each of `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`. French, matching the reporter's locale:

```json
  "statistics_profile_deco_notRecorded": "Non enregistré",
  "statistics_profile_deco_notRecordedHint": "{count} plongées n'ont aucune donnée de décompression enregistrée ou calculable et sont exclues du taux",
```

German: `"Nicht erfasst"`. Spanish: `"Sin registrar"`. Italian: `"Non registrato"`. Dutch: `"Niet vastgelegd"`. Portuguese: `"Não registado"`. Hungarian: `"Nincs rögzítve"`. Arabic: `"غير مسجل"`. Hebrew: `"לא נרשם"`. Chinese: `"未记录"`. Translate the hint sentence to match each, keeping the `{count}` placeholder.

- [ ] **Step 8: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: `lib/l10n/arb/app_localizations*.dart` regenerate with the two new getters and no errors.

- [ ] **Step 9: Render the new bucket**

In `lib/features/statistics/presentation/pages/statistics_profile_page.dart`, in `_buildDecoSection`, replace the body of the `data` branch. The rate denominator becomes classified dives only, and the empty state now triggers when nothing at all is classified:

```dart
          final classified = data.decoCount + data.noDecoCount;
          if (classified == 0 && data.unknownCount == 0) {
            return _EmptyChartState(
              message: context.l10n.statistics_profile_deco_empty,
            );
          }
          final percentage = classified == 0
              ? 0.0
              : data.decoCount / classified * 100;
```

Leave the three existing `_buildDecoStat` calls in place, but change the no-deco figure to read `data.noDecoCount.toString()` instead of `(data.totalCount - data.decoCount).toString()`. Then, immediately after the `Row` holding the three stats, add:

```dart
              if (data.unknownCount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  context.l10n.statistics_profile_deco_notRecordedHint(
                    data.unknownCount,
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
```

- [ ] **Step 10: Verify the whole project**

Run: `dart format .` then `flutter analyze` then `flutter test test/features/statistics/`
Expected: format reports no changes, analyze is clean, all statistics tests pass.

- [ ] **Step 11: Commit**

```bash
git add lib/features/statistics test/features/statistics lib/l10n
git commit -m "fix(stats): classify deco obligation from recorded signals correctly

getDecoObligationStats counted any sample with ceiling > 0 as a
decompression obligation. Both profile mappers write ceiling = decoDepth
for any non-zero deco_type, and type 1 is DC_DECO_SAFETYSTOP, so a routine
5 m safety stop was reported as a deco dive.

The same predicate under-counted in the opposite direction: ceiling is
only ever written from computer-reported sample data, and the MacDive,
Shearwater Cloud, generic UDDF, CSV and OCR paths never write it. Those
dives were silently counted as no-deco.

Classification now prefers deco_type = 2 and decoStopStart events, treats
ceiling > 0 as authoritative only for sources that write no deco_type at
all, and reports dives it cannot classify as not recorded instead of
folding them into the no-deco count. The deco rate denominator is now
classified dives only.

Refs #623"
```

---

### Task 2: Computed classification cache

The computed fallback needs somewhere to memoize its answer. Per the local-cache precedent, re-derivable data stays out of the synced main DB: no schema version bump, no HLC, no tombstones, no backup inclusion, and a restored database recomputes rather than importing another device's stale answer.

**Files:**
- Modify: `lib/core/database/local_cache_database.dart:89-206` (table) and `:206-290` (schema version and migration)
- Create: `lib/features/statistics/data/repositories/deco_classification_cache.dart`
- Test: `test/features/statistics/data/repositories/deco_classification_cache_test.dart` (create)

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces:
  - Drift table `DecoClassificationCache` with columns `diveId` (text, primary key), `hadDeco` (bool), `inputsHash` (text), `computedAt` (int).
  - `class DecoClassificationCacheRepository` with:
    - `Future<Map<String, bool>> getValid(Set<String> diveIds, String inputsHash)`
    - `Future<void> put(String diveId, {required bool hadDeco, required String inputsHash})`
    - `Future<void> clear()`

- [ ] **Step 1: Write the failing test**

Create `test/features/statistics/data/repositories/deco_classification_cache_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/statistics/data/repositories/deco_classification_cache.dart';

void main() {
  late LocalCacheDatabase db;
  late DecoClassificationCacheRepository repo;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    LocalCacheDatabaseService.instance.setTestDatabase(db);
    repo = DecoClassificationCacheRepository();
  });

  tearDown(() async {
    await db.close();
    LocalCacheDatabaseService.instance.resetForTesting();
  });

  test('returns nothing before anything is cached', () async {
    expect(await repo.getValid({'a', 'b'}, 'hash-1'), isEmpty);
  });

  test('round-trips a classification', () async {
    await repo.put('a', hadDeco: true, inputsHash: 'hash-1');
    await repo.put('b', hadDeco: false, inputsHash: 'hash-1');

    expect(await repo.getValid({'a', 'b'}, 'hash-1'), {'a': true, 'b': false});
  });

  test('a stale inputs hash invalidates the entry', () async {
    await repo.put('a', hadDeco: true, inputsHash: 'hash-1');

    expect(await repo.getValid({'a'}, 'hash-2'), isEmpty);
  });

  test('re-putting the same dive replaces the entry', () async {
    await repo.put('a', hadDeco: true, inputsHash: 'hash-1');
    await repo.put('a', hadDeco: false, inputsHash: 'hash-2');

    expect(await repo.getValid({'a'}, 'hash-1'), isEmpty);
    expect(await repo.getValid({'a'}, 'hash-2'), {'a': false});
  });

  test('only the requested dives come back', () async {
    await repo.put('a', hadDeco: true, inputsHash: 'hash-1');
    await repo.put('b', hadDeco: true, inputsHash: 'hash-1');

    expect(await repo.getValid({'a'}, 'hash-1'), {'a': true});
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/statistics/data/repositories/deco_classification_cache_test.dart`
Expected: FAIL, `deco_classification_cache.dart` does not exist.

- [ ] **Step 3: Add the table**

In `lib/core/database/local_cache_database.dart`, add after the `ReefDataCache` class:

```dart
/// Memoized result of the computed decompression-obligation classification
/// for one dive (issue #623).
///
/// Local-only by construction: every device can re-derive this from the dive
/// profile it already holds, so it carries no HLC, is never synced, and is
/// never backed up. A restored database recomputes rather than inheriting
/// another device's answer, which may have been produced under different
/// gradient factors.
class DecoClassificationCache extends Table {
  TextColumn get diveId => text()();

  /// Whether the app's own analysis put the diver into decompression.
  BoolColumn get hadDeco => boolean()();

  /// Fingerprint of every input that can change the answer: engine version,
  /// the gradient factors actually used, and the dive's profile revision.
  /// A mismatch means recompute.
  TextColumn get inputsHash => text()();

  IntColumn get computedAt => integer()();

  @override
  Set<Column> get primaryKey => {diveId};
}
```

Add `DecoClassificationCache` to the `@DriftDatabase(tables: [...])` annotation's table list, bump `schemaVersion` from `12` to `13`, and add the migration step after the existing `if (from < 12)` block:

```dart
      if (from < 13) {
        await m.createTable(decoClassificationCache);
      }
```

Then add the idempotent self-heal inside `beforeOpen`, alongside the existing `CREATE TABLE IF NOT EXISTS` assertions, so a parallel branch that also claims v13 cannot leave the table missing:

```dart
      await customStatement('''
        CREATE TABLE IF NOT EXISTS deco_classification_cache (
          dive_id TEXT NOT NULL,
          had_deco INTEGER NOT NULL,
          inputs_hash TEXT NOT NULL,
          computed_at INTEGER NOT NULL,
          PRIMARY KEY (dive_id)
        )
      ''');
```

- [ ] **Step 4: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `local_cache_database.g.dart` gains `DecoClassificationCache` and `decoClassificationCache`.

- [ ] **Step 5: Write the repository**

Create `lib/features/statistics/data/repositories/deco_classification_cache.dart`:

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';

/// Read/write access to the memoized computed deco classifications.
///
/// Entries are only valid for the [inputsHash] they were written under, so a
/// changed profile, a changed gradient factor, or a bumped analysis engine
/// invalidates them without needing an explicit purge.
class DecoClassificationCacheRepository {
  DecoClassificationCacheRepository({LocalCacheDatabase? database})
    : _database = database;

  final LocalCacheDatabase? _database;

  LocalCacheDatabase get _db =>
      _database ?? LocalCacheDatabaseService.instance.database;

  /// The cached classifications for [diveIds] that were computed under
  /// [inputsHash]. Dives that are absent or stale are simply missing from the
  /// result, which is what marks them as needing recomputation.
  Future<Map<String, bool>> getValid(
    Set<String> diveIds,
    String inputsHash,
  ) async {
    if (diveIds.isEmpty) return const {};
    final rows =
        await (_db.select(_db.decoClassificationCache)..where(
              (t) =>
                  t.diveId.isIn(diveIds) & t.inputsHash.equals(inputsHash),
            ))
            .get();
    return {for (final row in rows) row.diveId: row.hadDeco};
  }

  Future<void> put(
    String diveId, {
    required bool hadDeco,
    required String inputsHash,
  }) async {
    await _db
        .into(_db.decoClassificationCache)
        .insertOnConflictUpdate(
          DecoClassificationCacheCompanion(
            diveId: Value(diveId),
            hadDeco: Value(hadDeco),
            inputsHash: Value(inputsHash),
            computedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
  }

  Future<void> clear() async {
    await _db.delete(_db.decoClassificationCache).go();
  }
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/features/statistics/data/repositories/deco_classification_cache_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 7: Verify and commit**

Run: `dart format .` then `flutter analyze`

```bash
git add lib/core/database lib/features/statistics/data/repositories test/features/statistics
git commit -m "feat(stats): add local cache for computed deco classification

Local cache DB v13. Computed deco answers are re-derivable from data every
device already holds, so they stay out of the synced main DB: no schema
version bump there, no HLC, no tombstones, no backup inclusion. Entries are
keyed by an inputs fingerprint so a changed profile or changed gradient
factors invalidate without an explicit purge.

Refs #623"
```

---

### Task 3: Computed classification service

**Files:**
- Create: `lib/features/statistics/data/services/deco_classification_service.dart`
- Test: `test/features/statistics/data/services/deco_classification_service_test.dart` (create)

**Interfaces:**
- Consumes: `DecoClassificationCacheRepository` from Task 2.
- Produces:
  - `String decoInputsHash({required int engineVersion, required int gfLow, required int gfHigh, required int diveUpdatedAt})`
  - `class DecoClassificationService` with
    `Future<Map<String, bool>> classify(Ref ref, Set<String> diveIds, {int chunkSize = 25})`

- [ ] **Step 1: Write the failing test for the fingerprint**

Create `test/features/statistics/data/services/deco_classification_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/statistics/data/services/deco_classification_service.dart';

void main() {
  group('decoInputsHash', () {
    test('is stable for identical inputs', () {
      final a = decoInputsHash(
        engineVersion: 3,
        gfLow: 50,
        gfHigh: 85,
        diveUpdatedAt: 1000,
      );
      final b = decoInputsHash(
        engineVersion: 3,
        gfLow: 50,
        gfHigh: 85,
        diveUpdatedAt: 1000,
      );
      expect(a, b);
    });

    test('changes when a gradient factor changes', () {
      final a = decoInputsHash(
        engineVersion: 3,
        gfLow: 50,
        gfHigh: 85,
        diveUpdatedAt: 1000,
      );
      final b = decoInputsHash(
        engineVersion: 3,
        gfLow: 50,
        gfHigh: 80,
        diveUpdatedAt: 1000,
      );
      expect(a, isNot(b));
    });

    test('changes when the dive is edited', () {
      final a = decoInputsHash(
        engineVersion: 3,
        gfLow: 50,
        gfHigh: 85,
        diveUpdatedAt: 1000,
      );
      final b = decoInputsHash(
        engineVersion: 3,
        gfLow: 50,
        gfHigh: 85,
        diveUpdatedAt: 2000,
      );
      expect(a, isNot(b));
    });

    test('changes when the analysis engine is bumped', () {
      final a = decoInputsHash(
        engineVersion: 3,
        gfLow: 50,
        gfHigh: 85,
        diveUpdatedAt: 1000,
      );
      final b = decoInputsHash(
        engineVersion: 4,
        gfLow: 50,
        gfHigh: 85,
        diveUpdatedAt: 1000,
      );
      expect(a, isNot(b));
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/statistics/data/services/deco_classification_service_test.dart`
Expected: FAIL, the file does not exist.

- [ ] **Step 3: Write the service**

Create `lib/features/statistics/data/services/deco_classification_service.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/logger.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/statistics/data/repositories/deco_classification_cache.dart';

final _log = Logger('DecoClassificationService');

/// Fingerprint of every input that can change a computed classification.
///
/// Kept deliberately coarse: the dive's `updatedAt` moves whenever the dive
/// row or its profile is written, so it stands in for a profile revision
/// without hashing the samples themselves.
String decoInputsHash({
  required int engineVersion,
  required int gfLow,
  required int gfHigh,
  required int diveUpdatedAt,
}) => 'v$engineVersion/$gfLow-$gfHigh/$diveUpdatedAt';

/// Classifies dives that carry no recorded deco signal by running the same
/// analysis the dive detail page runs.
///
/// Reading [profileAnalysisProvider] rather than reimplementing the deco test
/// is the point of the exercise: issue #623 was the statistics card and the
/// dive page answering the same question from different layers, and a second
/// implementation would let them drift apart again.
class DecoClassificationService {
  const DecoClassificationService();

  /// Returns `diveId -> hadDeco` for every dive in [diveIds] the analysis
  /// could classify. Dives whose analysis yields nothing (no usable profile)
  /// are absent from the result and stay unclassified.
  ///
  /// Processes in chunks and invalidates each dive's analysis afterwards:
  /// [profileAnalysisProvider] and [analysisDiveProvider] are keepAlive
  /// families, so a library-wide pass would otherwise retain every profile's
  /// curves for the session.
  /// [revisions] maps dive id to that dive's `dives.updated_at`, as returned
  /// by `StatisticsRepository.scanRecordedDecoSignals`.
  Future<Map<String, bool>> classify(
    Ref ref,
    Map<String, int> revisions, {
    int chunkSize = 25,
  }) async {
    if (revisions.isEmpty) return const {};

    // The analysis uses the dive's own gradient factors when it has both,
    // and the diver's settings otherwise, so both feed the fingerprint.
    final settingsGfLow = ref.read(gfLowProvider);
    final settingsGfHigh = ref.read(gfHighProvider);

    final cache = DecoClassificationCacheRepository();
    final results = <String, bool>{};
    final pending = revisions.keys.toList(growable: false);

    for (var start = 0; start < pending.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, pending.length);
      for (final diveId in pending.sublist(start, end)) {
        var analysisRead = false;
        try {
          final dive = await ref.read(analysisDiveProvider(diveId).future);
          if (dive == null) continue;

          final hash = decoInputsHash(
            engineVersion: analysisEngineVersion,
            gfLow: dive.gradientFactorLow ?? settingsGfLow,
            gfHigh: dive.gradientFactorHigh ?? settingsGfHigh,
            diveUpdatedAt: revisions[diveId]!,
          );

          final cached = await cache.getValid({diveId}, hash);
          final hit = cached[diveId];
          if (hit != null) {
            results[diveId] = hit;
            continue;
          }

          analysisRead = true;
          final analysis = await ref.read(
            profileAnalysisProvider(diveId).future,
          );
          if (analysis == null || analysis.ndlCurve.isEmpty) continue;

          final hadDeco = analysis.hadDecoObligation;
          results[diveId] = hadDeco;
          await cache.put(diveId, hadDeco: hadDeco, inputsHash: hash);
        } catch (e, stackTrace) {
          _log.error(
            'Failed to classify deco obligation for dive $diveId',
            error: e,
            stackTrace: stackTrace,
          );
        } finally {
          if (analysisRead) ref.invalidate(profileAnalysisProvider(diveId));
          ref.invalidate(analysisDiveProvider(diveId));
        }
      }
    }
    return results;
  }
}
```

`analysisEngineVersion` does not exist yet. Add it to
`lib/features/dive_log/data/services/profile_analysis_service.dart` as a
top-level `const int analysisEngineVersion = 1;` and bump it whenever the
deco computation changes. `gfLowProvider` and `gfHighProvider` come from
`lib/features/settings/presentation/providers/settings_providers.dart` and
default to 50 and 85. `Dive.gradientFactorLow` and `Dive.gradientFactorHigh`
are `int?` (`dive.dart:88-89`); the `Dive` entity has no `updatedAt`, which
is why the revision arrives from the scan instead.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/statistics/data/services/deco_classification_service_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Verify and commit**

Run: `dart format .` then `flutter analyze`

```bash
git add lib/features/statistics/data/services lib/features/dive_log/data/services test/features/statistics/data/services
git commit -m "feat(stats): compute deco classification via the dive analysis

Reads profileAnalysisProvider rather than reimplementing the deco test, so
the statistics card and the dive detail page can never disagree again.
Chunked with per-dive invalidation because both analysis providers are
keepAlive families.

Refs #623"
```

---

### Task 4: Compose recorded and computed classification in the provider

**Files:**
- Modify: `lib/features/statistics/presentation/providers/statistics_providers.dart:498-508`
- Test: `test/features/statistics/presentation/providers/deco_obligation_provider_test.dart` (create)

**Interfaces:**
- Consumes: `scanRecordedDecoSignals` (Task 1), `DecoClassificationCacheRepository` (Task 2), `DecoClassificationService` (Task 3).
- Produces: `decoObligationStatsProvider` yielding `({int decoCount, int noDecoCount, int unknownCount})` with the computed fallback applied.

- [ ] **Step 1: Write the failing test**

Create `test/features/statistics/presentation/providers/deco_obligation_provider_test.dart`. Build a dive whose profile has no `deco_type` and no `ceiling` but is deep and long enough that Buhlmann puts it into deco, plus a shallow dive that stays within NDL. Assert the provider reports one deco dive and one no-deco dive, with `unknownCount` zero. Use the same `setUpTestDatabase` helper as the repository tests and a `ProviderContainer` for the provider read.

Do not guess the fixture depths and durations. Write the two profiles, run `ProfileAnalysisService` over each directly in a scratch test, and confirm one yields `hadDecoObligation == true` and the other `false` at the default GF 50/85 before asserting on the provider. A fixture that silently sits on the wrong side of the NDL boundary makes the test assert nothing.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/statistics/presentation/providers/deco_obligation_provider_test.dart`
Expected: FAIL, the provider reports both dives as unknown because the computed fallback is not wired in.

- [ ] **Step 3: Wire the fallback into the provider**

Replace `decoObligationStatsProvider` in `lib/features/statistics/presentation/providers/statistics_providers.dart`:

```dart
/// Deco obligation counts, recorded signals first and the app's own analysis
/// as the fallback (#623).
///
/// Cached computed answers are read up front so a warm library costs one
/// extra indexed SELECT. Only genuinely uncached dives run the analysis.
final decoObligationStatsProvider =
    FutureProvider<({int decoCount, int noDecoCount, int unknownCount})>((
      ref,
    ) async {
      _keepAliveWithExpiry(ref);
      final repository = ref.watch(statisticsRepositoryProvider);
      final currentDiverId = ref.watch(currentDiverIdProvider);
      final filter = ref.watch(statisticsFilterProvider);

      final scan = await repository.scanRecordedDecoSignals(
        diverId: currentDiverId,
        filter: filter,
      );

      var deco = scan.recordedDeco.length;
      var noDeco = scan.recordedNoDeco.length;
      var unknown = scan.noProfile.length;

      final computed = await const DecoClassificationService().classify(
        ref,
        scan.needsCompute,
      );
      for (final diveId in scan.needsCompute.keys) {
        final hadDeco = computed[diveId];
        if (hadDeco == null) {
          unknown++;
        } else if (hadDeco) {
          deco++;
        } else {
          noDeco++;
        }
      }

      return (decoCount: deco, noDecoCount: noDeco, unknownCount: unknown);
    });
```

`classify` already consults the cache per dive before computing, so a warm library does no analysis work at all.

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/statistics/presentation/providers/deco_obligation_provider_test.dart`
Expected: PASS.

- [ ] **Step 5: Verify and commit**

Run: `dart format .` then `flutter analyze` then `flutter test test/features/statistics/`

```bash
git add lib/features/statistics test/features/statistics
git commit -m "fix(stats): fall back to computed deco for dives with no recorded data

The Decompression Obligation card now agrees with the DECO badge on the
dive detail page. Dives whose source records no deco columns are classified
by the app's own analysis instead of being counted as no-deco.

Fixes #623"
```

---

### Task 5: End-to-end verification against the reported scenario

**Files:**
- Test: `test/features/statistics/deco_obligation_regression_test.dart` (create)

**Interfaces:**
- Consumes: everything above.
- Produces: nothing.

- [ ] **Step 1: Write the regression test**

Create `test/features/statistics/deco_obligation_regression_test.dart` reproducing issue #623: a library of dives whose profiles carry depth and temperature only, with no `deco_type`, no `ceiling`, and no deco events, where several profiles are deep and long enough to incur a genuine obligation. Assert that the card reports a non-zero deco count and a non-zero rate, and that the count matches the number of dives for which `ProfileAnalysis.hadDecoObligation` is true. Derive that expected count by running the analysis in the test rather than hard-coding a number, so the assertion cannot drift from the engine. Name the test after the issue so the intent survives.

- [ ] **Step 2: Run it to verify it passes**

Run: `flutter test test/features/statistics/deco_obligation_regression_test.dart`
Expected: PASS.

- [ ] **Step 3: Run the full suite**

Run: `flutter test`
Expected: PASS. Two pre-existing flakes are known and unrelated to this change: two `split('-')` recovery-code tests, and a security-settings recovery dialog where Argon2id outruns `settle()`. Do not chase them. Never pipe the run through `tail`, which masks the exit code.

- [ ] **Step 4: Verify formatting and analysis project-wide**

Run: `dart format .` then `flutter analyze`
Expected: no changes, no findings.

- [ ] **Step 5: Commit**

```bash
git add test/features/statistics
git commit -m "test(stats): regression cover for the #623 deco obligation report

Refs #623"
```

---

## Follow-up issues

Both were found during the #623 investigation, are real, and were deliberately out of scope here. Filed 2026-08-18:

1. **#1148**: `getTimeAtDepthRanges` counts profile rows and divides by 60, assuming 1 Hz sampling. At a 4-5 s sample interval the card understates time at depth by that factor. It also omits the `is_primary` filter, so a dive logged by two computers is double-counted.
2. **#1149**: `setPrimaryDataSource` (`dive_repository_impl.dart:5877-5891`) demotes every `dive_profiles` row for a dive, then re-promotes only rows whose `computer_id` matches `newPrimary.computerId`, and only when that id is non-null. File-imported dives have a null `computerId` on both the data source row and the profile rows, so nothing is re-promoted and the dive ends up with no primary profile. Any query gated on `is_primary = 1`, including the ascent/descent rates card, then silently skips that dive.
