import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/entities/set_history_rewrite.dart';
import 'package:submersion/features/equipment/domain/services/set_history_diff.dart';

/// Which dives a set save must revisit (issues #4283, #4525): the gear a
/// set applies is its own plus that of the sets it includes, and a dive
/// carries the tag of the outer set, so a change to an included set also
/// reaches the dives of every set that includes it.
void main() {
  final t = DateTime(2026, 11, 1);

  EquipmentSet set(
    String id, {
    List<String> gear = const [],
    List<String> includes = const [],
    List<String> presets = const [],
  }) => EquipmentSet(
    id: id,
    diverId: 'd1',
    name: id,
    equipmentIds: gear,
    includedSetIds: includes,
    weightPresetIds: presets,
    createdAt: t,
    updatedAt: t,
  );

  Map<String, Set<SetHistoryRewrite>> diff({
    required EquipmentSet before,
    required EquipmentSet after,
    required List<EquipmentSet> all,
  }) => {
    for (final change in setHistoryRewrites(
      before: before,
      after: after,
      allSets: all,
    ))
      change.setId: change.rewrites.toSet(),
  };

  test('own gear added and removed is replayed on the set', () {
    final before = set('s', gear: ['a', 'b']);
    final after = set('s', gear: ['b', 'c']);
    expect(diff(before: before, after: after, all: [before]), {
      's': {const SetItemAdded('c'), const SetItemRemoved('a')},
    });
  });

  test('including a set adds its gear, and dropping it removes it', () {
    final rig = set('rig', gear: ['bp', 'reg']);
    final before = set('outer', gear: ['cam']);
    final after = set('outer', gear: ['cam'], includes: ['rig']);
    expect(diff(before: before, after: after, all: [rig, before]), {
      'outer': {const SetItemAdded('bp'), const SetItemAdded('reg')},
    });
    expect(diff(before: after, after: before, all: [rig, after]), {
      'outer': {const SetItemRemoved('bp'), const SetItemRemoved('reg')},
    });
  });

  test('editing an included set reaches the sets that include it', () {
    final before = set('rig', gear: ['bp']);
    final after = set('rig', gear: ['bp', 'reg']);
    final outer = set('outer', gear: ['cam'], includes: ['rig']);
    final other = set('other', gear: ['x']);
    expect(diff(before: before, after: after, all: [before, outer, other]), {
      'rig': {const SetItemAdded('reg')},
      'outer': {const SetItemAdded('reg')},
    });
  });

  test('gear an included set still provides is not removed', () {
    final rig = set('rig', gear: ['reg']);
    final before = set('outer', gear: ['reg', 'cam'], includes: ['rig']);
    final after = set('outer', gear: ['cam'], includes: ['rig']);
    expect(diff(before: before, after: after, all: [rig, before]), isEmpty);
  });

  test('gear the outer set already has is not added again', () {
    final before = set('rig', gear: ['bp']);
    final after = set('rig', gear: ['bp', 'cam']);
    final outer = set('outer', gear: ['cam'], includes: ['rig']);
    expect(diff(before: before, after: after, all: [before, outer]), {
      'rig': {const SetItemAdded('cam')},
    });
  });

  test('a change to weights only replays nothing', () {
    final before = set('s', gear: ['a']);
    final after = set('s', gear: ['a'], presets: ['p1']);
    expect(diff(before: before, after: after, all: [before]), isEmpty);
  });

  test('the edited set comes first, then outer sets', () {
    final before = set('rig', gear: ['bp']);
    final after = set('rig', gear: ['bp', 'reg']);
    final outer = set('outer', includes: ['rig']);
    final changes = setHistoryRewrites(
      before: before,
      after: after,
      allSets: [outer, before],
    );
    expect(changes.map((c) => c.setId), ['rig', 'outer']);
  });
}
