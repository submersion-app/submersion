import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/test_database.dart';

/// Schema v251 (issue #2716) gave dive tanks a foreign key to their data
/// source without raising the sync floor, so a v249 peer still syncs with a
/// v251 one.
void main() {
  test('dive tanks guard their source like tank pressure series do', () {
    final refs = SyncService.parentRefs['diveTanks']!;
    final source = refs.singleWhere((r) => r.field == 'sourceId');
    final seriesSource = SyncService.parentRefs['tankPressureSeries']!
        .singleWhere((r) => r.field == 'sourceId');
    expect(source.parent, seriesSource.parent);
    expect(source.nullable, isTrue);
  });

  group('a record from a v249 peer', () {
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
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion.insert(
              id: 'tank1',
              diveId: 'd1',
            ).copyWith(sourceId: const Value('src1')),
          );
    });

    tearDown(() async {
      DatabaseService.instance.resetForTesting();
      SyncClock.instance.reset();
      await db.close();
    });

    /// The tank as a v249 peer would send it after editing it: every column
    /// this device knows except `sourceId`.
    Future<Map<String, dynamic>> editedOnOldPeer() async {
      final json = await SyncDataSerializer().fetchRecord('diveTanks', 'tank1');
      expect(json!['sourceId'], 'src1');
      return {...json, 'endPressure': 50.0}..remove('sourceId');
    }

    Future<DiveTank> tank() => (db.select(
      db.diveTanks,
    )..where((t) => t.id.equals('tank1'))).getSingle();

    test('applied alone, keeps the local source', () async {
      await SyncDataSerializer().upsertRecord(
        'diveTanks',
        await editedOnOldPeer(),
      );
      final row = await tank();
      expect(row.endPressure, 50.0);
      expect(row.sourceId, 'src1');
    });

    test('applied in a batch, keeps the local source', () async {
      await SyncDataSerializer().upsertRecords('diveTanks', [
        await editedOnOldPeer(),
      ]);
      final row = await tank();
      expect(row.endPressure, 50.0);
      expect(row.sourceId, 'src1');
    });
  });
}
