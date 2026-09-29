import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

import '../../../helpers/test_database.dart';

/// Schema v241 (issue #2440) added tank_pressure_series.source_id without
/// raising the sync floor, so a v240 peer still syncs with a v241 one. Its
/// records carry no `sourceId` key. Applying one must leave the attribution
/// this device holds alone: nothing re-derives it after the migration's
/// backfill, and an unattributed series is read as a recording of its own.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    DatabaseService.instance.setTestDatabase(db);
    SyncClock.instance.reset();
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: DateTime.utc(2026, 1, 1).millisecondsSinceEpoch,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 'tank1', diveId: 'd1'));
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src1',
            diveId: 'd1',
            isPrimary: const Value(true),
            importedAt: DateTime.utc(2026),
            createdAt: DateTime.utc(2026),
          ),
        );
  });

  tearDown(() async {
    DatabaseService.instance.resetForTesting();
    SyncClock.instance.reset();
    await db.close();
  });

  /// The series as a v240 peer would send it after editing it: every
  /// column this device knows except `sourceId`, with a newer updatedAt.
  Future<(String, Map<String, dynamic>)> seedAndEditOnOldPeer() async {
    final id = await TankPressureSeriesRepository().insertSeries(
      diveId: 'd1',
      tankId: 'tank1',
      sourceId: 'src1',
      samples: const [TankPressureSample(timestamp: 0, pressure: 200.0)],
      now: 1000,
    );
    final json = await SyncDataSerializer().fetchRecord(
      'tankPressureSeries',
      id,
    );
    expect(json!['sourceId'], 'src1');
    final fromOldPeer = {...json, 'updatedAt': 2000}..remove('sourceId');
    return (id, fromOldPeer);
  }

  Future<String?> sourceIdOf(String id) async {
    final row = await (db.select(
      db.tankPressureSeries,
    )..where((t) => t.id.equals(id))).getSingle();
    return row.sourceId;
  }

  test('a single record from a v240 peer keeps the local source', () async {
    final (id, fromOldPeer) = await seedAndEditOnOldPeer();

    await SyncDataSerializer().upsertRecord('tankPressureSeries', fromOldPeer);

    expect(await sourceIdOf(id), 'src1');
  });

  test('a batch from a v240 peer keeps the local source', () async {
    final (id, fromOldPeer) = await seedAndEditOnOldPeer();

    await SyncDataSerializer().upsertRecords('tankPressureSeries', [
      fromOldPeer,
    ]);

    expect(await sourceIdOf(id), 'src1');
  });
}
