import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `package:coverage` throws on a `coverage:ignore-start` opened before the
/// previous one ends, and `flutter test --coverage` then hangs until CI's
/// six-hour limit instead of failing (every test shard on 2026-11-03, from
/// nested blocks in `app_bootstrap_io.dart`). An unbalanced pair anywhere
/// under lib/ fails here in seconds instead.
final _start = RegExp(r'//\s*coverage:ignore-start\b');
final _end = RegExp(r'//\s*coverage:ignore-end\b');

/// The problems with one file's ignore blocks, as `line: what` strings.
List<String> coverageMarkerProblems(String source) {
  final problems = <String>[];
  int? openedAt;
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = i + 1;
    if (_start.hasMatch(lines[i])) {
      if (openedAt != null) {
        problems.add(
          '$line: ignore-start inside the block opened at $openedAt',
        );
      } else {
        openedAt = line;
      }
    } else if (_end.hasMatch(lines[i])) {
      if (openedAt == null) {
        problems.add('$line: ignore-end with no block open');
      } else {
        openedAt = null;
      }
    }
  }
  if (openedAt != null) {
    problems.add('$openedAt: ignore-start never ended');
  }
  return problems;
}

void main() {
  group('coverageMarkerProblems', () {
    test('accepts separate blocks and ignore-line markers', () {
      const source = '''
// coverage:ignore-start
a();
// coverage:ignore-end
b(); // coverage:ignore-line
  // coverage:ignore-start
c();
  // coverage:ignore-end
''';
      expect(coverageMarkerProblems(source), isEmpty);
    });

    test('flags a block opened inside another', () {
      const source = '''
// coverage:ignore-start
  // coverage:ignore-start
a();
  // coverage:ignore-end
// coverage:ignore-end
''';
      expect(coverageMarkerProblems(source), [
        '2: ignore-start inside the block opened at 1',
        '5: ignore-end with no block open',
      ]);
    });

    test('flags an end with no start and a start never ended', () {
      expect(coverageMarkerProblems('// coverage:ignore-end\n'), [
        '1: ignore-end with no block open',
      ]);
      expect(coverageMarkerProblems('// coverage:ignore-start\na();\n'), [
        '1: ignore-start never ended',
      ]);
    });
  });

  test('every coverage ignore block under lib/ is balanced', () {
    final offenders = <String>[];
    final files =
        Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .map((f) => f.path.replaceAll(r'\', '/'))
            .toList()
          ..sort();
    for (final path in files) {
      for (final problem in coverageMarkerProblems(
        File(path).readAsStringSync(),
      )) {
        offenders.add('$path:$problem');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'flutter test --coverage hangs on these; close each block before '
          'opening the next:\n${offenders.join('\n')}',
    );
  });
}
