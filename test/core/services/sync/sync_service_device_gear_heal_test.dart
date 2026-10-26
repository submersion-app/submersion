import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_computer_gear_identity.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

/// A sync can leave a dive computer without its Equipment item: a peer's
/// computer whose item this device never had, or an older peer that deleted
/// the item as "unlink only". The sync gives it one back before it ends
/// (issue #3676).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => DatabaseService.instance.resetForTesting());

  test('a computer left without an item has one after a sync', () async {
    final db = DatabaseService.instance.database;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'c1',
            name: 'Shearwater Teric',
            manufacturer: const Value('Shearwater'),
            model: const Value('Teric'),
            createdAt: 0,
            updatedAt: 0,
          ),
        );

    final result = await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: FakeCloudStorageProvider(),
    ).performSync();
    expect(result.status, isNot(SyncResultStatus.error));

    final computer = await (db.select(
      db.diveComputers,
    )..where((r) => r.id.equals('c1'))).getSingle();
    expect(computer.equipmentId, diveComputerGearId('c1'));
  });

  test('a sync that heals a computer tells open screens (review)', () async {
    final db = DatabaseService.instance.database;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion.insert(
            id: 'c1',
            name: 'Shearwater Teric',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    var ticks = 0;
    final sub = db
        .tableUpdates(TableUpdateQuery.onTable(db.equipment))
        .listen((_) => ticks++);
    addTearDown(sub.cancel);
    await Future<void>.delayed(Duration.zero);
    ticks = 0;

    await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: FakeCloudStorageProvider(),
    ).performSync();
    await Future<void>.delayed(Duration.zero);

    expect(ticks, greaterThan(0));
  });
}
