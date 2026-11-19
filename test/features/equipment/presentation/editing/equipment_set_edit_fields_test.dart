import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set_geofence.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_set_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/helpers/equipment_set_form_values.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

EquipmentSetGeofence _fence(String id, {double radius = 100, String? label}) =>
    EquipmentSetGeofence(
      id: id,
      setId: 's1',
      label: label,
      latitude: 1,
      longitude: 2,
      radiusMeters: radius,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

EquipmentSet _set({
  List<String> members = const ['e1', 'e2'],
  List<EquipmentSetGeofence>? fences,
}) => EquipmentSet(
  id: 's1',
  name: 'Cold water',
  equipmentIds: members,
  geofences: fences ?? [_fence('g1')],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

/// The set page's values and the rules they keep (issue #4527, phase 3).
void main() {
  group('rebasedSetMembers', () {
    test('keeps a member added underneath', () {
      expect(
        rebasedSetMembers(
          atStart: const ['e1', 'e2'],
          held: const ['e1'],
          atSave: const ['e1', 'e2', 'e4'],
        ),
        ['e1', 'e4'],
      );
    });

    test('applies only the sitting\'s additions and removals', () {
      expect(
        rebasedSetMembers(
          atStart: const ['e1', 'e2'],
          held: const ['e2', 'e3'],
          atSave: const ['e1', 'e2'],
        ),
        ['e2', 'e3'],
      );
    });

    test('an addition already made underneath is not doubled', () {
      expect(
        rebasedSetMembers(
          atStart: const ['e1'],
          held: const ['e1', 'e3'],
          atSave: const ['e1', 'e3'],
        ),
        ['e1', 'e3'],
      );
    });
  });

  group('rebasedGeofences', () {
    test('keeps a fence added underneath while another is edited', () {
      final edited = _fence('g1', radius: 250);
      final result = rebasedGeofences(
        atStart: [_fence('g1')],
        held: [edited],
        atSave: [_fence('g1'), _fence('g9')],
      );
      expect(result.map((g) => g.id), ['g1', 'g9']);
      expect(result.first.radiusMeters, 250);
    });

    test('an edit to a fence deleted underneath is dropped', () {
      final result = rebasedGeofences(
        atStart: [_fence('g1')],
        held: [_fence('g1', radius: 250)],
        atSave: const [],
      );
      expect(result, isEmpty);
    });

    test('a removed fence goes and a new one is added after', () {
      final result = rebasedGeofences(
        atStart: [_fence('g1'), _fence('g2')],
        held: [_fence('g2'), _fence('g3')],
        atSave: [_fence('g1'), _fence('g2')],
      );
      expect(result.map((g) => g.id), ['g2', 'g3']);
    });
  });

  group('fields', () {
    test('a members edit keeps a member another device added', () {
      final session = EditSession(_set());
      session.set(setMembersField, membersTicked(session, 'e2', false));
      final underneath = _set(members: const ['e1', 'e2', 'e4']);

      expect(session.applyTo(underneath).equipmentIds, ['e1', 'e4']);
    });

    test('the base survives the stored set changing underneath', () {
      final session = EditSession(_set());
      session.set(setMembersField, membersTicked(session, 'e2', false));
      session.rebase(_set(members: const ['e1', 'e2', 'e4']));

      expect(session.working.equipmentIds, ['e1', 'e4']);
    });

    test('ticking back what was stored leaves the session clean', () {
      final session = EditSession(_set());
      session.set(setMembersField, membersTicked(session, 'e2', false));
      session.set(setMembersField, membersTicked(session, 'e2', true));

      expect(session.isDirty, isFalse);
    });

    test('members untouched stay as stored', () {
      final session = EditSession(_set())..set(setNameField, 'Warm water');
      final underneath = _set(members: const ['e1', 'e2', 'e4']);

      expect(session.applyTo(underneath).equipmentIds, ['e1', 'e2', 'e4']);
    });

    test('a geofence re-saved unchanged is not a change', () {
      final session = EditSession(_set());
      session.set(
        setGeofencesField,
        geofencesEdited(session, [
          _fence('g1').copyWith(updatedAt: DateTime(2027)),
        ]),
      );

      expect(session.isDirty, isFalse);
    });

    test('a geofence edit keeps a fence another device added', () {
      final session = EditSession(_set());
      session.set(
        setGeofencesField,
        geofencesEdited(session, [_fence('g1', radius: 250)]),
      );
      final underneath = _set(fences: [_fence('g1'), _fence('g9')]);

      final fences = session.applyTo(underneath).geofences;
      expect(fences.map((g) => g.id), ['g1', 'g9']);
      expect(fences.first.radiusMeters, 250);
    });

    test('a weight preset added keeps the included sets another device '
        'changed', () {
      final session = EditSession(_set().copyWith(includedSetIds: ['s0']));
      setBundleLists(
        session,
        const SetBundleListValues(
          includedSetIds: ['s0'],
          weightPresetIds: ['p1'],
        ),
      );
      final underneath = _set().copyWith(includedSetIds: ['s9']);

      final merged = session.applyTo(underneath);
      expect(merged.includedSetIds, ['s9']);
      expect(merged.weightPresetIds, ['p1']);
      expect(session.changedCardIds, {'bundle'});
    });

    test('name and description are trimmed', () {
      final session = EditSession(_set())
        ..set(setNameField, '  Warm  ')
        ..set(setDescriptionField, ' Tropics ');

      expect(session.working.name, 'Warm');
      expect(session.working.description, 'Tropics');
    });

    test('a name of spaces is invalid', () {
      expect(setNameValid('   '), isFalse);
      expect(setNameValid(' Warm '), isTrue);
    });

    test('each field marks its own card', () {
      expect(setNameField.cardId, 'header');
      expect(setDefaultField.cardId, 'header');
      expect(setAutoApplyField.cardId, 'header');
      expect(setShowFigureField.cardId, 'figure');
      expect(setMembersField.cardId, 'members');
      expect(setIncludedSetsField.cardId, 'bundle');
      expect(setWeightPresetsField.cardId, 'bundle');
      expect(setCylinderConfigsField.cardId, 'bundle');
      expect(setGeofencesField.cardId, 'geofences');
    });
  });

  group('setItemsInSitting', () {
    EquipmentItem item(String id) =>
        EquipmentItem(id: id, name: id, type: EquipmentType.bcd);
    final every = [item('e1'), item('e2'), item('e3')];
    final included = EquipmentSet(
      id: 's0',
      name: 'Fins',
      equipmentIds: const ['e3'],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    test("includes an included set's gear", () {
      final working = _set().copyWith(includedSetIds: ['s0']);
      final items = setItemsInSitting(
        working,
        storedItems: const [],
        everyItem: every,
        allSets: [included],
      );
      expect(items.map((i) => i.id), ['e3', 'e1', 'e2']);
    });

    test('keeps a member no longer shared from the stored items', () {
      final items = setItemsInSitting(
        _set(members: const ['e1', 'gone']),
        storedItems: [item('gone')],
        everyItem: every,
        allSets: const [],
      );
      expect(items.map((i) => i.id), ['e1', 'gone']);
    });

    test('follows an included set added in the sitting', () {
      final session = EditSession(_set());
      session.set(setIncludedSetsField, const ['s0']);
      final items = setItemsInSitting(
        session.working,
        storedItems: const [],
        everyItem: every,
        allSets: [included, _set()],
      );
      expect(items.map((i) => i.id), ['e3', 'e1', 'e2']);
    });
  });
}
