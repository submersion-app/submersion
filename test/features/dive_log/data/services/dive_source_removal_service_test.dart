import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/change_log/data/services/change_log_operation_undo.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/dive_source_removal_service.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/tank_shared_computers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveSourceRemovalService service;
  late ProfileSeriesRepository profileSeries;
  late TankPressureSeriesRepository tankSeries;

  final baseTime = DateTime.utc(2026, 5, 7, 14, 6).millisecondsSinceEpoch;
  var rowCounter = 0;

  Future<void> insertComputer(String id) => db
      .into(db.diveComputers)
      .insert(
        DiveComputersCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: Value(baseTime),
          updatedAt: Value(baseTime),
        ),
      );

  Future<void> insertDive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(baseTime),
          computerId: const Value('dc-a'),
          diveNumber: const Value(7),
          notes: const Value('Calm, two computers'),
          maxDepth: const Value(21.7),
          createdAt: Value(baseTime),
          updatedAt: Value(baseTime),
        ),
      );

  Future<void> insertSource(
    String id,
    String? computerId, {
    required bool isPrimary,
    required int createdDay,
    int offsetSeconds = 0,
  }) => db
      .into(db.diveDataSources)
      .insert(
        DiveDataSourcesCompanion(
          id: Value(id),
          diveId: const Value('dive-1'),
          computerId: Value(computerId),
          isPrimary: Value(isPrimary),
          timeOffsetSeconds: Value(offsetSeconds),
          importedAt: Value(DateTime.utc(2026, 1, createdDay)),
          createdAt: Value(DateTime.utc(2026, 1, createdDay)),
        ),
      );

  Future<String> insertProfile(
    String? computerId, {
    required bool isPrimary,
    String? sourceId,
    int timestamp = 0,
  }) => profileSeries.insertSeries(
    diveId: 'dive-1',
    computerId: computerId,
    sourceId: sourceId,
    isPrimary: isPrimary,
    samples: [ProfileSample(timestamp: timestamp, depth: 10.0)],
    now: 1000,
  );

  Future<String> insertTank(
    String? computerId, {
    List<String>? sharedWith,
  }) async {
    final id = 'tank-${rowCounter++}';
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value(id),
            diveId: const Value('dive-1'),
            computerId: Value(computerId),
            sharedComputerIds: Value(
              sharedWith == null ? null : encodeSharedComputerIds(sharedWith),
            ),
          ),
        );
    return id;
  }

  Future<String> insertPressure(String tankId, String? computerId) =>
      tankSeries.insertSeries(
        diveId: 'dive-1',
        tankId: tankId,
        computerId: computerId,
        samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
        now: 1000,
      );

  Future<String> insertEvent(String? computerId) async {
    final id = 'ev-${rowCounter++}';
    await db
        .into(db.diveProfileEvents)
        .insert(
          DiveProfileEventsCompanion(
            id: Value(id),
            diveId: const Value('dive-1'),
            computerId: Value(computerId),
            timestamp: const Value(30),
            eventType: const Value('bookmark'),
            createdAt: Value(baseTime),
          ),
        );
    return id;
  }

  Future<List<String>> fkViolations() async {
    final rows = await db.customSelect('PRAGMA foreign_key_check').get();
    return rows.map((r) => r.data.toString()).toList();
  }

  Future<Set<String>> ids(TableInfo<Table, Object?> table) async {
    final rows = await db
        .customSelect('SELECT id FROM ${table.actualTableName}')
        .get();
    return {for (final r in rows) r.read<String>('id')};
  }

  /// A dive recorded by dc-a (primary) and dc-b, each with a profile, a tank
  /// with a pressure series, and an event.
  Future<
    ({
      String profileA,
      String profileB,
      String tankA,
      String tankB,
      String pressureB,
      String eventB,
    })
  >
  twoComputerDive({int offsetB = 0}) async {
    await insertDive('dive-1');
    await insertSource('src-a', 'dc-a', isPrimary: true, createdDay: 1);
    await insertSource(
      'src-b',
      'dc-b',
      isPrimary: false,
      createdDay: 2,
      offsetSeconds: offsetB,
    );
    final profileA = await insertProfile('dc-a', isPrimary: true);
    final profileB = await insertProfile(
      'dc-b',
      isPrimary: false,
      timestamp: offsetB,
    );
    final tankA = await insertTank('dc-a');
    final tankB = await insertTank('dc-b');
    await insertPressure(tankA, 'dc-a');
    final pressureB = await insertPressure(tankB, 'dc-b');
    await insertEvent('dc-a');
    final eventB = await insertEvent('dc-b');
    return (
      profileA: profileA,
      profileB: profileB,
      tankA: tankA,
      tankB: tankB,
      pressureB: pressureB,
      eventB: eventB,
    );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    service = DiveSourceRemovalService();
    profileSeries = ProfileSeriesRepository();
    tankSeries = TankPressureSeriesRepository();
    rowCounter = 0;
    final fk = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(fk.data.values.first, 1);
    await insertComputer('dc-a');
    await insertComputer('dc-b');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test(
    'removing a secondary source deletes it and only what it owns',
    () async {
      final rows = await twoComputerDive();

      await service.remove(diveId: 'dive-1', sourceId: 'src-b');

      expect(await ids(db.diveDataSources), {'src-a'});
      expect(await ids(db.diveProfileSeries), {rows.profileA});
      expect(await ids(db.diveTanks), {rows.tankA});
      expect(await ids(db.tankPressureSeries), hasLength(1));
      expect((await ids(db.diveProfileEvents)).contains(rows.eventB), isFalse);
      expect(await ids(db.diveProfileEvents), hasLength(1));
      expect(await fkViolations(), isEmpty);
    },
  );

  test('logs a deletion for the source, its tank and its series', () async {
    final rows = await twoComputerDive();

    await service.remove(diveId: 'dive-1', sourceId: 'src-b');

    final tombstones = await db.select(db.deletionLog).get();
    final byRecord = {for (final t in tombstones) t.recordId: t.entityType};
    expect(byRecord['src-b'], 'diveDataSources');
    expect(byRecord[rows.tankB], 'diveTanks');
    expect(byRecord[rows.profileB], 'diveProfileSeries');
    expect(byRecord[rows.pressureB], 'tankPressureSeries');
    expect(byRecord['dive-1|dc-b'], 'diveProfileEventsScope');
  });

  test('removing the primary promotes the earliest remaining source and '
      're-zeroes its timeline', () async {
    final rows = await twoComputerDive(offsetB: 120);

    await service.remove(diveId: 'dive-1', sourceId: 'src-a');

    final source = await (db.select(
      db.diveDataSources,
    )..where((t) => t.id.equals('src-b'))).getSingle();
    expect(source.isPrimary, isTrue);
    final dive = await (db.select(
      db.dives,
    )..where((t) => t.id.equals('dive-1'))).getSingle();
    expect(dive.computerId, 'dc-b');
    expect(dive.diveDateTime, baseTime + 120 * 1000);
    final series = (await profileSeries.getSeriesForDive(
      'dive-1',
    )).singleWhere((s) => s.id == rows.profileB);
    expect(series.isPrimary, isTrue);
    expect(series.samples.first.timestamp, 0);
  });

  test('refuses the only source', () async {
    await insertDive('dive-1');
    await insertSource('src-a', 'dc-a', isPrimary: true, createdDay: 1);

    expect(
      () => service.remove(diveId: 'dive-1', sourceId: 'src-a'),
      throwsArgumentError,
    );
  });

  test('refuses a source that is not on the dive', () async {
    await twoComputerDive();

    expect(
      () => service.remove(diveId: 'dive-1', sourceId: 'elsewhere'),
      throwsArgumentError,
    );
  });

  test('leaves the logbook entry untouched', () async {
    await twoComputerDive();

    await service.remove(diveId: 'dive-1', sourceId: 'src-b');

    final dive = await (db.select(
      db.dives,
    )..where((t) => t.id.equals('dive-1'))).getSingle();
    expect(dive.notes, 'Calm, two computers');
    expect(dive.diveNumber, 7);
  });

  test(
    'a tank another computer shares stays, handed to that computer',
    () async {
      await insertDive('dive-1');
      await insertSource('src-a', 'dc-a', isPrimary: true, createdDay: 1);
      await insertSource('src-b', 'dc-b', isPrimary: false, createdDay: 2);
      await insertProfile('dc-a', isPrimary: true);
      final shared = await insertTank('dc-b', sharedWith: ['dc-a']);

      await service.remove(diveId: 'dive-1', sourceId: 'src-b');

      final tank = await (db.select(
        db.diveTanks,
      )..where((t) => t.id.equals(shared))).getSingle();
      expect(tank.computerId, 'dc-a');
    },
  );

  test('reverting the operation brings the dive back as it was', () async {
    final rows = await twoComputerDive(offsetB: 120);

    final removal = await service.remove(diveId: 'dive-1', sourceId: 'src-a');
    expect(removal.operationId, isNotNull);

    final undone = await undoChangeLogOperation(
      removal.operationId,
      revert: ChangeLogRevertService(afterDiveWrites: (_) {}),
    );

    expect(undone, isTrue);
    expect(await ids(db.diveDataSources), {'src-a', 'src-b'});
    final sources = await db.select(db.diveDataSources).get();
    expect(
      {for (final s in sources) s.id: s.isPrimary},
      {'src-a': true, 'src-b': false},
    );
    final all = await profileSeries.getSeriesForDive('dive-1');
    expect(all.map((s) => s.id).toSet(), {rows.profileA, rows.profileB});
    final b = all.singleWhere((s) => s.id == rows.profileB);
    expect(b.isPrimary, isFalse);
    expect(b.samples.first.timestamp, 120);
    expect(await ids(db.diveTanks), {rows.tankA, rows.tankB});
    final dive = await (db.select(
      db.dives,
    )..where((t) => t.id.equals('dive-1'))).getSingle();
    expect(dive.diveDateTime, baseTime);
    expect(dive.computerId, 'dc-a');
    expect(await fkViolations(), isEmpty);
  });
}
