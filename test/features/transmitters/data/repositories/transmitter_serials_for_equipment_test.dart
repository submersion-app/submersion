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
    for (final (id, type) in [('tx', 'transmitter'), ('tank', 'tank')]) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: type,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    final now = DateTime.utc(2026);
    await repo.create(
      Transmitter(
        id: 't1',
        transmitterSerial: ' 180777 ',
        label: 'Left',
        // The cylinder it feeds, and the transmitter gear item it is.
        equipmentId: 'tank',
        transmitterEquipmentId: 'tx',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repo.create(
      Transmitter(
        id: 't2',
        transmitterSerial: '180778',
        label: 'Right',
        transmitterEquipmentId: 'tx',
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

  test('the cylinder a transmitter feeds is not the transmitter', () async {
    // A registry row's equipmentId is the cylinder it feeds; keying the
    // dropout rules on it meant a real transmitter item never matched.
    expect(await repo.getSerialsForEquipment('tank'), isEmpty);
  });
}
