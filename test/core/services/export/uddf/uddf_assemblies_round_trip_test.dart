import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';

import '../../../../helpers/test_database.dart';
import 'uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;

/// Export a logbook with a nested assembly on a dive applied from a set,
/// restore it onto a clean database, and find the same shape (issue #1487).
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  test('components and gear provenance survive export and import', () async {
    final diverId = await createTestDiver();
    final equipment = EquipmentRepository();
    final reg = await equipment.createEquipment(
      const EquipmentItem(id: '', name: 'Reg', type: EquipmentType.regulator),
    );
    final first = await equipment.createEquipment(
      const EquipmentItem(
        id: '',
        name: 'First',
        type: EquipmentType.firstStage,
      ),
    );
    final hose = await equipment.createEquipment(
      const EquipmentItem(id: '', name: 'Hose', type: EquipmentType.hose),
    );
    final components = EquipmentComponentRepository();
    await components.addComponent(
      parentId: reg.id,
      componentId: first.id,
      role: 'First stage',
    );
    await components.addComponent(
      parentId: first.id,
      componentId: hose.id,
      role: 'LP hose',
    );
    final sets = EquipmentSetRepository();
    final now = DateTime.now();
    await sets.createSet(
      EquipmentSet(
        id: 'winter',
        diverId: diverId,
        name: 'Winter',
        equipmentIds: [reg.id],
        createdAt: now,
        updatedAt: now,
      ),
    );
    final dives = DiveRepository();
    await dives.createDive(
      domain.Dive(
        id: 'd1',
        dateTime: DateTime(2026, 3, 1),
        gear: gearLinksFor(
          [reg, first, hose],
          [
            GearProvenance(equipmentId: reg.id, viaSetId: 'winter'),
            GearProvenance(
              equipmentId: first.id,
              viaEquipmentId: reg.id,
              viaSetId: 'winter',
            ),
            GearProvenance(
              equipmentId: hose.id,
              viaEquipmentId: first.id,
              viaSetId: 'winter',
            ),
          ],
        ),
      ),
    );

    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: await dives.getAllDives(),
      equipment: await equipment.getAllEquipment(),
      equipmentSets: await sets.getAllSets(),
      components: await components.getAllComponents(),
    );

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

    final byName = {
      for (final e in await EquipmentRepository().getAllEquipment())
        e.name: e.id,
    };
    expect(byName.keys, containsAll(['Reg', 'First', 'Hose']));
    final rows = await EquipmentComponentRepository().getAllComponents();
    expect(rows, hasLength(2));
    final underReg = rows.firstWhere(
      (r) => r.parentEquipmentId == byName['Reg'],
    );
    expect(underReg.componentEquipmentId, byName['First']);
    expect(underReg.role, 'First stage');
    final underFirst = rows.firstWhere(
      (r) => r.parentEquipmentId == byName['First'],
    );
    expect(underFirst.componentEquipmentId, byName['Hose']);
    expect(underFirst.role, 'LP hose');

    final restored = (await DiveRepository().getAllDives()).single;
    final gear = {for (final g in restored.gear) g.item.name: g};
    expect(gear.keys, containsAll(['Reg', 'First', 'Hose']));
    expect(gear['Reg']!.viaEquipmentId, isNull);
    expect(gear['First']!.viaEquipmentId, byName['Reg']);
    expect(gear['Hose']!.viaEquipmentId, byName['First']);
    final setId = (await EquipmentSetRepository().getAllSets()).single.id;
    expect(setId, isNot('winter'), reason: 'the restore mints a new set id');
    expect(gear['Reg']!.viaSetId, setId);
    expect(gear['First']!.viaSetId, setId);
    expect(gear['Hose']!.viaSetId, setId);
  });

  test('a cyclic pair of component rows is skipped, not thrown', () async {
    // Untrusted input again: a file claiming reg contains hose and hose
    // contains reg cannot both be true. The second edge is refused and
    // logged, and the rest of the logbook still lands.
    final diverId = await createTestDiver();
    const parsed = UddfImportResult(
      equipment: [
        {
          'uddfId': 'equip_reg',
          'name': 'Reg',
          'type': EquipmentType.regulator,
          'components': [
            {'componentRef': 'equip_hose', 'role': 'Primary', 'sortOrder': 0},
          ],
        },
        {
          'uddfId': 'equip_hose',
          'name': 'Hose',
          'type': EquipmentType.hose,
          'components': [
            {'componentRef': 'equip_reg', 'role': 'Loop', 'sortOrder': 0},
          ],
        },
      ],
    );

    await UddfEntityImporter().import(
      data: parsed,
      selections: UddfImportSelections.selectAll(parsed),
      repositories: buildRepositories(),
      diverId: diverId,
    );

    final byName = {
      for (final e in await EquipmentRepository().getAllEquipment())
        e.name: e.id,
    };
    expect(byName.keys, containsAll(['Reg', 'Hose']));
    final rows = await EquipmentComponentRepository().getAllComponents();
    expect(rows, hasLength(1), reason: 'only the first edge is legal');
    expect(rows.single.parentEquipmentId, byName['Reg']);
    expect(rows.single.componentEquipmentId, byName['Hose']);
  });

  test('a component row with a non-string role still imports', () async {
    // Import input is untrusted: a role that is not a string must cost
    // that row its role, not the whole logbook.
    final diverId = await createTestDiver();
    const parsed = UddfImportResult(
      equipment: [
        {
          'uddfId': 'equip_reg',
          'name': 'Reg',
          'type': EquipmentType.regulator,
          'components': [
            {'componentRef': 'equip_hose', 'role': 42, 'sortOrder': 0},
          ],
        },
        {'uddfId': 'equip_hose', 'name': 'Hose', 'type': EquipmentType.hose},
      ],
    );

    await UddfEntityImporter().import(
      data: parsed,
      selections: UddfImportSelections.selectAll(parsed),
      repositories: buildRepositories(),
      diverId: diverId,
    );

    final byName = {
      for (final e in await EquipmentRepository().getAllEquipment())
        e.name: e.id,
    };
    final rows = await EquipmentComponentRepository().getAllComponents();
    expect(rows, hasLength(1), reason: 'the row survived the bad role');
    expect(rows.single.parentEquipmentId, byName['Reg']);
    expect(rows.single.componentEquipmentId, byName['Hose']);
    expect(rows.single.role, '');
  });
}
