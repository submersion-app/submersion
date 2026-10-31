import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/reports/report_gear_sets.dart';

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

void main() {
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

    test('idle candidates drop spares and parts', () {
      expect(isIdleCandidate(_item('a'), 'me'), isTrue);
      expect(
        isIdleCandidate(_item('a', status: EquipmentStatus.spare), 'me'),
        isFalse,
      );
      expect(isIdleCandidate(_item('a', parent: 'p'), 'me'), isFalse);
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

    test('survives a loop', () {
      final ids = withInstalledParts('a', [
        _item('a', parent: 'b'),
        _item('b', parent: 'a'),
      ]);
      expect(ids, {'a', 'b'});
    });
  });
}
