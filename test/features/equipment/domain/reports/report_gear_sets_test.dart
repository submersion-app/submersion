import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/reports/report_gear_sets.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';

EquipmentItem _item(
  String id, {
  String? diverId = 'me',
  EquipmentStatus status = EquipmentStatus.active,
  bool isActive = true,
  String? parent,
}) => EquipmentItem(
  id: id,
  diverId: diverId,
  name: id,
  type: EquipmentType.regulator,
  status: status,
  isActive: isActive,
  parentEquipmentId: parent,
);

ComponentsIndex _index(List<(String, String)> edges) =>
    ComponentsIndex.fromRows([
      for (final (parent, part) in edges)
        EquipmentComponent(
          id: '$parent-$part',
          parentEquipmentId: parent,
          componentEquipmentId: part,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
    ]);

void main() {
  group('withAssemblyParents', () {
    String? parentOf(List<EquipmentItem> items, String id) =>
        items.firstWhere((i) => i.id == id).parentEquipmentId;

    test('gives an assembly part its assembly as parent', () {
      final items = withAssemblyParents([
        _item('set'),
        _item('first'),
      ], _index([('set', 'first')]));
      expect(parentOf(items, 'first'), 'set');
      expect(parentOf(items, 'set'), isNull);
    });

    test('keeps an installed-in parent', () {
      final items = withAssemblyParents([
        _item('set'),
        _item('other'),
        _item('cell', parent: 'other'),
      ], _index([('set', 'cell')]));
      expect(parentOf(items, 'cell'), 'other');
    });

    test('ignores an assembly that is not in the list', () {
      final items = withAssemblyParents([
        _item('first'),
      ], _index([('gone', 'first')]));
      expect(parentOf(items, 'first'), isNull);
    });

    test('a shared part goes under a fitted assembly, then the first by '
        'name', () {
      final items = withAssemblyParents([
        _item('zed'),
        _item('abe'),
        _item('old', status: EquipmentStatus.retired),
        _item('stage'),
      ], _index([('old', 'stage'), ('zed', 'stage'), ('abe', 'stage')]));
      expect(parentOf(items, 'stage'), 'abe');
    });

    test('leaves every other field alone', () {
      final items = withAssemblyParents([
        _item('set'),
        _item('first', diverId: 'them'),
      ], _index([('set', 'first')]));
      expect(items.last.diverId, 'them');
    });
  });

  group('gearWithParts', () {
    test('keeps a retired root and drops its retired parts', () {
      final gear = gearWithParts(
        {'set'},
        [
          _item('set', status: EquipmentStatus.retired),
          _item('live', parent: 'set'),
          _item('dead', parent: 'set', status: EquipmentStatus.retired),
          _item('other'),
        ],
        ComponentsIndex.empty,
      );
      expect(gear.map((i) => i.id), ['set', 'live']);
    });

    test('drops wishlist gear, even as a root', () {
      final gear = gearWithParts(
        {'wish'},
        [_item('wish', status: EquipmentStatus.wanted)],
        ComponentsIndex.empty,
      );
      expect(gear, isEmpty);
    });

    test('brings a shared part under each of its assemblies', () {
      final gear = gearWithParts(
        {'din'},
        [_item('din'), _item('yoke'), _item('stage', parent: 'yoke')],
        _index([('din', 'stage'), ('yoke', 'stage')]),
      );
      expect(gear.map((i) => i.id), ['din', 'stage']);
    });
  });

  group('gear sets', () {
    test('owned now keeps fitted gear and drops the rest', () {
      for (final status in [
        EquipmentStatus.active,
        EquipmentStatus.spare,
        EquipmentStatus.needsService,
        EquipmentStatus.inService,
        EquipmentStatus.loaned,
      ]) {
        expect(isOwnedNow(_item('a', status: status), 'me'), isTrue);
      }
      for (final status in [
        EquipmentStatus.retired,
        EquipmentStatus.sold,
        EquipmentStatus.wanted,
        EquipmentStatus.lost,
      ]) {
        expect(isOwnedNow(_item('a', status: status), 'me'), isFalse);
      }
      expect(isOwnedNow(_item('a', isActive: false), 'me'), isFalse);
    });

    test("another profile's item is not owned now but is serviceable", () {
      final shared = _item('a', diverId: 'them');
      expect(isOwnedNow(shared, 'me'), isFalse);
      expect(isServiceable(shared), isTrue);
    });

    test('serviceable drops lost and retired gear', () {
      expect(isServiceable(_item('a', status: EquipmentStatus.lost)), isFalse);
      expect(
        isServiceable(_item('a', status: EquipmentStatus.retired)),
        isFalse,
      );
    });

    test('ever owned keeps sold and retired, drops wanted', () {
      expect(
        isEverOwned(_item('a', status: EquipmentStatus.sold), 'me'),
        isTrue,
      );
      expect(
        isEverOwned(_item('a', status: EquipmentStatus.retired), 'me'),
        isTrue,
      );
      expect(
        isEverOwned(_item('a', status: EquipmentStatus.wanted), 'me'),
        isFalse,
      );
      expect(isEverOwned(_item('a', diverId: 'them'), 'me'), isFalse);
    });

    test('idle candidates drop spares', () {
      expect(isIdleCandidate(_item('a'), 'me'), isTrue);
      expect(
        isIdleCandidate(_item('a', status: EquipmentStatus.spare), 'me'),
        isFalse,
      );
    });

    test('a null diver owns everything', () {
      final other = _item('a', diverId: 'them');
      expect(isOwnedNow(other, null), isTrue);
      expect(isEverOwned(other, null), isTrue);
      expect(isIdleCandidate(other, null), isTrue);
    });

    test('an ownerless item belongs to the active diver', () {
      expect(isOwnedNow(_item('a', diverId: null), 'me'), isTrue);
    });
  });

  group('arrangeAsTree', () {
    test('indents parts under their parent, deepest last', () {
      final rows = arrangeAsTree([
        _item('hose', parent: 'first'),
        _item('other'),
        _item('first', parent: 'set'),
        _item('set'),
      ]);
      expect(
        rows.map((r) => (r.item.id, r.depth)),
        // Top-level rows keep input order; parts nest under them.
        [('other', 0), ('set', 0), ('first', 1), ('hose', 2)],
      );
    });

    test('prints an orphan part at the top level', () {
      final rows = arrangeAsTree([_item('part', parent: 'gone')]);
      expect(rows.single.depth, 0);
    });

    test('survives a parent loop, each item once', () {
      final rows = arrangeAsTree([
        _item('a', parent: 'b'),
        _item('b', parent: 'a'),
        _item('c'),
      ]);
      expect(rows.map((r) => r.item.id).toList()..sort(), ['a', 'b', 'c']);
    });
  });

  group('usageSourceOf', () {
    final items = [_item('set'), _item('first'), _item('second')];
    final index = _index([('set', 'first'), ('set', 'second')]);

    test('reads the item itself when it has dives', () {
      final dives = {'set': 1, 'first': 40};
      expect(usageSourceOf('set', items, index, (id) => dives[id] ?? 0), 'set');
    });

    test('reads the busiest part when only the parts have dives', () {
      final dives = {'first': 12, 'second': 40};
      expect(
        usageSourceOf('set', items, index, (id) => dives[id] ?? 0),
        'second',
      );
    });

    test('stays on the item with no dives anywhere', () {
      expect(usageSourceOf('set', items, index, (_) => 0), 'set');
    });
  });

  group('withInstalledParts', () {
    test('walks every depth', () {
      final ids = withInstalledParts('set', [
        _item('set'),
        _item('first', parent: 'set'),
        _item('hose', parent: 'first'),
        _item('other'),
      ]);
      expect(ids, {'set', 'first', 'hose'});
    });

    test('walks assembly edges too', () {
      final ids = withInstalledParts('set', [
        _item('set'),
        _item('first'),
      ], index: _index([('set', 'first')]));
      expect(ids, {'set', 'first'});
    });

    test('survives a loop', () {
      final ids = withInstalledParts('a', [
        _item('a', parent: 'b'),
        _item('b', parent: 'a'),
      ]);
      expect(ids, {'a', 'b'});
    });
  });
}
