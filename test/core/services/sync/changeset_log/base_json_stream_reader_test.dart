import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/changeset_log/base_json_stream_reader.dart';

/// Feed [s] as a single chunk.
Stream<List<int>> _one(String s) => Stream.value(utf8.encode(s));

/// Feed [s] one byte per chunk, to prove the scanner survives arbitrary
/// chunk boundaries.
Stream<List<int>> _drip(String s) async* {
  for (final b in utf8.encode(s)) {
    yield [b];
  }
}

Future<({Map<String, String> scalars, List<List<String>> rows})> run(
  Stream<List<int>> bytes, {
  bool Function(String section, String table)? want,
}) async {
  final scalars = <String, String>{};
  final rows = <List<String>>[];
  await BaseJsonStreamReader().parse(
    bytes,
    onScalar: (k, v) async => scalars[k] = utf8.decode(v),
    wantRows: want,
    onRow: (section, table, row) async =>
        rows.add([section, table, utf8.decode(row)]),
  );
  return (scalars: scalars, rows: rows);
}

void main() {
  const doc =
      '{"version":2,"exportedAt":17,"deviceId":"abc",'
      '"data":{"dives":[{"id":"d1","n":1},{"id":"d2","n":2}],'
      '"diveProfiles":[{"id":"p1"}]},'
      '"deletions":{"dives":[{"id":"x","deletedAt":5}]},'
      '"uploadNonce":null}';

  test('emits top-level scalars with raw JSON value bytes', () async {
    final r = await run(_one(doc));
    expect(r.scalars['version'], '2');
    expect(r.scalars['exportedAt'], '17');
    expect(r.scalars['deviceId'], '"abc"');
    expect(r.scalars['uploadNonce'], 'null');
    // Sections are not scalars.
    expect(r.scalars.containsKey('data'), isFalse);
    expect(r.scalars.containsKey('deletions'), isFalse);
  });

  test('emits each data and deletions row with section+table tags', () async {
    final r = await run(_one(doc));
    expect(r.rows, [
      ['data', 'dives', '{"id":"d1","n":1}'],
      ['data', 'dives', '{"id":"d2","n":2}'],
      ['data', 'diveProfiles', '{"id":"p1"}'],
      ['deletions', 'dives', '{"id":"x","deletedAt":5}'],
    ]);
  });

  test('survives one-byte-per-chunk boundaries', () async {
    final r = await run(_drip(doc));
    expect(r.scalars['deviceId'], '"abc"');
    expect(r.rows.length, 4);
    expect(r.rows.first, ['data', 'dives', '{"id":"d1","n":1}']);
  });

  test('wantRows=false skips a table without emitting it', () async {
    final r = await run(
      _one(doc),
      want: (section, table) => !(section == 'data' && table == 'diveProfiles'),
    );
    expect(r.rows.where((e) => e[1] == 'diveProfiles'), isEmpty);
    expect(r.rows.length, 3);
  });

  test('handles structural chars and escapes inside string values', () async {
    const tricky =
        '{"data":{"t":[{"s":"a,b{c}[d]\\"e\\\\f","ok":true}]},"deletions":{}}';
    final r = await run(_one(tricky));
    expect(r.rows.length, 1);
    final decoded = jsonDecode(r.rows.single[2]) as Map<String, dynamic>;
    expect(decoded['s'], 'a,b{c}[d]"e\\f');
    expect(decoded['ok'], true);
  });

  test('handles nested objects and arrays within a row', () async {
    const nested =
        '{"data":{"t":[{"id":"a","meta":{"k":[1,2,{"z":"}"}]}}]},'
        '"deletions":{}}';
    final r = await run(_one(nested));
    expect(r.rows.length, 1);
    final decoded = jsonDecode(r.rows.single[2]) as Map<String, dynamic>;
    expect((decoded['meta'] as Map)['k'], [
      1,
      2,
      {'z': '}'},
    ]);
  });

  test('handles empty data and empty tables', () async {
    final r = await run(_one('{"data":{},"deletions":{}}'));
    expect(r.rows, isEmpty);
  });

  test('tolerates unknown top-level keys and trailing members', () async {
    const doc2 = '{"future":{"a":1},"data":{"t":[{"id":"a"}]},"x":7}';
    final r = await run(_one(doc2));
    expect(r.scalars['x'], '7');
    expect(r.rows, [
      ['data', 't', '{"id":"a"}'],
    ]);
  });

  test('captures a row larger than a typical buffer', () async {
    final big = 'y' * 100000;
    final doc3 = '{"data":{"t":[{"id":"a","blob":"$big"}]},"deletions":{}}';
    final r = await run(_drip(doc3));
    expect(r.rows.length, 1);
    final decoded = jsonDecode(r.rows.single[2]) as Map<String, dynamic>;
    expect((decoded['blob'] as String).length, 100000);
  });

  // A scalar value that is itself an array (top-level), to confirm the scanner
  // does not mistake a non-object top value for a section. Not produced by our
  // writer, but the scanner should not crash or mis-tag it.
  test('treats a top-level array value as a scalar capture', () async {
    final r = await run(_one('{"tags":[1,2],"data":{"t":[{"id":"a"}]}}'));
    expect(jsonDecode(r.scalars['tags']!), [1, 2]);
    expect(r.rows, [
      ['data', 't', '{"id":"a"}'],
    ]);
  });

  test('throws FormatException on a truncated document', () async {
    // Stream ends mid-row, before the top-level object closes.
    await expectLater(
      run(_one('{"data":{"t":[{"id":"a"')),
      throwsFormatException,
    );
  });

  test('throws FormatException on empty input', () async {
    await expectLater(run(_one('')), throwsFormatException);
  });

  test('throws FormatException when the top object is never closed', () async {
    // Well-formed rows but the final closing brace is missing.
    await expectLater(
      run(_one('{"data":{"t":[{"id":"a"}]},"deletions":{}')),
      throwsFormatException,
    );
  });
}
