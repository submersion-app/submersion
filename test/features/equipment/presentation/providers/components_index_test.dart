import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);
  var seq = 0;
  EquipmentComponent edge(String parent, String child, {int order = 0}) =>
      EquipmentComponent(
        id: 'c${seq++}',
        parentEquipmentId: parent,
        componentEquipmentId: child,
        sortOrder: order,
        createdAt: t0,
        updatedAt: t0,
      );

  test('fromRows groups both ways and keeps sort order per parent', () {
    final index = ComponentsIndex.fromRows([
      edge('reg', 'hose', order: 2),
      edge('reg', 'first', order: 0),
      edge('kit', 'hose', order: 0),
    ]);
    expect(index.byParent['reg']!.map((c) => c.componentEquipmentId), [
      'first',
      'hose',
    ]);
    expect(index.parentIdsOf('hose'), unorderedEquals(['reg', 'kit']));
    expect(index.componentCount('reg'), 2);
    expect(index.componentCount('hose'), 0);
    expect(index.isAssembly('kit'), isTrue);
    expect(index.isAssembly('first'), isFalse);
  });

  test('equal sort orders fall back to row id so the order is fixed', () {
    final a = EquipmentComponent(
      id: 'zz',
      parentEquipmentId: 'reg',
      componentEquipmentId: 'second',
      createdAt: t0,
      updatedAt: t0,
    );
    final b = EquipmentComponent(
      id: 'aa',
      parentEquipmentId: 'reg',
      componentEquipmentId: 'first',
      createdAt: t0,
      updatedAt: t0,
    );
    for (final rows in [
      [a, b],
      [b, a],
    ]) {
      final index = ComponentsIndex.fromRows(rows);
      expect(index.byParent['reg']!.map((c) => c.id), ['aa', 'zz']);
    }
  });

  test('descendantsOf walks every level and excludes the root', () {
    final index = ComponentsIndex.fromRows([
      edge('kit', 'reg'),
      edge('reg', 'first'),
      edge('first', 'hose'),
      edge('kit', 'wing'),
    ]);
    expect(index.descendantsOf('kit'), {'reg', 'first', 'hose', 'wing'});
    expect(index.descendantsOf('reg'), {'first', 'hose'});
    expect(index.descendantsOf('hose'), isEmpty);
  });

  test('ancestorsOf walks upward', () {
    final index = ComponentsIndex.fromRows([
      edge('kit', 'reg'),
      edge('reg', 'hose'),
    ]);
    expect(index.ancestorsOf('hose'), {'reg', 'kit'});
    expect(index.ancestorsOf('kit'), isEmpty);
  });

  test('a corrupt cycle still terminates', () {
    final index = ComponentsIndex.fromRows([edge('a', 'b'), edge('b', 'a')]);
    expect(index.descendantsOf('a'), {'b', 'a'});
    expect(index.ancestorsOf('a'), {'b', 'a'});
  });

  test('empty is empty', () {
    expect(ComponentsIndex.empty.componentCount('x'), 0);
    expect(ComponentsIndex.empty.descendantsOf('x'), isEmpty);
  });
}
