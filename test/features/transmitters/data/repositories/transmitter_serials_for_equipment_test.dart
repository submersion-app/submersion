import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late TransmitterRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = TransmitterRepository();
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'tx',
            name: 'Tx',
            type: 'transmitter',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    final now = DateTime.utc(2026);
    await repo.create(
      Transmitter(
        id: 't1',
        transmitterSerial: ' 180777 ',
        label: 'Left',
        equipmentId: 'tx',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repo.create(
      Transmitter(
        id: 't2',
        transmitterSerial: '180778',
        label: 'Right',
        equipmentId: 'tx',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repo.create(
      Transmitter(
        id: 't3',
        transmitterSerial: '999',
        label: 'Other item',
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(tearDownTestDatabase);

  test('returns the normalised serials of the item\'s registry rows', () async {
    expect(await repo.getSerialsForEquipment('tx'), {'180777', '180778'});
    expect(await repo.getSerialsForEquipment('none'), isEmpty);
  });
}
