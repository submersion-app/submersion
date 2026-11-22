import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/helpers/equipment_set_form_values.dart';

void main() {
  group('bundle lists (issue #4525)', () {
    test('a list change is a change', () {
      expect(
        const SetBundleListValues(weightPresetIds: ['p1']),
        isNot(SetBundleListValues.empty),
      );
      expect(
        const SetBundleListValues(includedSetIds: ['s']),
        isNot(SetBundleListValues.empty),
      );
      expect(
        const SetBundleListValues(cylinderConfigIds: ['c']),
        isNot(SetBundleListValues.empty),
      );
    });

    test('a reorder is a change', () {
      expect(
        const SetBundleListValues(weightPresetIds: ['p1', 'p2']),
        isNot(const SetBundleListValues(weightPresetIds: ['p2', 'p1'])),
      );
    });

    test("of() reads a saved set's lists", () {
      final lists = SetBundleListValues.of(
        EquipmentSet(
          id: 's1',
          name: 'Cold Water',
          equipmentIds: const ['a', 'b'],
          includedSetIds: const ['rig'],
          weightPresetIds: const ['p1'],
          cylinderConfigIds: const ['c1'],
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      expect(lists.includedSetIds, ['rig']);
      expect(lists.weightPresetIds, ['p1']);
      expect(lists.cylinderConfigIds, ['c1']);
    });
  });

  // A set's loaded items are what it applies, the gear of the sets it
  // includes too (issue #4525). Only its own members can be "no longer
  // shared" members of it.
  group('unsharedSetMembers', () {
    final at = DateTime(2026, 11, 1);
    EquipmentItem item(String id) =>
        EquipmentItem(id: id, name: id, type: EquipmentType.regulator);
    final set = EquipmentSet(
      id: 'outer',
      name: 'Outer',
      equipmentIds: const ['own', 'ownHidden'],
      includedSetIds: const ['rig'],
      items: [item('own'), item('ownHidden'), item('includedHidden')],
      createdAt: at,
      updatedAt: at,
    );

    test('lists the set\'s own members the diver cannot see', () {
      expect(unsharedSetMembers(set, {'own'}).map((i) => i.id), ['ownHidden']);
    });

    test('lists nothing until the visible gear is known, or for no set', () {
      expect(unsharedSetMembers(set, null), isEmpty);
      expect(unsharedSetMembers(null, {'own'}), isEmpty);
    });
  });
}
