import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../../helpers/test_database.dart';

/// Equipment save and delete never lose or strand tag links (issue #1942).
void main() {
  late AppDatabase db;
  late EquipmentRepository equipment;
  late EquipmentTagRepository tags;

  setUp(() async {
    db = await setUpTestDatabase();
    equipment = EquipmentRepository();
    tags = EquipmentTagRepository();
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('e1', 'Wing', 'bcd', 1, 1), ('e2', 'Fins', 'fins', 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO tags (id, name, created_at, updated_at, "
      "applies_to_dives, applies_to_sites, applies_to_equipment) "
      "VALUES ('t1', 'Travel kit', 0, 0, 0, 0, 1), "
      "('t2', 'Rental', 0, 0, 0, 0, 1)",
    );
  });

  tearDown(tearDownTestDatabase);

  Future<List<String>> tombstonedLinks() async {
    final rows = await db.select(db.deletionLog).get();
    return [
      for (final r in rows)
        if (r.entityType == 'equipmentTags') r.recordId,
    ];
  }

  test('deleteEquipment tombstones its tag links', () async {
    await tags.addTags(['e1'], ['t1', 't2']);
    await tags.addTags(['e2'], ['t1']);
    final doomed = [
      for (final r in await db.select(db.equipmentTags).get())
        if (r.equipmentId == 'e1') r.id,
    ];

    await equipment.deleteEquipment('e1');

    final left = await db.select(db.equipmentTags).get();
    expect(left.map((r) => r.equipmentId), ['e2']);
    expect(await tombstonedLinks(), unorderedEquals(doomed));
  });

  test('updateEquipment with a partial entity leaves tags untouched', () async {
    await tags.replaceTags('e1', ['t1', 't2']);

    // A partially loaded item, as the dive-joined mappers build one.
    await equipment.updateEquipment(
      const EquipmentItem(
        id: 'e1',
        name: 'Renamed wing',
        type: EquipmentType.bcd,
      ),
    );

    expect((await tags.getTagsForEquipment('e1')).map((t) => t.id).toSet(), {
      't1',
      't2',
    });
    expect(await tombstonedLinks(), isEmpty);
  });
}
