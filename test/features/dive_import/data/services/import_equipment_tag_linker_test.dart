import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_import/data/services/import_equipment_tag_linker.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late String regId;
  late Tag night;
  late Tag rental;
  late ImportEquipmentTagLinker link;

  setUp(() async {
    await setUpTestDatabase();
    final now = DateTime(2026);
    await DiverRepository().createDiver(
      Diver(id: 'd1', name: 'Diver', createdAt: now, updatedAt: now),
    );
    regId = (await EquipmentRepository().createEquipment(
      const EquipmentItem(
        id: '',
        diverId: 'd1',
        name: 'Reg',
        type: EquipmentType.regulator,
      ),
    )).id;
    night = await TagRepository().getOrCreateTag('Night', diverId: 'd1');
    rental = await TagRepository().getOrCreateTag(
      'Rental',
      diverId: 'd1',
      scope: TagScope.equipment,
    );
    link = ImportEquipmentTagLinker(
      tags: TagRepository(),
      links: EquipmentTagRepository(),
    );
  });

  tearDown(tearDownTestDatabase);

  Future<List<String>> tagNamesOfReg() async => [
    for (final t in await EquipmentTagRepository().getTagsForEquipment(regId))
      t.name,
  ];

  test(
    'links resolved refs, drops unknown ones and widens a dive tag',
    () async {
      await link.link(
        items: const [
          {
            'uddfId': 'equip_1',
            'name': 'Reg',
            'tagRefs': ['tag_a', 'tag_b', 'tag_missing'],
          },
        ],
        equipmentIdMapping: {'equip_1': regId},
        tagIdMapping: {'tag_a': night.id, 'tag_b': rental.id},
      );
      expect(await tagNamesOfReg(), ['Night', 'Rental']);
      final widened = await TagRepository().getTagById(night.id);
      expect(widened!.scopes, {TagScope.dives, TagScope.equipment});
    },
  );

  test('adds to the tags an item has and removes none', () async {
    await EquipmentTagRepository().replaceTags(regId, [rental.id]);
    await link.link(
      items: const [
        {
          'uddfId': 'equip_1',
          'tagRefs': ['tag_a'],
        },
      ],
      equipmentIdMapping: {'equip_1': regId},
      tagIdMapping: {'tag_a': night.id},
    );
    expect(await tagNamesOfReg(), ['Night', 'Rental']);
  });

  test('an item that resolved to no local item is left alone', () async {
    await link.link(
      items: const [
        {
          'uddfId': 'equip_unselected',
          'tagRefs': ['tag_b'],
        },
      ],
      equipmentIdMapping: const {},
      tagIdMapping: {'tag_b': rental.id},
    );
    expect(await tagNamesOfReg(), isEmpty);
  });

  test('a name two id-less rows share links neither by name', () async {
    // One row was matched to the existing Reg by name (a skipped duplicate,
    // or the selected one of two); the name alone cannot say which row the
    // local item stands for.
    await link.link(
      items: const [
        {
          'name': 'Reg',
          'tagRefs': ['tag_a'],
        },
        {
          'name': 'Reg',
          'tagRefs': ['tag_b'],
        },
      ],
      equipmentIdMapping: {'Reg': regId},
      tagIdMapping: {'tag_a': night.id, 'tag_b': rental.id},
    );
    expect(await tagNamesOfReg(), isEmpty);
  });
}
