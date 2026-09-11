import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/database/database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late EquipmentRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = EquipmentRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> child(
    String parentId,
    String name,
    EquipmentType type, {
    int? slot,
  }) => repo.createEquipment(
    EquipmentItem(
      id: '',
      name: name,
      type: type,
      parentEquipmentId: parentId,
      attributes: [
        if (slot != null)
          EquipmentAttribute.curated(
            equipmentId: '',
            key: EquipmentAttrKeys.cellSlot,
            valueNum: slot.toDouble(),
          ),
      ],
    ),
  );

  test('cells by slot, then batteries, then any other part', () async {
    final parent = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'Rig', type: EquipmentType.rebreather),
    );
    // Created out of order, and with a strobe, whose enum position sits
    // before the cell's: the order must not depend on when a type was
    // added to the enum.
    await child(parent.id, 'Strobe', EquipmentType.strobe);
    await child(parent.id, 'Battery', EquipmentType.battery);
    await child(parent.id, 'Cell 2', EquipmentType.o2Cell, slot: 2);
    await child(parent.id, 'Cell 1', EquipmentType.o2Cell, slot: 1);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final children = await container.read(
      childEquipmentProvider(parent.id).future,
    );
    expect(children.map((c) => c.name), [
      'Cell 1',
      'Cell 2',
      'Battery',
      'Strobe',
    ]);
  });

  test('a legacy row retired by status alone is not listed', () async {
    final parent = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'Rig', type: EquipmentType.rebreather),
    );
    await child(parent.id, 'Fitted', EquipmentType.o2Cell, slot: 1);
    await child(parent.id, 'Sold', EquipmentType.o2Cell, slot: 2);
    final db = DatabaseService.instance.database;
    await (db.update(db.equipment)..where((t) => t.name.equals('Sold'))).write(
      const EquipmentCompanion(status: Value('sold')),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final children = await container.read(
      childEquipmentProvider(parent.id).future,
    );
    expect(children.map((c) => c.name), ['Fitted']);
  });

  test('an attribute edit reorders an open list', () async {
    // Slots live in equipment_attributes; a write there reaches no
    // equipment row, so the list must watch the attributes too.
    final parent = await repo.createEquipment(
      const EquipmentItem(id: '', name: 'Rig', type: EquipmentType.rebreather),
    );
    await child(parent.id, 'A', EquipmentType.o2Cell, slot: 1);
    await child(parent.id, 'B', EquipmentType.o2Cell, slot: 2);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(childEquipmentProvider(parent.id), (_, _) {});
    addTearDown(sub.close);
    Future<List<String>> names() async => [
      for (final c in await container.read(
        childEquipmentProvider(parent.id).future,
      ))
        c.name,
    ];
    expect(await names(), ['A', 'B']);
    final a = (await names()).isEmpty
        ? null
        : (await container.read(
            childEquipmentProvider(parent.id).future,
          )).first;
    await repo.saveAttributes(a!.id, [
      EquipmentAttribute.curated(
        equipmentId: a.id,
        key: EquipmentAttrKeys.cellSlot,
        valueNum: 3,
      ),
    ]);
    var now = await names();
    for (var i = 0; i < 50 && now.first != 'B'; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      now = await names();
    }
    expect(now, ['B', 'A']);
  });
}
