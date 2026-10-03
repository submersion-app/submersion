import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/services/transfer_unit.dart';

void main() {
  TransferUnitGraph graph({
    Map<String, String?> owners = const {},
    Map<String, String> hosts = const {},
    List<({String parent, String component})> edges = const [],
  }) =>
      TransferUnitGraph(ownerOf: owners, hostOf: hosts, componentEdges: edges);

  test('a lone item is its own unit', () {
    final g = graph(owners: {'light': 'bill'});
    expect(transferUnits(g, ['light'], ownerId: 'bill'), [
      {'light'},
    ]);
  });

  test('a picked installed part expands to its host and siblings', () {
    final g = graph(
      owners: {'ccr': 'bill', 'cell1': 'bill', 'cell2': 'bill'},
      hosts: {'cell1': 'ccr', 'cell2': 'ccr'},
    );
    expect(transferUnits(g, ['cell1'], ownerId: 'bill'), [
      {'ccr', 'cell1', 'cell2'},
    ]);
  });

  test('assembly components move with the assembly', () {
    final g = graph(
      owners: {'reg': 'bill', 'first': 'bill', 'second': 'bill'},
      edges: [
        (parent: 'reg', component: 'first'),
        (parent: 'reg', component: 'second'),
      ],
    );
    expect(transferUnits(g, ['reg'], ownerId: 'bill'), [
      {'reg', 'first', 'second'},
    ]);
  });

  test('a component another profile owns is a boundary', () {
    final g = graph(
      owners: {'reg': 'bill', 'octo': 'anna'},
      edges: [(parent: 'reg', component: 'octo')],
    );
    expect(transferUnits(g, ['reg'], ownerId: 'bill'), [
      {'reg'},
    ]);
  });

  test('an assembly another profile owns is not pulled in by its part', () {
    final g = graph(
      owners: {'kit': 'anna', 'mask': 'bill'},
      edges: [(parent: 'kit', component: 'mask')],
    );
    expect(transferUnits(g, ['mask'], ownerId: 'bill'), [
      {'mask'},
    ]);
  });

  test('two assemblies sharing a part form one unit', () {
    final g = graph(
      owners: {'a': 'bill', 'b': 'bill', 'p': 'bill'},
      edges: [(parent: 'a', component: 'p'), (parent: 'b', component: 'p')],
    );
    expect(transferUnits(g, ['a'], ownerId: 'bill'), [
      {'a', 'b', 'p'},
    ]);
  });

  test('items not owned by the owner are in no unit', () {
    final g = graph(owners: {'mask': 'anna', 'fin': 'bill'});
    expect(transferUnits(g, ['mask', 'fin', 'ghost'], ownerId: 'bill'), [
      {'fin'},
    ]);
  });

  test('two picked items of one unit give one unit', () {
    final g = graph(
      owners: {'ccr': 'bill', 'cell': 'bill', 'light': 'bill'},
      hosts: {'cell': 'ccr'},
    );
    expect(transferUnits(g, ['cell', 'ccr', 'light'], ownerId: 'bill'), [
      {'ccr', 'cell'},
      {'light'},
    ]);
  });

  test('a cycle in the links terminates', () {
    final g = graph(
      owners: {'a': 'bill', 'b': 'bill'},
      hosts: {'a': 'b', 'b': 'a'},
      edges: [(parent: 'a', component: 'b')],
    );
    expect(transferUnits(g, ['a'], ownerId: 'bill'), [
      {'a', 'b'},
    ]);
  });
}
