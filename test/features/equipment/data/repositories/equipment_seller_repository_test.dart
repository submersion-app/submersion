import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../../helpers/test_database.dart';

/// The seller links on a gear item (issue #5140) survive a save and every
/// read path.
void main() {
  late AppDatabase db;
  late EquipmentRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentRepository();
    await db.customStatement(
      'INSERT INTO buddies (id, name, created_at, updated_at) '
      "VALUES ('b1', 'Anna Berg', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dive_centers (id, name, created_at, updated_at) '
      "VALUES ('c1', 'Anchor Dive', 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  test('a buddy seller link round-trips through create and read', () async {
    final created = await repo.createEquipment(
      const EquipmentItem(
        id: '',
        name: 'Reg',
        type: EquipmentType.regulator,
        sellerBuddyId: 'b1',
      ),
    );

    final read = await repo.getEquipmentById(created.id);
    expect(read!.sellerBuddyId, 'b1');
    expect(read.sellerDiveCenterId, isNull);
  });

  test('an update moves the link from a buddy to a dive centre', () async {
    final created = await repo.createEquipment(
      const EquipmentItem(
        id: '',
        name: 'Reg',
        type: EquipmentType.regulator,
        sellerBuddyId: 'b1',
      ),
    );
    final stored = (await repo.getEquipmentById(created.id))!;

    await repo.updateEquipment(
      stored.copyWith(clearSellerLinks: true, sellerDiveCenterId: 'c1'),
    );

    final read = await repo.getEquipmentById(created.id);
    expect(read!.sellerBuddyId, isNull);
    expect(read.sellerDiveCenterId, 'c1');
  });

  test('search results carry the seller links', () async {
    await repo.createEquipment(
      const EquipmentItem(
        id: '',
        name: 'Wing',
        type: EquipmentType.bcd,
        sellerDiveCenterId: 'c1',
      ),
    );

    final found = await repo.searchEquipment('Wing');
    expect(found.single.sellerDiveCenterId, 'c1');
  });
}
