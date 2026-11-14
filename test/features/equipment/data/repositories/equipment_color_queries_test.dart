import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../../helpers/test_database.dart';

/// The custom colours already on a diver's gear (issue #4537), which the
/// colour sheet offers as recent colours.
void main() {
  late AppDatabase db;
  late EquipmentRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentRepository();
    for (final id in ['d1', 'd2']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  /// An item of [diverId]'s coloured [color], its colour last written at
  /// [at]. [custom] stores it as the diver's own field named "color".
  Future<void> item(
    String diverId,
    String? color, {
    required int at,
    EquipmentStatus status = EquipmentStatus.active,
    bool custom = false,
  }) async {
    final gear = await repo.createEquipment(
      EquipmentItem(
        id: '',
        name: 'Mask $at',
        type: EquipmentType.mask,
        diverId: diverId,
        status: status,
      ),
    );
    await repo.saveAttributes(gear.id, [
      if (custom)
        EquipmentAttribute(
          id: '',
          equipmentId: gear.id,
          key: EquipmentAttrKeys.color,
          isCustom: true,
          valueText: color,
        )
      else
        EquipmentAttribute.curated(
          equipmentId: gear.id,
          key: EquipmentAttrKeys.color,
          valueText: color,
        ),
    ]);
    await (db.update(db.equipmentAttributes)
          ..where((a) => a.equipmentId.equals(gear.id)))
        .write(EquipmentAttributesCompanion(updatedAt: Value(at)));
  }

  test('lists the diver\'s off-palette colours, newest first', () async {
    await item('d1', '#123456', at: 1);
    await item('d1', '#ABCDEF', at: 3);
    await item('d1', '#0A3D91', at: 2);

    expect(await repo.getGearColors('d1'), ['#ABCDEF', '#0A3D91', '#123456']);
  });

  test('another diver\'s gear is not listed', () async {
    await item('d2', '#123456', at: 1);

    expect(await repo.getGearColors('d1'), isEmpty);
  });

  test('with no profile chosen, every item is read', () async {
    await item('d1', '#123456', at: 1);
    await item('d2', '#ABCDEF', at: 2);

    expect(await repo.getGearColors(null), ['#ABCDEF', '#123456']);
  });

  test('retired gear is listed', () async {
    await item('d1', '#123456', at: 1, status: EquipmentStatus.retired);

    expect(await repo.getGearColors('d1'), ['#123456']);
  });

  test('a colour in two spellings shows once, normalised', () async {
    await item('d1', '#ff6a00', at: 2);
    await item('d1', '#FF6A00', at: 1);

    expect(await repo.getGearColors('d1'), ['#FF6A00']);
  });

  test('palette colours, non-codes and custom fields are skipped', () async {
    await item('d1', '#F97316', at: 1);
    await item('d1', 'Red', at: 2);
    await item('d1', '#123456', at: 3, custom: true);

    expect(await repo.getGearColors('d1'), isEmpty);
  });

  test('lists at most twelve', () async {
    for (var i = 0; i < 14; i++) {
      await item('d1', '#0000${i.toString().padLeft(2, '0')}', at: i);
    }

    final colors = await repo.getGearColors('d1');
    expect(colors, hasLength(12));
    expect(colors.first, '#000013');
  });
}
