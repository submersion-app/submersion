import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';

import '../../../../helpers/test_database.dart';

/// A passport id from an import is written only into an empty slot
/// (issue #2651).
void main() {
  late AppDatabase db;
  late CylinderPassportRepository passports;

  Future<void> item(String id, String type) async {
    final t = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: id,
            name: id,
            type: type,
            createdAt: t,
            updatedAt: t,
            diverId: const Value('d1'),
          ),
        );
  }

  CylinderFill orphan(String id, String passportId) => CylinderFill(
    id: id,
    diverId: 'd1',
    passportId: passportId,
    filledAt: DateTime(2026, 9, 1),
    o2Percent: 32,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    passports = CylinderPassportRepository();
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
    await item('tank-1', 'tank');
  });
  tearDown(tearDownTestDatabase);

  test('an empty slot takes the id and the orphan fills relink', () async {
    await CylinderFillRepository().create(orphan('f1', 'pp-1'));
    final adopted = await passports.adoptImportedPassportId(
      equipmentId: 'tank-1',
      passportId: 'pp-1',
      diverId: 'd1',
    );
    expect(adopted, isTrue);
    expect(await passports.getPassportId('tank-1'), 'pp-1');
    expect(
      (await CylinderFillRepository().getById('f1'))!.equipmentId,
      'tank-1',
    );
  });

  test('an item with its own tag keeps it', () async {
    await passports.assignPassportId(
      equipmentId: 'tank-1',
      passportId: 'pp-own',
      diverId: 'd1',
    );
    final adopted = await passports.adoptImportedPassportId(
      equipmentId: 'tank-1',
      passportId: 'pp-file',
      diverId: 'd1',
    );
    expect(adopted, isFalse);
    expect(await passports.getPassportId('tank-1'), 'pp-own');
  });

  for (final status in ['active', 'retired']) {
    test('another $status holder keeps the id', () async {
      await item('tank-2', 'tank');
      await passports.assignPassportId(
        equipmentId: 'tank-2',
        passportId: 'pp-1',
        diverId: 'd1',
      );
      await db.customStatement(
        "UPDATE equipment SET status = '$status' WHERE id = 'tank-2'",
      );
      final adopted = await passports.adoptImportedPassportId(
        equipmentId: 'tank-1',
        passportId: 'pp-1',
        diverId: 'd1',
      );
      expect(adopted, isFalse);
      expect(await passports.getPassportId('tank-1'), isNull);
      expect(await passports.getPassportId('tank-2'), 'pp-1');
    });
  }

  test('a non-tank takes the id but collects no fills', () async {
    await item('bcd-1', 'bcd');
    await CylinderFillRepository().create(orphan('f2', 'pp-g'));
    expect(
      await passports.adoptImportedPassportId(
        equipmentId: 'bcd-1',
        passportId: 'pp-g',
        diverId: 'd1',
      ),
      isTrue,
    );
    expect(await passports.getPassportId('bcd-1'), 'pp-g');
    expect((await CylinderFillRepository().getById('f2'))!.equipmentId, isNull);
  });

  test('adopting a tag keeps the item\'s other attributes', () async {
    final equipment = EquipmentRepository();
    await equipment.saveAttributes('tank-1', [
      EquipmentAttribute.curated(
        equipmentId: 'tank-1',
        key: EquipmentAttrKeys.workingPressureBar,
        valueNum: 232,
      ),
    ]);
    await passports.adoptImportedPassportId(
      equipmentId: 'tank-1',
      passportId: 'pp-1',
      diverId: 'd1',
    );
    final attributes = {
      for (final a in await equipment.getAttributesForEquipment('tank-1'))
        a.key: a.valueNum ?? a.valueText,
    };
    expect(attributes[EquipmentAttrKeys.workingPressureBar], 232);
    expect(attributes[EquipmentAttrKeys.passportId], 'pp-1');
  });
}
