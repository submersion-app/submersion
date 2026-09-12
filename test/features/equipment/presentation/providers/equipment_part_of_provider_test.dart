import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';

import '../../../../helpers/test_database.dart';

/// The upward view of the assembly graph (issue #1487): what an item is a
/// part of, with each parent's outermost rigs named.
void main() {
  late EquipmentRepository equipment;
  late EquipmentComponentRepository components;

  setUp(() async {
    await setUpTestDatabase();
    equipment = EquipmentRepository();
    components = EquipmentComponentRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<String> item(
    String name,
    EquipmentType type, {
    String id = '',
  }) async => (await equipment.createEquipment(
    EquipmentItem(id: id, name: name, type: type),
  )).id;

  test('lists each parent by name with its top-level rigs', () async {
    // Fixed ids make the graph walk meet "Sidemount" first, so the names
    // only come out alphabetical if they are sorted, and the lowercase
    // "backmount" only lands first if that sort ignores case.
    final sidemount = await item(
      'Sidemount rig',
      EquipmentType.other,
      id: 'a-rig',
    );
    final backmount = await item(
      'backmount rig',
      EquipmentType.other,
      id: 'b-rig',
    );
    final travel = await item('Travel reg', EquipmentType.regulator);
    final cold = await item('Cold water reg', EquipmentType.regulator);
    final octo = await item('XTX50 octopus', EquipmentType.secondStage);
    await components.addComponent(parentId: sidemount, componentId: travel);
    await components.addComponent(parentId: backmount, componentId: travel);
    await components.addComponent(
      parentId: travel,
      componentId: octo,
      role: 'Octopus',
    );
    await components.addComponent(parentId: cold, componentId: octo);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final entries = await container.read(equipmentPartOfProvider(octo).future);

    expect(entries.map((e) => e.edge.parent?.name), [
      'Cold water reg',
      'Travel reg',
    ]);
    expect(entries.map((e) => e.edge.role), ['', 'Octopus']);
    // A top-level parent has no rig above it; a shared one names each.
    expect(entries.first.rootNames, isEmpty);
    expect(entries.last.rootNames, ['backmount rig', 'Sidemount rig']);
  });

  test('an item that is part of nothing has no entries', () async {
    final rig = await item('Rig', EquipmentType.other);
    final reg = await item('Reg', EquipmentType.regulator);
    await components.addComponent(parentId: rig, componentId: reg);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(await container.read(equipmentPartOfProvider(rig).future), isEmpty);
  });
}
