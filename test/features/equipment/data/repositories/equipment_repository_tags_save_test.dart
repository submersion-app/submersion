import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_tag_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../../helpers/test_database.dart';

/// The edit page saves an item and its tags together (issue #1942).
void main() {
  late EquipmentRepository equipment;
  late EquipmentTagRepository tags;

  setUp(() async {
    await setUpTestDatabase();
    equipment = EquipmentRepository();
    tags = EquipmentTagRepository();
    await DatabaseService.instance.database.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at, '
      'applies_to_dives, applies_to_sites, applies_to_equipment) VALUES '
      "('t1', 'Travel kit', 0, 0, 0, 0, 1), "
      "('t2', 'Rental', 0, 0, 0, 0, 1)",
    );
  });

  tearDown(() async => tearDownTestDatabase());

  Future<List<String>> tagIdsOf(String equipmentId) async => [
    for (final t in await tags.getTagsForEquipment(equipmentId)) t.id,
  ];

  Future<int> linkCount() async {
    final row = await DatabaseService.instance.database
        .customSelect('SELECT COUNT(*) AS n FROM equipment_tags')
        .getSingle();
    return row.read<int>('n');
  }

  test('createEquipmentWithTags writes the row and its tags', () async {
    final item = await equipment.createEquipmentWithTags(
      const EquipmentItem(id: '', name: 'Wing', type: EquipmentType.bcd),
      ['t2', 't1'],
    );

    expect((await equipment.getEquipmentById(item.id))!.name, 'Wing');
    // Read back by name.
    expect(await tagIdsOf(item.id), ['t2', 't1']);
  });

  test('a failing tag write leaves no new item behind', () async {
    await expectLater(
      equipment.createEquipmentWithTags(
        const EquipmentItem(
          id: 'fixed',
          name: 'Doomed',
          type: EquipmentType.bcd,
        ),
        // A tag id with no tags row violates the equipment_tags foreign key,
        // after 't1' has already been linked.
        ['t1', 'missing'],
      ),
      throwsA(anything),
    );

    expect(await equipment.getEquipmentById('fixed'), isNull);
    expect(await linkCount(), 0);
  });

  test('updateEquipmentWithTags replaces the set with the row', () async {
    final item = await equipment.createEquipmentWithTags(
      const EquipmentItem(id: '', name: 'Wing', type: EquipmentType.bcd),
      ['t1'],
    );

    await equipment.updateEquipmentWithTags(
      item.copyWith(name: 'Wing renamed'),
      ['t2'],
    );

    expect((await equipment.getEquipmentById(item.id))!.name, 'Wing renamed');
    expect(await tagIdsOf(item.id), ['t2']);
  });

  test(
    'a failing tag write on update keeps the old row and the old set',
    () async {
      final item = await equipment.createEquipmentWithTags(
        const EquipmentItem(id: '', name: 'Wing', type: EquipmentType.bcd),
        ['t1'],
      );

      await expectLater(
        equipment.updateEquipmentWithTags(item.copyWith(name: 'Wing renamed'), [
          't2',
          'missing',
        ]),
        throwsA(anything),
      );

      expect((await equipment.getEquipmentById(item.id))!.name, 'Wing');
      expect(await tagIdsOf(item.id), ['t1']);
    },
  );

  /// Counts sync notifications while [action] runs. Auto-sync must hear of
  /// a save once, after it commits: never mid-transaction, and never for a
  /// save that rolled back.
  Future<int> notificationsDuring(Future<void> Function() action) async {
    var count = 0;
    final subscription = SyncEventBus.changes.listen((_) => count++);
    try {
      await action();
    } catch (_) {
      // The rollback cases throw by design; only the count matters here.
    }
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    return count;
  }

  test('saving an item with its tags notifies sync once', () async {
    late EquipmentItem item;
    expect(
      await notificationsDuring(() async {
        item = await equipment.createEquipmentWithTags(
          const EquipmentItem(id: '', name: 'Wing', type: EquipmentType.bcd),
          ['t1'],
        );
      }),
      1,
      reason: 'create',
    );
    expect(
      await notificationsDuring(
        () => equipment.updateEquipmentWithTags(
          item.copyWith(name: 'Wing renamed'),
          ['t2'],
        ),
      ),
      1,
      reason: 'update',
    );
  });

  test('a save whose tag write rolls back never notifies sync', () async {
    final item = await equipment.createEquipmentWithTags(
      const EquipmentItem(id: '', name: 'Wing', type: EquipmentType.bcd),
      ['t1'],
    );

    expect(
      await notificationsDuring(
        () => equipment.createEquipmentWithTags(
          const EquipmentItem(id: '', name: 'Doomed', type: EquipmentType.bcd),
          ['t1', 'missing'],
        ),
      ),
      0,
      reason: 'create',
    );
    expect(
      await notificationsDuring(
        () => equipment.updateEquipmentWithTags(item, ['t2', 'missing']),
      ),
      0,
      reason: 'update',
    );
  });

  test('updateEquipment with a partial entity leaves the tags alone', () async {
    final item = await equipment.createEquipmentWithTags(
      const EquipmentItem(id: '', name: 'Wing', type: EquipmentType.bcd),
      ['t1', 't2'],
    );

    // A partially built entity, as the dive-joined mappers produce.
    await equipment.updateEquipment(
      EquipmentItem(id: item.id, name: 'Wing', type: EquipmentType.bcd),
    );

    expect(await tagIdsOf(item.id), ['t2', 't1']);
  });
}
