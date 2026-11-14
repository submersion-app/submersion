import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';

import '../../../../helpers/test_database.dart';
import 'uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;

/// The sets a set includes travel in the private block (issue #4525): an
/// export keeps them and a restore puts them back, under the new set ids.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  test('a set\'s included sets survive export and import', () async {
    final diverId = await createTestDiver();
    final equipment = EquipmentRepository();
    final reg = await equipment.createEquipment(
      const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
    );
    final cam = await equipment.createEquipment(
      const EquipmentItem(id: '', name: 'Camera', type: EquipmentType.camera),
    );
    final sets = EquipmentSetRepository();
    final now = DateTime.now();
    await sets.createSet(
      EquipmentSet(
        id: 'rig',
        diverId: diverId,
        name: 'Rig',
        equipmentIds: [reg.id],
        createdAt: now,
        updatedAt: now,
      ),
    );
    await sets.createSet(
      EquipmentSet(
        id: 'outer',
        diverId: diverId,
        name: 'Rig + camera',
        equipmentIds: [cam.id],
        includedSetIds: const ['rig'],
        createdAt: now,
        updatedAt: now,
      ),
    );

    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: const [],
      equipment: await equipment.getAllEquipment(),
      equipmentSets: await sets.getAllSets(),
    );
    expect(xml, contains('<setref>set_rig</setref>'));

    // A clean database, as a restore onto a new device would be.
    await tearDownTestDatabase();
    await setUpTestDatabase();
    final restoredDiverId = await createTestDiver();

    final parsed = await ExportService().importAllDataFromUddf(xml);
    await UddfEntityImporter().import(
      data: parsed,
      selections: UddfImportSelections.selectAll(parsed),
      repositories: buildRepositories(),
      diverId: restoredDiverId,
    );

    final restored = {
      for (final s in await EquipmentSetRepository().getAllSets()) s.name: s,
    };
    expect(restored.keys, containsAll(['Rig', 'Rig + camera']));
    expect(restored['Rig + camera']!.includedSetIds, [restored['Rig']!.id]);
    expect(restored['Rig']!.includedSetIds, isEmpty);
  });

  test('a reference to a set the file does not hold is dropped', () async {
    const uddf = '''<?xml version="1.0" encoding="UTF-8"?>
<uddf version="3.2.0">
  <applicationdata><submersion version="1.0">
    <equipmentsets>
      <set id="set_outer"><name>Outer</name>
        <includes><setref>set_gone</setref><setref></setref></includes>
      </set>
    </equipmentsets>
  </submersion></applicationdata>
</uddf>''';
    final parsed = await UddfFullImportService().importAllDataFromUddf(uddf);
    expect(parsed.equipmentSets.single['includedSetRefs'], ['set_gone']);

    final diverId = await createTestDiver();
    await UddfEntityImporter().import(
      data: parsed,
      selections: UddfImportSelections.selectAll(parsed),
      repositories: buildRepositories(),
      diverId: diverId,
    );
    final outer = (await EquipmentSetRepository().getAllSets()).single;
    expect(outer.name, 'Outer');
    expect(outer.includedSetIds, isEmpty);
  });
}
