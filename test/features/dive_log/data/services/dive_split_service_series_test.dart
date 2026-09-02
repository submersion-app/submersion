import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/dive_split_service.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveSplitService service;
  late ProfileSeriesRepository profileSeries;
  late TankPressureSeriesRepository tankSeries;

  final baseTime = DateTime.utc(2026, 5, 7, 14, 6).millisecondsSinceEpoch;

  Future<void> insertComputer(String id, String name) async {
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value(name),
            createdAt: Value(baseTime),
            updatedAt: Value(baseTime),
          ),
        );
  }

  Future<void> insertDive(String id, {String? computerId}) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(baseTime),
            computerId: Value(computerId),
            entryTime: Value(baseTime),
            exitTime: Value(baseTime + 56 * 60 * 1000),
            maxDepth: const Value(21.7),
            createdAt: Value(baseTime),
            updatedAt: Value(baseTime),
          ),
        );
  }

  Future<void> insertSource(
    String id,
    String diveId,
    String? computerId, {
    required bool isPrimary,
    double? maxDepth,
    DateTime? createdAt,
  }) async {
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            maxDepth: Value(maxDepth),
            importedAt: Value(createdAt ?? DateTime.utc(2026, 1, 1)),
            createdAt: Value(createdAt ?? DateTime.utc(2026, 1, 1)),
          ),
        );
  }

  var rowCounter = 0;
  Future<String> insertTank(String diveId, String? computerId) async {
    final id = 'tank-${rowCounter++}';
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value(id),
            diveId: Value(diveId),
            computerId: Value(computerId),
            tankOrder: const Value(0),
          ),
        );
    return id;
  }

  setUp(() async {
    db = await setUpTestDatabase();
    service = DiveSplitService(DiveRepository());
    profileSeries = ProfileSeriesRepository();
    tankSeries = TankPressureSeriesRepository();
    rowCounter = 0;
    await insertComputer('comp-a', 'A');
    await insertComputer('comp-b', 'B');
    await insertDive('dive-1', computerId: 'comp-a');
    await insertSource(
      'src-a',
      'dive-1',
      'comp-a',
      isPrimary: true,
      createdAt: DateTime.utc(2026, 1, 1),
    );
    await insertSource(
      'src-b',
      'dive-1',
      'comp-b',
      isPrimary: false,
      createdAt: DateTime.utc(2026, 1, 2),
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<String> sourceIdOf(String diveId) async => (await (db.select(
    db.diveDataSources,
  )..where((t) => t.diveId.equals(diveId))).getSingle()).id;

  test('splitting the primary source moves its series and its null-computer '
      'family to the new dive', () async {
    final a1 = await profileSeries.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-a',
      sourceId: 'src-a',
      samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
      now: 1000,
    );
    final b1 = await profileSeries.insertSeries(
      diveId: 'dive-1',
      computerId: 'comp-b',
      sourceId: 'src-b',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
      now: 1000,
    );
    final e = await profileSeries.insertSeries(
      diveId: 'dive-1',
      sourceId: 'src-a',
      isPrimary: false,
      samples: const [ProfileSample(timestamp: 0, depth: 3.0)],
      now: 1000,
    );
    final ta = await insertTank('dive-1', 'comp-a');
    final tb = await insertTank('dive-1', 'comp-b');
    final pa = await tankSeries.insertSeries(
      diveId: 'dive-1',
      tankId: ta,
      computerId: 'comp-a',
      samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
      now: 1000,
    );
    final pb = await tankSeries.insertSeries(
      diveId: 'dive-1',
      tankId: tb,
      computerId: 'comp-b',
      samples: const [TankPressureSample(timestamp: 0, pressure: 100.0)],
      now: 1000,
    );

    final newDiveId = await service.split(diveId: 'dive-1', sourceId: 'src-a');

    final newSourceId = await sourceIdOf(newDiveId);
    final moved = await profileSeries.getSeriesForDive(newDiveId);
    expect(moved.map((s) => s.samples.single.depth).toSet(), {1.0, 3.0});
    expect(moved.every((s) => s.sourceId == newSourceId), isTrue);
    expect(
      moved.firstWhere((s) => s.samples.single.depth == 1.0).isPrimary,
      isTrue,
    );
    expect(
      moved.firstWhere((s) => s.samples.single.depth == 3.0).isPrimary,
      isFalse,
    );
    final left = await profileSeries.getSeriesForDive('dive-1');
    expect(left.map((s) => s.id), [b1]);
    expect(left.single.isPrimary, isTrue, reason: 'promote-after-split');
    final movedTanks = await tankSeries.getSeriesForDive(newDiveId);
    expect(movedTanks.single.samples.single.pressure, 200.0);
    expect(
      movedTanks.single.tankId,
      isNot(ta),
      reason: 'the tank was cloned under a fresh id',
    );
    expect((await tankSeries.getSeriesForDive('dive-1')).single.id, pb);
    final tombstones = await db.select(db.deletionLog).get();
    expect(
      tombstones
          .where((t) => t.entityType == 'diveProfileSeries')
          .map((t) => t.recordId)
          .toSet(),
      {a1, e},
    );
    expect(
      tombstones
          .where((t) => t.entityType == 'tankPressureSeries')
          .map((t) => t.recordId),
      [pa],
    );
    expect(
      tombstones.any(
        (t) =>
            t.entityType == 'diveProfiles' ||
            t.entityType == 'tankPressureProfiles',
      ),
      isFalse,
    );
  });

  test(
    'splitting a non-primary source promotes its series in the new dive',
    () async {
      await profileSeries.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-a',
        sourceId: 'src-a',
        samples: const [ProfileSample(timestamp: 0, depth: 1.0)],
        now: 1000,
      );
      final b1 = await profileSeries.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-b',
        sourceId: 'src-b',
        isPrimary: false,
        samples: const [ProfileSample(timestamp: 0, depth: 2.0)],
        now: 1000,
      );

      final newDiveId = await service.split(
        diveId: 'dive-1',
        sourceId: 'src-b',
      );

      final moved = (await profileSeries.getSeriesForDive(newDiveId)).single;
      expect(moved.samples.single.depth, 2.0);
      expect(moved.isPrimary, isTrue);
      expect(moved.computerId, 'comp-b');
      expect(moved.sourceId, await sourceIdOf(newDiveId));
      expect(
        (await profileSeries.getSeriesForDive('dive-1')).single.isPrimary,
        isTrue,
      );
      expect(
        (await db.select(db.deletionLog).get())
            .where((t) => t.entityType == 'diveProfileSeries')
            .map((t) => t.recordId),
        [b1],
      );
    },
  );
}
