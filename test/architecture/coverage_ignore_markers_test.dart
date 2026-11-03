// pre-push: scans lib/
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _start = RegExp(r'//\s*coverage:ignore-start\s*$');
final _end = RegExp(r'//\s*coverage:ignore-end\s*$');

/// What is wrong with the `coverage:ignore-start` / `coverage:ignore-end`
/// pairs in [source], one line each, or nothing when every block opens once
/// and closes once.
List<String> markerProblems(String source) {
  final problems = <String>[];
  int? openedAt;
  final lines = source.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = i + 1;
    if (_start.hasMatch(lines[i])) {
      if (openedAt != null) {
        problems.add('line $line starts a block inside the one from $openedAt');
      }
      openedAt ??= line;
    } else if (_end.hasMatch(lines[i])) {
      if (openedAt == null) {
        problems.add('line $line ends a block that never started');
      }
      openedAt = null;
    }
  }
  if (openedAt != null) problems.add('the block from $openedAt never ends');
  return problems;
}

/// The coverage package throws on a `coverage:ignore-start` inside another
/// one, and `flutter test --coverage` then never exits: every test shard sat
/// until the six-hour job limit (#4182). Nesting looks harmless in review,
/// since an inner pair inside an outer one reads as belt and braces.
void main() {
  group('markerProblems', () {
    test('accepts pairs one after another', () {
      const source =
          'a\n// coverage:ignore-start\nb\n// coverage:ignore-end\n'
          '// coverage:ignore-start\nc\n// coverage:ignore-end\n';
      expect(markerProblems(source), isEmpty);
    });

    test('flags a block started inside another', () {
      const source =
          '// coverage:ignore-start\na\n  // coverage:ignore-start\n'
          '  // coverage:ignore-end\n// coverage:ignore-end\n';
      expect(markerProblems(source), [
        'line 3 starts a block inside the one from 1',
        'line 5 ends a block that never started',
      ]);
    });

    test('flags a block that never ends', () {
      expect(markerProblems('// coverage:ignore-start\na\n'), [
        'the block from 1 never ends',
      ]);
    });

    test('ignores the markers mentioned in prose', () {
      const source = '/// Wrap it in coverage:ignore-start and -end.\n';
      expect(markerProblems(source), isEmpty);
    });
  });

  test('every coverage ignore block in lib/ opens once and closes once', () {
    final found = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      for (final problem in markerProblems(entity.readAsStringSync())) {
        found.add('$path: $problem');
      }
    }
    expect(found, isEmpty, reason: found.join('\n'));
  });
}
