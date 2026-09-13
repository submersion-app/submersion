import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
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

/// Issues #1718 and #1796: a dives-only UDDF shared from one device and
/// imported on a clean one brings back every participant with their exact
/// role, and the gear and computer used on the dive.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  /// Seeds one dive with every role and an assembly applied from a set,
  /// then exports it the way the dive detail page does.
  Future<String> seedAndExport(UddfExportOptions options) async {
    final diverId = await createTestDiver();
    final custom = await DiveRoleRepository().createDiveRole(
      name: 'Photographer',
      diverId: diverId,
    );
    final buddies = BuddyRepository();
    final now = DateTime.now();
    Future<Buddy> person(String name) => buddies.createBuddy(
      Buddy(id: '', name: name, createdAt: now, updatedAt: now),
    );
    final guide = await person('Nicol Sorin');
    final master = await person('Ana Reyes');
    final instructor = await person('Tom Lee');
    final student = await person('Sam Park');
    final photographer = await person('Pat Kim');
    final plain = await person('Joe Bloggs');
    // A certification lives in its own table and is derived onto the
    // person at read time, so it only reaches the file if the export's
    // participant read hydrates it.
    await CertificationRepository().createCertification(
      Certification(
        id: '',
        buddyId: instructor.id,
        name: 'Rescue Diver',
        agency: CertificationAgency.padi,
        level: CertificationLevel.rescue,
        createdAt: now,
        updatedAt: now,
      ),
    );

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
    await EquipmentComponentRepository().addComponent(
      parentId: reg.id,
      componentId: first.id,
      role: 'First stage',
    );
    await EquipmentSetRepository().createSet(
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
        dateTime: DateTime(2026, 3, 1, 9),
        diveComputerModel: 'Perdix AI',
        diveComputerSerial: 'SN1',
        gear: gearLinksFor(
          [reg, first],
          [
            GearProvenance(equipmentId: reg.id, viaSetId: 'winter'),
            GearProvenance(equipmentId: first.id, viaEquipmentId: reg.id),
          ],
        ),
      ),
    );
    await buddies.addBuddyToDive('d1', guide.id, DiveRole.diveGuideId);
    await buddies.addBuddyToDive('d1', master.id, DiveRole.diveMasterId);
    await buddies.addBuddyToDive('d1', instructor.id, DiveRole.instructorId);
    await buddies.addBuddyToDive('d1', student.id, DiveRole.studentId);
    await buddies.addBuddyToDive('d1', photographer.id, custom.id);
    await buddies.addBuddyToDive('d1', plain.id, DiveRole.buddyId);

    final selected = await dives.getDivesByIds(['d1']);
    return UddfExportService().generateDivesUddfContent(
      selected,
      extras: await resolveDivesExtras(
        buddies,
        EquipmentComponentRepository(),
        DiveRoleRepository(),
        diverId,
        ['d1'],
        options,
      ),
      options: options,
    );
  }

  /// Imports [xml] into a clean database, as another device would.
  Future<domain.Dive> importOnCleanDatabase(String xml) async {
    await tearDownTestDatabase();
    await setUpTestDatabase();
    final diverId = await createTestDiver();
    final parsed = await ExportService().importAllDataFromUddf(xml);
    await UddfEntityImporter().import(
      data: parsed,
      selections: UddfImportSelections.selectAll(parsed),
      repositories: buildRepositories(),
      diverId: diverId,
    );
    return (await DiveRepository().getAllDives()).single;
  }

  test('every role, the assembly and the computer come back', () async {
    final xml = await seedAndExport(const UddfExportOptions());
    final restored = await importOnCleanDatabase(xml);

    final roles = {
      for (final b in await BuddyRepository().getBuddiesForDive(restored.id))
        b.buddy.name: b.role.id,
    };
    final photographerRole = roles['Pat Kim'];
    final tom = (await BuddyRepository().getBuddiesForDive(
      restored.id,
    )).singleWhere((b) => b.buddy.name == 'Tom Lee').buddy;
    expect(tom.certificationLevel, CertificationLevel.rescue);
    expect(tom.certificationAgency, CertificationAgency.padi);
    expect(roles, {
      'Nicol Sorin': DiveRole.diveGuideId,
      'Ana Reyes': DiveRole.diveMasterId,
      'Tom Lee': DiveRole.instructorId,
      'Sam Park': DiveRole.studentId,
      'Pat Kim': photographerRole,
      'Joe Bloggs': DiveRole.buddyId,
    });
    expect(
      (await DiveRoleRepository().getDiveRoleById(photographerRole!))?.name,
      'Photographer',
    );
    expect(
      await BuddyRepository().getAllBuddies(),
      hasLength(6),
      reason: 'no person is created twice',
    );
    expect(restored.diveMaster, anyOf(isNull, isEmpty));

    final gear = {for (final g in restored.gear) g.item.name: g};
    expect(gear.keys, containsAll(['Reg', 'First']));
    final regId = gear['Reg']!.item.id;
    expect(gear['First']!.viaEquipmentId, regId);
    expect(
      gear['Reg']!.viaSetId,
      isNull,
      reason: 'sets are not shared, so a set-applied row lands loose',
    );
    final components = await EquipmentComponentRepository().getAllComponents();
    expect(components.single.parentEquipmentId, regId);
    expect(components.single.role, 'First stage');
    expect(restored.diveComputerModel, 'Perdix AI');
    expect(restored.diveComputerSerial, 'SN1');
  });

  test('with both checkboxes off, no person and no gear arrive', () async {
    final xml = await seedAndExport(
      const UddfExportOptions(includeParticipants: false, includeGear: false),
    );
    final restored = await importOnCleanDatabase(xml);

    expect(await BuddyRepository().getAllBuddies(), isEmpty);
    expect(restored.gear, isEmpty);
    expect(await EquipmentRepository().getAllEquipment(), isEmpty);
  });
}
