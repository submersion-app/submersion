import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);
  var seq = 0;
  EquipmentComponent edge(String parent, String child) => EquipmentComponent(
    id: 'c${seq++}',
    parentEquipmentId: parent,
    componentEquipmentId: child,
    createdAt: t0,
    updatedAt: t0,
  );
  // kit > reg, fins; reg > first, second. "spare-second" is in reg and in
  // "stage", so it has two assemblies.
  final index = ComponentsIndex.fromRows([
    edge('kit', 'reg'),
    edge('kit', 'fins'),
    edge('reg', 'first'),
    edge('reg', 'second'),
    edge('reg', 'spare-second'),
    edge('stage', 'spare-second'),
  ]);

  group('partsWithin (#2514)', () {
    test('is the parts whose assembly is offered alongside them', () {
      expect(index.partsWithin({'reg', 'first', 'second', 'mask'}), {
        'first',
        'second',
      });
    });

    test('keeps a part whose assembly is not offered', () {
      // The assembly is already on the dive, or Spare, or retired: the part
      // can only be added on its own.
      expect(index.partsWithin({'first', 'second', 'mask'}), isEmpty);
    });

    test('hides every level of a nested assembly under an offered root', () {
      expect(index.partsWithin({'kit', 'reg', 'fins', 'first', 'second'}), {
        'reg',
        'fins',
        'first',
        'second',
      });
    });

    test('hides a part under a sub-assembly offered without its root', () {
      expect(index.partsWithin({'reg', 'fins', 'first'}), {'first'});
    });

    test('hides a shared part when any one of its assemblies is offered', () {
      expect(index.partsWithin({'stage', 'spare-second'}), {'spare-second'});
    });

    test('leaves out an item that would hide itself through a bad loop', () {
      final looped = ComponentsIndex.fromRows([edge('odd', 'odd')]);
      expect(looped.partsWithin({'odd'}), isEmpty);
    });

    test('a longer bad loop hides neither member through the other', () {
      // a > b > a, and "root" holds a: the loop alone must not hide both.
      final looped = ComponentsIndex.fromRows([
        edge('a', 'b'),
        edge('b', 'a'),
        edge('root', 'a'),
      ]);
      expect(looped.partsWithin({'a', 'b'}), isEmpty);
      expect(looped.partsWithin({'root', 'a', 'b'}), {'a'});
    });

    test('keeps a shared part whose other assembly is on the dive', () {
      // reg is attached, so the dropped spare second goes back beside it,
      // even though "stage" is offered and holds it too.
      expect(
        index.partsWithin({'stage', 'spare-second'}, attached: {'reg'}),
        isEmpty,
      );
      expect(index.partsWithin({'stage', 'spare-second'}, attached: {'mask'}), {
        'spare-second',
      });
    });

    test('is empty with no assemblies', () {
      expect(ComponentsIndex.empty.partsWithin({'a', 'b'}), isEmpty);
    });
  });
}
