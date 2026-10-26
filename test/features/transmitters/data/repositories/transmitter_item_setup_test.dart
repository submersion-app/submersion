import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';

import '../../../../helpers/test_database.dart';

/// Role and cylinder belong to the transmitter item (issue #3676): one setup
/// writes every key behind it and marks them configured.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    for (final id in ['tx-gear', 'cyl']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: id == 'cyl' ? 'tank' : 'transmitter',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }
    for (final (id, serial, configured) in [
      ('a', '4A21F', false),
      ('b', '7C0B19', true),
    ]) {
      await db
          .into(db.transmitters)
          .insert(
            TransmittersCompanion.insert(
              id: id,
              label: 'Tx',
              tankRole: 'backGas',
              transmitterSerial: Value(serial),
              transmitterEquipmentId: const Value('tx-gear'),
              isConfigured: Value(configured),
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  test('getForEquipment lists the keys behind an item', () async {
    final keys = await TransmitterRepository().getForEquipment('tx-gear');
    expect(keys.map((k) => k.id).toSet(), {'a', 'b'});
    expect(await TransmitterRepository().getForEquipment('cyl'), isEmpty);
  });

  test('saving the setup configures every row of the item', () async {
    await TransmitterRepository().saveSetup(
      'tx-gear',
      role: TankRole.stage,
      cylinderId: 'cyl',
      volumeL: 11.1,
      workingPressureBar: 207,
      material: TankMaterial.aluminum,
      presetName: 'AL80',
    );

    final keys = await TransmitterRepository().getForEquipment('tx-gear');
    for (final k in keys) {
      expect(k.isConfigured, isTrue);
      expect(k.role, TankRole.stage);
      expect(k.equipmentId, 'cyl');
      expect(k.volumeL, 11.1);
      expect(k.workingPressureBar, 207);
      expect(k.material, TankMaterial.aluminum);
      expect(k.presetName, 'AL80');
      expect(k.isSetUp, isTrue);
    }
  });

  test('the key the page just saved is not written a second time', () async {
    await TransmitterRepository().saveSetup(
      'tx-gear',
      role: TankRole.stage,
      cylinderId: 'cyl',
      volumeL: 11.1,
      exceptKeyId: 'a',
    );

    final a = await (db.select(
      db.transmitters,
    )..where((t) => t.id.equals('a'))).getSingle();
    expect(a.updatedAt, 0);
    expect(a.tankRole, 'backGas');
    final b = await (db.select(
      db.transmitters,
    )..where((t) => t.id.equals('b'))).getSingle();
    expect(b.tankRole, 'stage');
  });
}
