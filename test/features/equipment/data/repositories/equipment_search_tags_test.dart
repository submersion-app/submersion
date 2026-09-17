import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../../helpers/test_database.dart';

/// Equipment search also matches tag names (issue #1942).
void main() {
  late EquipmentRepository equipment;
  late EquipmentTagRepository tags;

  setUp(() async {
    await setUpTestDatabase();
    equipment = EquipmentRepository();
    tags = EquipmentTagRepository();
    final db = DatabaseService.instance.database;
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('d1', 'Diver', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO tags (id, diver_id, name, created_at, updated_at, '
      'applies_to_dives, applies_to_sites, applies_to_equipment) VALUES '
      "('t1', 'd1', 'Travel kit', 0, 0, 0, 0, 1), "
      "('t2', 'd1', 'Travel spares', 0, 0, 0, 0, 1), "
      "('t3', 'd1', 'Rental', 0, 0, 0, 0, 1)",
    );
  });

  tearDown(() async => tearDownTestDatabase());

  Future<EquipmentItem> add(
    String name, {
    String? brand,
    List<String> tagIds = const [],
  }) async {
    final item = await equipment.createEquipment(
      EquipmentItem(
        id: '',
        diverId: 'd1',
        name: name,
        type: EquipmentType.bcd,
        brand: brand,
      ),
    );
    await tags.replaceTags(item.id, tagIds);
    return item;
  }

  test('a tag name match finds the item', () async {
    final wing = await add('Wing', tagIds: ['t1']);
    await add('Drysuit', tagIds: ['t3']);

    final found = await equipment.searchEquipment('kit');
    expect(found.map((e) => e.id), [wing.id]);
  });

  test('an item with two matching tags comes back once', () async {
    final wing = await add('Wing', tagIds: ['t1', 't2']);

    final found = await equipment.searchEquipment('travel');
    expect(found.map((e) => e.id), [wing.id]);
  });

  test('untagged items still match by name and brand', () async {
    final reg = await add('Primary', brand: 'Apeks');
    await add('Wing', tagIds: ['t1']);

    // The LEFT JOIN must keep items that have no tag rows at all.
    expect((await equipment.searchEquipment('apeks')).map((e) => e.id), [
      reg.id,
    ]);
    expect((await equipment.searchEquipment('prim')).map((e) => e.id), [
      reg.id,
    ]);
  });

  test('the diver filter still applies with the tags joined', () async {
    final wing = await add('Wing', tagIds: ['t1']);

    expect(
      (await equipment.searchEquipment(
        'travel',
        diverId: 'd1',
      )).map((e) => e.id),
      [wing.id],
    );
    expect(
      await equipment.searchEquipment('travel', diverId: 'someone-else'),
      isEmpty,
    );
  });
}
