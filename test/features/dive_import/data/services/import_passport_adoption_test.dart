import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/dive_import/data/services/import_passport_adoption.dart';

import '../../../../helpers/test_database.dart';

/// The importer's adoption pass (issue #2651).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'D',
            createdAt: t,
            updatedAt: t,
          ),
        );
    for (final id in ['a', 'b']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'tank',
              createdAt: t,
              updatedAt: t,
              diverId: const Value('d1'),
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  test('two items carrying one id: the first adopts it, the second is '
      'refused, and unmapped or untagged items are skipped', () async {
    final passports = CylinderPassportRepository();
    final count = await adoptImportedPassportIds(
      [
        {'uddfId': 'equip_x', 'passportId': 'pp-1'},
        {'uddfId': 'equip_y', 'passportId': 'pp-1'},
        {'uddfId': 'equip_z', 'passportId': 'pp-unmapped'},
        {'uddfId': 'equip_w'},
      ],
      {'equip_x': 'a', 'equip_y': 'b'},
      passports,
      diverId: 'd1',
    );
    expect(count, 1);
    expect(await passports.getPassportId('a'), 'pp-1');
    expect(await passports.getPassportId('b'), isNull);
  });
}
