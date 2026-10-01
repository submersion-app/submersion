import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';

import '../../../../helpers/test_database.dart';

/// A further computer's recording of a dive is written whole or not at all
/// (issue #2672).
void main() {
  late DiveRepository repository;
  late AppDatabase db;
  final createdAt = DateTime.utc(2025, 3, 10, 9);

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-1'),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  });

  tearDown(() async => tearDownTestDatabase());

  DiveDataSourcesCompanion reading(String id) => DiveDataSourcesCompanion(
    id: Value(id),
    diveId: const Value('dive-1'),
    // Claims primary: the method must not let it.
    isPrimary: const Value(true),
    computerModel: const Value('Shearwater Teric'),
    importedAt: Value(createdAt),
    createdAt: Value(createdAt),
  );

  const profile = [
    DiveProfilePoint(timestamp: 0, depth: 0),
    DiveProfilePoint(timestamp: 600, depth: 30.4),
  ];

  ProfileEvent bookmark(String id) => ProfileEvent.bookmark(
    id: id,
    diveId: 'dive-1',
    timestamp: 1260,
    createdAt: createdAt,
  );

  test('writes a non-primary source owning its series and events', () async {
    await repository.saveAdditionalComputerReading(
      reading: reading('src-teric'),
      profile: profile,
      events: [bookmark('ev-1')],
    );

    final source = await (db.select(
      db.diveDataSources,
    )..where((t) => t.id.equals('src-teric'))).getSingle();
    expect(source.isPrimary, isFalse);

    final series = await ProfileSeriesRepository().getSeriesForDive('dive-1');
    expect(series.single.sourceId, 'src-teric');
    expect(series.single.isPrimary, isFalse);
    expect(await db.select(db.diveProfileEvents).get(), hasLength(1));
  });

  test('marks the source row pending, even with no events', () async {
    // Incremental sync exports a source row only for a dive modified since
    // the last sync or as a pending record of its own. With no events or
    // pressures nothing else re-marks the dive, so the row must be.
    await repository.saveAdditionalComputerReading(
      reading: reading('src-teric'),
      profile: profile,
    );

    final pending = await SyncRepository().getPendingRecords();
    expect(
      pending.where(
        (r) => r.entityType == 'diveDataSources' && r.recordId == 'src-teric',
      ),
      hasLength(1),
    );
  });

  test('writes its tank pressures owned by the same source', () async {
    await db
        .into(db.diveTanks)
        .insert(
          const DiveTanksCompanion(
            id: Value('tank-1'),
            diveId: Value('dive-1'),
          ),
        );

    await repository.saveAdditionalComputerReading(
      reading: reading('src-teric'),
      profile: profile,
      tankPressures: {
        'tank-1': [
          (timestamp: 0, pressure: 201.0),
          (timestamp: 2400, pressure: 61.0),
        ],
      },
    );

    final series = await TankPressureSeriesRepository().getSeriesForDive(
      'dive-1',
    );
    expect(series.single.tankId, 'tank-1');
    expect(series.single.sourceId, 'src-teric');
  });

  test('a failed pressure write takes the whole computer with it', () async {
    // A resync would see a source left behind as present and never retry
    // its pressures, so the row and its profile must not outlive them.
    await expectLater(
      repository.saveAdditionalComputerReading(
        reading: reading('src-teric'),
        profile: profile,
        tankPressures: {
          'no-such-tank': [(timestamp: 0, pressure: 201.0)],
        },
      ),
      throwsA(anything),
    );

    expect(await db.select(db.diveDataSources).get(), isEmpty);
    expect(await ProfileSeriesRepository().getSeriesForDive('dive-1'), isEmpty);
  });

  test('a failed write leaves nothing of that computer behind', () async {
    await repository.saveAdditionalComputerReading(
      reading: reading('src-teric'),
      profile: profile,
      events: [bookmark('ev-1')],
    );

    // The event id is taken, so the write fails on its last step, after the
    // source row and series went in. Both must roll back with it.
    await expectLater(
      repository.saveAdditionalComputerReading(
        reading: reading('src-second'),
        profile: profile,
        events: [bookmark('ev-1')],
      ),
      throwsA(anything),
    );

    expect(await db.select(db.diveDataSources).get(), hasLength(1));
    expect(
      await ProfileSeriesRepository().getSeriesForDive('dive-1'),
      hasLength(1),
    );
    expect(await db.select(db.diveProfileEvents).get(), hasLength(1));
  });
}
