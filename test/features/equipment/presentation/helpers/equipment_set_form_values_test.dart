import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/features/equipment/presentation/helpers/equipment_set_form_values.dart';

void main() {
  EquipmentSetGeofence fence({
    String id = 'f1',
    double radius = 500,
    DateTime? updatedAt,
  }) => EquipmentSetGeofence(
    id: id,
    setId: 's1',
    label: 'Breakwater',
    latitude: 36.6,
    longitude: -121.9,
    radiusMeters: radius,
    createdAt: DateTime(2026),
    updatedAt: updatedAt ?? DateTime(2026),
  );

  EquipmentSetFormValues values({
    String name = 'Cold Water',
    String description = '',
    Set<String> ids = const {'a', 'b'},
    bool isDefault = false,
    bool autoApply = false,
    bool showFigure = true,
    List<EquipmentSetGeofence> geofences = const [],
  }) => EquipmentSetFormValues(
    name: name,
    description: description,
    equipmentIds: ids,
    isDefault: isDefault,
    autoApplyOnComputerImport: autoApply,
    showFigure: showFigure,
    geofences: geofences,
  );

  test('the same values are equal', () {
    expect(values(), values());
  });

  test('member order does not matter', () {
    expect(values(ids: {'a', 'b'}), values(ids: {'b', 'a'}));
  });

  test('surrounding whitespace in the text fields does not matter', () {
    expect(values(name: ' Cold Water  '), values(name: 'Cold Water'));
    expect(values(description: 'x\n'), values(description: 'x'));
  });

  test('each field counts as a change', () {
    final base = values();
    expect(values(name: 'Warm'), isNot(base));
    expect(values(description: 'Notes'), isNot(base));
    expect(values(ids: {'a'}), isNot(base));
    expect(values(isDefault: true), isNot(base));
    expect(values(autoApply: true), isNot(base));
    expect(values(showFigure: false), isNot(base));
    expect(values(geofences: [fence()]), isNot(base));
  });

  test('a geofence re-saved unchanged is not a change', () {
    expect(
      values(geofences: [fence()]),
      values(geofences: [fence(updatedAt: DateTime(2027))]),
    );
  });

  test('a geofence with a new radius is a change', () {
    expect(
      values(geofences: [fence()]),
      isNot(values(geofences: [fence(radius: 800)])),
    );
  });

  test('of() reads a saved set', () {
    final set = EquipmentSet(
      id: 's1',
      name: 'Cold Water',
      description: 'Drysuit',
      equipmentIds: const ['a', 'b'],
      isDefault: true,
      autoApplyOnComputerImport: true,
      showFigure: false,
      geofences: [fence()],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    expect(
      EquipmentSetFormValues.of(set),
      values(
        description: 'Drysuit',
        isDefault: true,
        autoApply: true,
        showFigure: false,
        geofences: [fence()],
      ),
    );
  });

  test('retainingEquipment drops only the members it rejects', () {
    final opened = values(isDefault: true, geofences: [fence()]);
    expect(
      opened.retainingEquipment((id) => id != 'b'),
      values(ids: const {'a'}, isDefault: true, geofences: [fence()]),
    );
  });

  test('blank matches a new form', () {
    expect(EquipmentSetFormValues.blank, values(name: '', ids: const {}));
  });

  group('bundle lists (issue #4525)', () {
    EquipmentSetFormValues withLists(SetBundleListValues lists) =>
        EquipmentSetFormValues(
          name: 'Cold Water',
          description: '',
          equipmentIds: const {'a'},
          isDefault: false,
          autoApplyOnComputerImport: false,
          showFigure: true,
          geofences: const [],
          lists: lists,
        );

    test('a list change is a change', () {
      expect(
        withLists(const SetBundleListValues(weightPresetIds: ['p1'])),
        isNot(withLists(SetBundleListValues.empty)),
      );
      expect(
        withLists(const SetBundleListValues(includedSetIds: ['s'])),
        isNot(withLists(SetBundleListValues.empty)),
      );
      expect(
        withLists(const SetBundleListValues(cylinderConfigIds: ['c'])),
        isNot(withLists(SetBundleListValues.empty)),
      );
    });

    test('a reorder is a change', () {
      expect(
        withLists(const SetBundleListValues(weightPresetIds: ['p1', 'p2'])),
        isNot(
          withLists(const SetBundleListValues(weightPresetIds: ['p2', 'p1'])),
        ),
      );
    });

    test('the form opens with the set\'s lists and keeps them when gear '
        'is pruned', () {
      final opened = EquipmentSetFormValues.of(
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
      expect(opened.lists.includedSetIds, ['rig']);
      expect(opened.lists.weightPresetIds, ['p1']);
      expect(opened.lists.cylinderConfigIds, ['c1']);
      expect(opened.retainingEquipment((id) => id == 'a').lists, opened.lists);
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
