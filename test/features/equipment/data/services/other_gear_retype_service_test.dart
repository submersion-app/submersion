import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/other_gear_retype_service.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/other_gear_retype.dart';

import '../../../../helpers/test_database.dart';

/// Fails every write to the item named [failingName].
class _FailingRepository extends EquipmentRepository {
  _FailingRepository(this.failingName);

  final String failingName;

  @override
  Future<void> updateEquipment(EquipmentItem equipment, {bool notify = true}) {
    if (equipment.name == failingName) throw StateError('write failed');
    return super.updateEquipment(equipment);
  }
}

/// Fails every attribute save: [updateEquipment] has already written the
/// equipment row by then, so only a transaction can take it back.
class _AttributesFail extends EquipmentRepository {
  @override
  Future<void> saveAttributes(
    String equipmentId,
    List<EquipmentAttribute> desired, {
    bool preserveSystem = true,
  }) async {
    throw StateError('attributes failed');
  }
}

void main() {
  late AppDatabase db;
  late EquipmentRepository repo;
  late OtherGearRetypeService service;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = EquipmentRepository();
    service = OtherGearRetypeService(repo);
    final t = DateTime.now().millisecondsSinceEpoch;
    for (final id in ['d1', 'd2']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: t,
              updatedAt: t,
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  Future<EquipmentItem> add(
    String name, {
    EquipmentType type = EquipmentType.other,
    String diverId = 'd1',
    List<EquipmentAttribute> attributes = const [],
  }) => repo.createEquipment(
    EquipmentItem(
      id: '',
      diverId: diverId,
      name: name,
      type: type,
      attributes: attributes,
    ),
  );

  String? thicknessOf(EquipmentItem item) => item.attributes
      .where((a) => !a.isCustom && a.key == EquipmentAttrKeys.thicknessMm)
      .map((a) => a.valueText)
      .firstOrNull;

  Future<bool> isPending(String id) async {
    final rows = await db.select(db.syncRecords).get();
    return rows.any((r) => r.entityType == 'equipment' && r.recordId == id);
  }

  group('findCandidates', () {
    test("lists the diver's Other items whose name says what they are, "
        'by name', () async {
      await add('Apeks fins');
      await add('7mm Wetsuit');
      await add('Hydros Pro');
      await add('Drysuit', type: EquipmentType.drysuit);
      await add('Other diver wetsuit', diverId: 'd2');

      final candidates = await service.findCandidates('d1');

      expect(
        [for (final c in candidates) (c.item.name, c.type, c.thickness)],
        [
          ('7mm Wetsuit', EquipmentType.wetsuit, '7mm'),
          ('Apeks fins', EquipmentType.fins, null),
        ],
      );
    });

    test('proposes no thickness when the item already has one', () async {
      await add(
        '7mm Wetsuit',
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: '',
            key: EquipmentAttrKeys.thicknessMm,
            valueText: '5',
            valueNum: 5,
          ),
        ],
      );

      final candidates = await service.findCandidates('d1');

      expect(candidates.single.type, EquipmentType.wetsuit);
      expect(candidates.single.thickness, isNull);
    });
  });

  group('apply', () {
    test(
      'retypes each item, writes its thickness and marks it for sync',
      () async {
        final suit = await add('7mm Wetsuit');
        final fins = await add('Apeks fins');
        await db.delete(db.syncRecords).go();

        final receipt = await service.apply(await service.findCandidates('d1'));

        expect(receipt.failed, 0);
        expect(
          [
            for (final r in receipt.retyped)
              (r.id, r.before.type, r.after.type, thicknessOf(r.after)),
          ],
          [
            (suit.id, EquipmentType.other, EquipmentType.wetsuit, '7mm'),
            (fins.id, EquipmentType.other, EquipmentType.fins, null),
          ],
        );
        final storedSuit = (await repo.getEquipmentById(suit.id))!;
        expect(storedSuit.type, EquipmentType.wetsuit);
        expect(thicknessOf(storedSuit), '7mm');
        expect(
          (await repo.getEquipmentById(fins.id))!.type,
          EquipmentType.fins,
        );
        expect(await isPending(suit.id), isTrue);
        expect(await isPending(fins.id), isTrue);
        expect(await service.findCandidates('d1'), isEmpty);
      },
    );

    test('keeps the attributes the item already had', () async {
      final suit = await add(
        '7mm Wetsuit',
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: '',
            key: EquipmentAttrKeys.size,
            valueText: 'L',
          ),
        ],
      );

      await service.apply(await service.findCandidates('d1'));

      final stored = (await repo.getEquipmentById(suit.id))!;
      expect(
        stored.attributes.map((a) => (a.key, a.valueText)),
        containsAll([
          (EquipmentAttrKeys.size, 'L'),
          (EquipmentAttrKeys.thicknessMm, '7mm'),
        ]),
      );
    });

    test('skips an item that is no longer Other', () async {
      final suit = await add('7mm Wetsuit');
      final candidates = await service.findCandidates('d1');
      final edited = (await repo.getEquipmentById(suit.id))!;
      await repo.updateEquipment(edited.copyWith(type: EquipmentType.drysuit));

      final receipt = await service.apply(candidates);

      expect(receipt.retyped, isEmpty);
      expect(receipt.failed, 0);
      expect(
        (await repo.getEquipmentById(suit.id))!.type,
        EquipmentType.drysuit,
      );
    });

    test('counts a failed write and still retypes the rest', () async {
      final fins = await add('Apeks fins');
      await add('7mm Wetsuit');
      final failing = OtherGearRetypeService(_FailingRepository('7mm Wetsuit'));

      final receipt = await failing.apply(await failing.findCandidates('d1'));

      expect(receipt.failed, 1);
      expect(receipt.retyped.map((r) => r.id), [fins.id]);
      expect((await repo.getEquipmentById(fins.id))!.type, EquipmentType.fins);
    });

    test('rolls back an item whose write fails part way', () async {
      final suit = await add('7mm Wetsuit');
      await db.delete(db.syncRecords).go();
      final failing = OtherGearRetypeService(_AttributesFail());

      final receipt = await failing.apply(await failing.findCandidates('d1'));

      expect(receipt.failed, 1);
      expect(receipt.retyped, isEmpty);
      final stored = (await repo.getEquipmentById(suit.id))!;
      expect(stored.type, EquipmentType.other);
      expect(thicknessOf(stored), isNull);
      expect(await isPending(suit.id), isFalse);
    });
  });

  group('undo', () {
    test('restores the type and removes the thickness it added', () async {
      final suit = await add(
        '7mm Wetsuit',
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: '',
            key: EquipmentAttrKeys.size,
            valueText: 'L',
          ),
        ],
      );
      final receipt = await service.apply(await service.findCandidates('d1'));
      await db.delete(db.syncRecords).go();

      final result = await service.undo(receipt);

      expect(result, const RetypeUndoResult(restored: 1));
      final stored = (await repo.getEquipmentById(suit.id))!;
      expect(stored.type, EquipmentType.other);
      expect(thicknessOf(stored), isNull);
      expect(stored.attributes.map((a) => (a.key, a.valueText)), [
        (EquipmentAttrKeys.size, 'L'),
      ]);
      expect(await isPending(suit.id), isTrue);
    });

    test('leaves a thickness the item had before', () async {
      final suit = await add(
        '7mm Wetsuit',
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: '',
            key: EquipmentAttrKeys.thicknessMm,
            valueText: '5',
            valueNum: 5,
          ),
        ],
      );
      final receipt = await service.apply(await service.findCandidates('d1'));

      final result = await service.undo(receipt);

      expect(result, const RetypeUndoResult(restored: 1));
      final stored = (await repo.getEquipmentById(suit.id))!;
      expect(stored.type, EquipmentType.other);
      expect(thicknessOf(stored), '5');
    });

    test('leaves an item retyped again since', () async {
      final suit = await add('7mm Wetsuit');
      final receipt = await service.apply(await service.findCandidates('d1'));
      final current = (await repo.getEquipmentById(suit.id))!;
      await repo.updateEquipment(current.copyWith(type: EquipmentType.drysuit));

      final result = await service.undo(receipt);

      expect(result, const RetypeUndoResult(skipped: 1));
      expect(
        (await repo.getEquipmentById(suit.id))!.type,
        EquipmentType.drysuit,
      );
    });

    test('leaves an item edited since, even at the same type', () async {
      final suit = await add('7mm Wetsuit');
      final receipt = await service.apply(await service.findCandidates('d1'));
      final current = (await repo.getEquipmentById(suit.id))!;
      await repo.updateEquipment(current.copyWith(brand: 'Bare'));

      final result = await service.undo(receipt);

      expect(result, const RetypeUndoResult(skipped: 1));
      final stored = (await repo.getEquipmentById(suit.id))!;
      expect(stored.type, EquipmentType.wetsuit);
      expect(stored.brand, 'Bare');
      expect(thicknessOf(stored), '7mm');
    });

    test('leaves a thickness changed since', () async {
      final suit = await add('7mm Wetsuit');
      final receipt = await service.apply(await service.findCandidates('d1'));
      final current = (await repo.getEquipmentById(suit.id))!;
      await repo.updateEquipment(
        current.copyWith(
          attributes: [
            EquipmentAttribute.curated(
              equipmentId: suit.id,
              key: EquipmentAttrKeys.thicknessMm,
              valueText: '5',
              valueNum: 5,
            ),
          ],
        ),
      );

      final result = await service.undo(receipt);

      expect(result, const RetypeUndoResult(skipped: 1));
      final stored = (await repo.getEquipmentById(suit.id))!;
      expect(stored.type, EquipmentType.wetsuit);
      expect(thicknessOf(stored), '5');
    });

    test('skips an item deleted since', () async {
      final suit = await add('7mm Wetsuit');
      final receipt = await service.apply(await service.findCandidates('d1'));
      await repo.deleteEquipment(suit.id);

      final result = await service.undo(receipt);

      expect(result, const RetypeUndoResult(skipped: 1));
      expect(await repo.getEquipmentById(suit.id), isNull);
    });

    test('rolls back an item whose undo fails part way', () async {
      final suit = await add('7mm Wetsuit');
      final receipt = await service.apply(await service.findCandidates('d1'));

      final result = await OtherGearRetypeService(
        _AttributesFail(),
      ).undo(receipt);

      expect(result, const RetypeUndoResult(failed: 1));
      final stored = (await repo.getEquipmentById(suit.id))!;
      expect(stored.type, EquipmentType.wetsuit);
      expect(thicknessOf(stored), '7mm');
    });
  });
}
