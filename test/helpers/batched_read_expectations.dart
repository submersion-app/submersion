import 'package:flutter_test/flutter_test.dart';

import 'export_logbook_fixture.dart';

/// Registers the tests every batched "for many ids" read owes its per-id
/// sibling (issue #1867), against a [setUpStatementLoggingDatabase]
/// database that [seed] fills and that returns the ids worth asking about.
///
/// [batched] must return a map holding exactly the ids that have
/// something, each with what [single] returns for it.
void batchedReadTests<V>({
  required Future<List<String>> Function() seed,
  required Future<Map<String, V>> Function(List<String> ids) batched,
  required Future<V> Function(String id) single,
  required bool Function(V value) holdsNothing,
}) {
  late List<String> ids;

  setUp(() async {
    await setUpStatementLoggingDatabase();
    ids = await silently(seed);
  });

  test(
    'matches the per-id read for every id, leaving out empty ones',
    () async {
      final result = await silently(() => batched([...ids, 'no-such-id']));

      var nonEmpty = 0;
      for (final id in ids) {
        final expected = await silently(() => single(id));
        if (holdsNothing(expected)) {
          expect(result.containsKey(id), isFalse, reason: id);
        } else {
          nonEmpty++;
          expect(result[id], expected, reason: id);
        }
      }
      expect(nonEmpty, greaterThan(1), reason: 'the fixture proves nothing');
      expect(result.containsKey('no-such-id'), isFalse);
    },
  );

  test('costs one statement however many ids it is given', () async {
    final (_, statements) = await captureStatements(() => batched(ids));
    expect(statements, hasLength(1), reason: statements.join('\n'));
  });

  test('splits a long id list into bounded statements', () async {
    // 1,000 ids with the seeded ones at both ends, so the second chunk of
    // 900 has to be read and merged for the last of them to come back.
    final padding = [for (var i = 0; i < 1000 - ids.length; i++) 'pad-$i'];
    final long = [ids.first, ...padding, ...ids.skip(1)];

    final (result, statements) = await captureStatements(() => batched(long));

    expect(statements, hasLength(2), reason: statements.join('\n'));
    for (final id in ids) {
      final expected = await silently(() => single(id));
      if (!holdsNothing(expected)) expect(result[id], expected, reason: id);
    }
  });

  test('an empty id list reads nothing', () async {
    final (result, statements) = await captureStatements(
      () => batched(const []),
    );
    expect(result, isEmpty);
    expect(statements, isEmpty);
  });
}
