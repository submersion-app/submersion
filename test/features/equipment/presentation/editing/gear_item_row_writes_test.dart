import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/equipment/presentation/editing/gear_item_row_writes.dart';

/// A row of a held list: its id and one value.
typedef Row = ({String id, String value});

/// The one write rule a gear item's held lists share (issue #4527, phase 3,
/// plan 6): only the difference between the rows read and the rows held.
void main() {
  Future<(bool, List<String>)> write(
    List<Row> loaded,
    List<Row> current, {
    bool canCreate = true,
  }) async {
    final calls = <String>[];
    final wrote = await writeRowChanges<Row>(
      loaded: loaded,
      current: current,
      idOf: (r) => r.id,
      create: canCreate ? (r) async => calls.add('create ${r.id}') : null,
      update: (r) async => calls.add('update ${r.id}'),
      delete: (id) async => calls.add('delete $id'),
    );
    return (wrote, calls);
  }

  test('a row new to the list is created, a changed one updated, a missing '
      'one deleted, an untouched one left', () async {
    final (wrote, calls) = await write(
      [(id: 'a', value: '1'), (id: 'b', value: '1'), (id: 'c', value: '1')],
      [(id: 'a', value: '1'), (id: 'b', value: '2'), (id: 'd', value: '1')],
    );

    expect(wrote, isTrue);
    expect(calls, ['update b', 'create d', 'delete c']);
  });

  test('nothing to write says so', () async {
    final (wrote, calls) = await write(
      [(id: 'a', value: '1')],
      [(id: 'a', value: '1')],
    );

    expect(wrote, isFalse);
    expect(calls, isEmpty);
  });

  test(
    'a list that never gains rows of its own updates one it finds',
    () async {
      final (_, calls) = await write(const [], [
        (id: 'a', value: '1'),
      ], canCreate: false);

      expect(calls, ['update a']);
    },
  );
}
