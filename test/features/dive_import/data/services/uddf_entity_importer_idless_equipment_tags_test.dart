import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';

import '../../../../core/services/export/uddf/uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;
import '../../../../helpers/test_database.dart';

/// Equipment tags on an item the file gives no id (issue #1942). Such an
/// item is keyed by its name, as the import wizard keys a duplicate, so its
/// tags still link; a name two id-less items share keys neither.
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async => tearDownTestDatabase());

  ImportRepositories repositories() {
    final r = buildRepositories();
    return ImportRepositories(
      tripRepository: r.tripRepository,
      equipmentRepository: r.equipmentRepository,
      equipmentSetRepository: r.equipmentSetRepository,
      buddyRepository: r.buddyRepository,
      diveCenterRepository: r.diveCenterRepository,
      certificationRepository: r.certificationRepository,
      tagRepository: r.tagRepository,
      diveTypeRepository: r.diveTypeRepository,
      diveRoleRepository: r.diveRoleRepository,
      siteRepository: r.siteRepository,
      diveRepository: r.diveRepository,
      tankPressureRepository: r.tankPressureRepository,
      courseRepository: r.courseRepository,
      diveComputerRepository: r.diveComputerRepository,
      siteTypeRepository: r.siteTypeRepository,
      siteClassificationRepository: r.siteClassificationRepository,
      equipmentTagRepository: EquipmentTagRepository(),
    );
  }

  const rental = {
    'uddfId': 'tag_rental',
    'name': 'Rental',
    'appliesToDives': false,
    'appliesToSites': false,
    'appliesToEquipment': true,
  };

  Future<Map<String, List<String>>> tagNamesByItemName() async {
    final tags = EquipmentTagRepository();
    return {
      for (final item in await EquipmentRepository().getAllEquipment())
        item.name: [
          for (final t in await tags.getTagsForEquipment(item.id)) t.name,
        ],
    };
  }

  Future<void> import(
    UddfImportResult data, {
    UddfImportSelections? selections,
  }) async {
    await UddfEntityImporter().import(
      data: data,
      selections: selections ?? UddfImportSelections.selectAll(data),
      repositories: repositories(),
      diverId: await createTestDiver(),
    );
  }

  test('an item with no id still gets its tags', () async {
    await import(
      const UddfImportResult(
        tags: [rental],
        equipment: [
          {
            'name': 'Wing',
            'type': 'bcd',
            'tagRefs': ['tag_rental'],
          },
        ],
      ),
    );

    expect(await tagNamesByItemName(), {
      'Wing': ['Rental'],
    });
  });

  test('two id-less items sharing a name get no tags', () async {
    await import(
      const UddfImportResult(
        tags: [rental],
        equipment: [
          {
            'name': 'Wing',
            'type': 'bcd',
            'tagRefs': ['tag_rental'],
          },
          {'name': 'Wing', 'type': 'bcd'},
        ],
      ),
    );

    final items = await EquipmentRepository().getAllEquipment();
    expect(items, hasLength(2));
    for (final item in items) {
      expect(
        await EquipmentTagRepository().getTagsForEquipment(item.id),
        isEmpty,
        reason: 'which Wing the tag belongs to is ambiguous',
      );
    }
  });

  test(
    'a deselected id-less namesake lends the selected row no tags',
    () async {
      const cold = {
        'uddfId': 'tag_cold',
        'name': 'Cold water',
        'appliesToDives': false,
        'appliesToSites': false,
        'appliesToEquipment': true,
      };
      const data = UddfImportResult(
        tags: [rental, cold],
        equipment: [
          {
            'name': 'Wing',
            'type': 'bcd',
            'tagRefs': ['tag_rental'],
          },
          {
            'name': 'Wing',
            'type': 'bcd',
            'tagRefs': ['tag_cold'],
          },
        ],
      );
      final all = UddfImportSelections.selectAll(data);
      await import(
        data,
        selections: UddfImportSelections(tags: all.tags, equipment: const {0}),
      );

      final wing = (await EquipmentRepository().getAllEquipment()).single;
      expect(
        await EquipmentTagRepository().getTagsForEquipment(wing.id),
        isEmpty,
        reason: 'which Wing a name stands for is ambiguous in this file',
      );
    },
  );
}
