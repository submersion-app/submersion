import 'dart:math';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/data_quality/data/services/quality_neighbor_sql.dart';
import 'package:submersion/features/data_quality/data/services/quality_prefilters.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';
import 'package:submersion/features/equipment/data/repositories/dive_gear_usage_sql.dart';

import '../../../helpers/test_database.dart';

/// The all-pairs queries these replaced (issue #3863), kept as the definition
/// of correct pair membership: bounded range joins may be faster, never
/// different.
const _allPairsSameDiverSql =
    'SELECT DISTINCT a.id AS id FROM dives a JOIN dives b ON a.id != b.id '
    'AND a.diver_id IS b.diver_id '
    'AND ABS(COALESCE(a.entry_time, a.dive_date_time) - '
    'COALESCE(b.entry_time, b.dive_date_time)) <= ?1';

String _allPairsExpandSql(int idCount, int windowMs) {
  final placeholders = List.filled(idCount, '?').join(',');
  return 'SELECT DISTINCT b.id AS id FROM dives a JOIN dives b '
      'ON b.id != a.id AND a.diver_id IS b.diver_id '
      'AND ABS(COALESCE(a.entry_time, a.dive_date_time) - '
      'COALESCE(b.entry_time, b.dive_date_time)) <= $windowMs '
      'WHERE a.id IN ($placeholders)';
}

String _allPairsSharedGearSql() =>
    'SELECT DISTINCT da.id AS id FROM dives da '
    'JOIN dives db ON db.id != da.id '
    'AND da.diver_id IS NOT NULL AND db.diver_id IS NOT NULL '
    'AND da.diver_id != db.diver_id '
    'AND ABS(COALESCE(da.entry_time, da.dive_date_time) - '
    'COALESCE(db.entry_time, db.dive_date_time)) <= ?1 '
    'WHERE EXISTS (SELECT 1 FROM '
    '(${diveGearUsageSql(diveIdPredicate: '= da.id')}) ga '
    'JOIN (${diveGearUsageSql(diveIdPredicate: '= db.id')}) gb '
    'ON gb.equipment_id = ga.equipment_id)';

/// Records which dives a scan built a context for and flags none of them.
class _RecordingDetector extends QualityDetector {
  _RecordingDetector();
  final seen = <String>{};
  @override
  String get id => 'recording';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.time;
  @override
  List<QualityFinding> detect(DiveQualityContext context) {
    seen.add(context.dive.id);
    return const [];
  }
}

void main() {
  final windowMs = QualityThresholds.neighborWindow.inMilliseconds;
  final base = DateTime.utc(2026, 5, 1, 10).millisecondsSinceEpoch;
  late AppDatabase db;

  setUp(() async {
    await setUpTestDatabase();
    db = DatabaseService.instance.database;
    for (final id in ['bill', 'anna']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  Future<void> seed(
    String id, {
    required int at,
    int? entry,
    String? diver,
    String? gear,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diverId: Value(diver),
            diveDateTime: at,
            entryTime: Value(entry),
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    if (gear != null) {
      await db
          .into(db.diveEquipment)
          .insert(DiveEquipmentCompanion.insert(diveId: id, equipmentId: gear));
    }
  }

  Future<Set<String>> selectIds(
    String sql, [
    List<Variable> variables = const [],
  ]) async {
    final rows = await db.customSelect(sql, variables: variables).get();
    return {for (final r in rows) r.read<String>('id')};
  }

  Future<Set<String>> pairCandidates() async =>
      (await QualityPrefilters().candidatesByDetector())['duplicate']!;

  group('same-diver pair window', () {
    test(
      'includes dives exactly one window apart, excludes one ms more',
      () async {
        await seed('edge-a', at: base);
        await seed('edge-b', at: base + windowMs);
        await seed('past-a', at: base + 100 * windowMs);
        await seed('past-b', at: base + 101 * windowMs + 1);
        expect(await pairCandidates(), {'edge-a', 'edge-b'});
      },
    );

    test('pairs two dives that start at the same instant', () async {
      await seed('tie-a', at: base);
      await seed('tie-b', at: base);
      expect(await pairCandidates(), {'tie-a', 'tie-b'});
    });

    test('a dive is never its own neighbor', () async {
      await seed('alone', at: base);
      expect(await pairCandidates(), isEmpty);
    });

    test('reads entry_time first and falls back to dive_date_time', () async {
      // entry_time wins, so the dive date being a year away is irrelevant.
      await seed('entry', at: base + 730 * windowMs, entry: base);
      // No entry_time: the dive date is the start.
      await seed('fallback', at: base + windowMs);
      // Its date is in range, but its entry_time is not.
      await seed('far', at: base, entry: base + 730 * windowMs);
      expect(await pairCandidates(), {'entry', 'fallback'});
    });

    test('unassigned dives pair with each other but never with a '
        'diver, and different divers never pair', () async {
      await seed('null-a', at: base);
      await seed('null-b', at: base + 1);
      await seed('bill-1', at: base + 100 * windowMs, diver: 'bill');
      await seed('anna-1', at: base + 100 * windowMs, diver: 'anna');
      await seed('null-c', at: base + 200 * windowMs);
      await seed('bill-2', at: base + 200 * windowMs, diver: 'bill');
      expect(await pairCandidates(), {'null-a', 'null-b'});
    });
  });

  group('matches the all-pairs queries', () {
    // Boundary-heavy on purpose: starts land on, one ms inside and one ms
    // outside multiples of the window, across NULL and real divers, with a
    // decoy dive date on every dive that has an entry time.
    Future<List<String>> seedRandomLibrary() async {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: 'light',
              name: 'light',
              type: 'light',
              createdAt: 1,
              updatedAt: 1,
            ),
          );
      final random = Random(3863);
      final ids = <String>[];
      for (var i = 0; i < 160; i++) {
        final start =
            base + random.nextInt(24) * windowMs + random.nextInt(3) - 1;
        final hasEntry = random.nextBool();
        final id = 'd$i';
        ids.add(id);
        await seed(
          id,
          at: hasEntry ? base + random.nextInt(24) * windowMs : start,
          entry: hasEntry ? start : null,
          diver: const [null, 'bill', 'anna'][random.nextInt(3)],
          gear: random.nextBool() ? 'light' : null,
        );
      }
      return ids;
    }

    test('for the same-diver and shared-gear candidates', () async {
      await seedRandomLibrary();
      final window = [Variable.withInt(windowMs)];
      final candidates = await QualityPrefilters().candidatesByDetector();
      final expectedPairs = await selectIds(_allPairsSameDiverSql, window);
      final expectedGear = await selectIds(_allPairsSharedGearSql(), window);
      // Guards the fixture: a library with nothing to find proves nothing.
      expect(expectedPairs, isNotEmpty);
      expect(expectedPairs.length, lessThan(160));
      expect(expectedGear, isNotEmpty);
      expect(candidates['duplicate'], expectedPairs);
      expect(candidates['split_pair'], expectedPairs);
      expect(candidates['shared_gear_overlap'], expectedGear);
    });

    test('for targeted neighbor expansion', () async {
      final ids = await seedRandomLibrary();
      final requested = ids.take(25).toList();
      final variables = [for (final id in requested) Variable.withString(id)];
      final expected = await selectIds(
        _allPairsExpandSql(requested.length, windowMs),
        variables,
      );
      expect(expected, isNotEmpty);
      expect(
        await selectIds(
          qualityExpandNeighborsSql(requested.length, windowMs),
          variables,
        ),
        expected,
      );
    });
  });

  test('a targeted scan builds the requested dives and their neighbors, '
      'not the rest of the library', () async {
    await seed('asked', at: base);
    await seed('in-window', at: base + windowMs);
    await seed('out-of-window', at: base + windowMs * 3);
    await seed('other-diver', at: base, diver: 'bill');
    final detector = _RecordingDetector();
    await QualityScanService(detectors: [detector]).scanDives({'asked'});
    expect(detector.seen, {'asked', 'in-window'});
  });
}
