import 'package:flutter_test/flutter_test.dart';

import 'dive_date_decode_scanner.dart';

/// Unit tests for the scanner behind `dive_date_decode_single_source_test.dart`,
/// on synthetic source so the accepted and rejected shapes stay pinned as
/// `lib/` moves.
void main() {
  group('flags a plain decode of', () {
    for (final call in [
      "DateTime.fromMillisecondsSinceEpoch(row.read<int>('dive_date_time'))",
      'DateTime.fromMillisecondsSinceEpoch(dive.diveDateTime)',
      'DateTime.fromMillisecondsSinceEpoch(entryTimeMs)',
      'DateTime.fromMillisecondsSinceEpoch(firstSeenMs)',
      "DateTime.fromMillisecondsSinceEpoch(row.data['last_dive'] as int)",
      "DateTime.fromMillisecondsSinceEpoch(r.read<int>('last_dived'))",
    ]) {
      test(call, () {
        expect(findLocalDiveDateDecodes('final t = $call;'), hasLength(1));
      });
    }

    test('a call spread over several lines, reported on its first', () {
      const source = '''
void f() {
  final t = DateTime.fromMillisecondsSinceEpoch(
    row.read<int>('dive_date_time'),
  );
}
''';
      expect(findLocalDiveDateDecodes(source), [
        "2: DateTime.fromMillisecondsSinceEpoch( row.read<int>('dive_date_time'), )",
      ]);
    });

    test('a decode that says isUtc: false', () {
      expect(
        findLocalDiveDateDecodes(
          'DateTime.fromMillisecondsSinceEpoch(diveDateTime, isUtc: false);',
        ),
        hasLength(1),
      );
    });
  });

  group('accepts', () {
    test('a decode flagged UTC', () {
      expect(
        findLocalDiveDateDecodes(
          'DateTime.fromMillisecondsSinceEpoch(diveDateTime, isUtc: true);',
        ),
        isEmpty,
      );
    });

    test('a plain decode of a value that is not a dive time', () {
      // Trip dates are local instants and must stay local.
      expect(
        findLocalDiveDateDecodes(
          "DateTime.fromMillisecondsSinceEpoch(r.read<int>('start_date'));\n"
          'DateTime.fromMillisecondsSinceEpoch(row.createdAt);',
        ),
        isEmpty,
      );
    });

    test('a call that only appears in a comment or a string', () {
      expect(
        findLocalDiveDateDecodes('''
// DateTime.fromMillisecondsSinceEpoch(diveDateTime) shifts the day.
const s = 'DateTime.fromMillisecondsSinceEpoch(diveDateTime)';
'''),
        isEmpty,
      );
    });

    test('a comment inside an unrelated call that names a dive time', () {
      expect(
        findLocalDiveDateDecodes('''
DateTime.fromMillisecondsSinceEpoch(
  // not the dive_date_time column
  row.createdAt,
);
'''),
        isEmpty,
      );
    });
  });
}
