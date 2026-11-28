import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'spacing_literal_scanner.dart';

/// Unit tests for the scanner that backs
/// `test/architecture/spacing_literals_test.dart` (issue #4971).
///
/// Uses synthetic source in a temp directory rather than the real `lib/` tree,
/// so the flagged and exempt shapes stay pinned as the codebase moves.
void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('spacing_scanner'));
  tearDown(() => temp.deleteSync(recursive: true));

  List<SpacingLiteral> scanSource(String source, {String name = 'w.dart'}) {
    final file = File(p.join(temp.path, name))..writeAsStringSync(source);
    return scanForSpacingLiterals(files: [file], relativize: p.basename);
  }

  List<SpacingLiteral> scan(String body) => scanSource('''
Widget build() {
  return $body;
}
''');

  List<num> values(List<SpacingLiteral> found) => [
    for (final literal in found) literal.value,
  ];

  group('flags', () {
    final cases = <String, (String, List<num>)>{
      'const EdgeInsets.all(16)': ('EdgeInsets.all', [16]),
      'EdgeInsets.all(16)': ('EdgeInsets.all', [16]),
      'EdgeInsets.symmetric(horizontal: 8, vertical: 4)': (
        'EdgeInsets.symmetric',
        [8, 4],
      ),
      'EdgeInsets.only(left: 10)': ('EdgeInsets.only', [10]),
      'EdgeInsets.fromLTRB(16, 0, 16, 6)': ('EdgeInsets.fromLTRB', [16, 16, 6]),
      'EdgeInsetsDirectional.fromSTEB(4, 0, 4, 0)': (
        'EdgeInsetsDirectional.fromSTEB',
        [4, 4],
      ),
      'const EdgeInsetsDirectional.only(start: 12)': (
        'EdgeInsetsDirectional.only',
        [12],
      ),
      'BorderRadius.circular(12)': ('BorderRadius.circular', [12]),
      'const Radius.circular(8)': ('Radius.circular', [8]),
      'Radius.elliptical(4, 6)': ('Radius.elliptical', [4, 6]),
      'SizedBox(width: 8)': ('SizedBox.width', [8]),
      'const SizedBox(height: 12)': ('SizedBox.height', [12]),
      'SizedBox(width: 8, child: null)': ('SizedBox.width', [8]),
      'const SizedBox(height: 12, child: (null))': ('SizedBox.height', [12]),
      'Wrap(spacing: 24, runSpacing: 12, children: c)': (
        'Wrap.spacing',
        [24, 12],
      ),
      'Row(spacing: 8, children: c)': ('Row.spacing', [8]),
      'GridView.count(crossAxisCount: 2, mainAxisSpacing: 4)': (
        'GridView.count.mainAxisSpacing',
        [4],
      ),
      'const Divider(indent: 16, endIndent: 16)': ('Divider.indent', [16, 16]),
      'EdgeInsets.all(compact ? 8 : 16)': ('EdgeInsets.all', [8, 16]),
      'EdgeInsets.all(gap ?? 4)': ('EdgeInsets.all', [4]),
      'EdgeInsets.all((12))': ('EdgeInsets.all', [12]),
      'EdgeInsets.all(16.0)': ('EdgeInsets.all', [16.0]),
      'EdgeInsets.only(top: -4)': ('EdgeInsets.only', [-4]),
      'w.EdgeInsets.all(8)': ('EdgeInsets.all', [8]),
      'const w.EdgeInsets.all(8)': ('EdgeInsets.all', [8]),
      'const w.SizedBox(width: 8)': ('SizedBox.width', [8]),
      'w.SizedBox(width: 8)': ('SizedBox.width', [8]),
    };
    cases.forEach((source, expected) {
      test(source, () {
        final found = scan(source);
        expect(values(found), expected.$2);
        expect(found.first.call, expected.$1);
      });
    });

    test('a switch expression arm', () {
      expect(values(scan('EdgeInsets.all(switch (x) { 1 => 8, _ => 16 })')), [
        8,
        16,
      ]);
    });

    test('BorderRadiusDirectional.circular', () {
      final found = scan('BorderRadiusDirectional.circular(8)');
      expect(values(found), [8]);
      expect(found.first.call, 'BorderRadiusDirectional.circular');
    });

    test('an instance field is widget state, not a named constant', () {
      final found = scanSource('''
class _State {
  final pad = EdgeInsets.all(10);
}
''');
      expect(values(found), [10]);
    });

    test('a closure inside a named constant is code, not its value', () {
      final found = scanSource('''
final kBuild = (c) => Padding(padding: EdgeInsets.all(8));
abstract final class Style {
  static final builder = (c) => const SizedBox(width: 12);
}
''');
      expect(values(found), [8, 12]);
    });

    test('a const local in a function body is not a named constant', () {
      final found = scanSource('''
Widget build() {
  const pad = EdgeInsets.all(10);
  return Padding(padding: pad);
}
''');
      expect(values(found), [10]);
    });
  });

  group('ignores', () {
    for (final source in [
      'EdgeInsets.zero',
      'EdgeInsets.all(0)',
      'EdgeInsets.all(0.0)',
      'EdgeInsets.all(Spacing.s8)',
      'EdgeInsets.all(Spacing.s8 * 2)',
      'EdgeInsets.only(left: depth * 12)',
      'SizedBox(width: 8, height: 8)',
      'SizedBox(width: 150, child: x)',
      'SizedBox.square(dimension: 24)',
      'SizedBox.fromSize(size: s)',
      'GridView.count(crossAxisCount: 2)',
      "Text('EdgeInsets.all(16)')",
    ]) {
      test(source, () => expect(scan(source), isEmpty));
    }

    test('a top-level named constant', () {
      expect(
        scanSource('const kPad = EdgeInsets.only(bottom: 88);\n'),
        isEmpty,
      );
    });

    test("an enum constant's off-scale arguments", () {
      expect(
        scanSource('''
enum Gap {
  tight(EdgeInsets.all(10)),
  loose(EdgeInsets.all(14));

  const Gap(this.padding);
  final EdgeInsets padding;
}
'''),
        isEmpty,
      );
    });

    test('a static final field named constant', () {
      expect(
        scanSource('''
abstract final class Style {
  static final padding = EdgeInsets.only(left: 10);
}
'''),
        isEmpty,
      );
    });

    test('a class field named constant', () {
      expect(
        scanSource('''
abstract final class Style {
  static const rowPadding = EdgeInsets.symmetric(horizontal: 14);
}
'''),
        isEmpty,
      );
    });

    test('a comment', () {
      expect(scanSource('// EdgeInsets.all(16)\nvoid f() {}\n'), isEmpty);
    });

    test('a generated file', () {
      expect(
        scanSource('Widget build() => EdgeInsets.all(16);\n', name: 'w.g.dart'),
        isEmpty,
      );
    });
  });

  // A named constant exempts a value that is off the scale. One that is on it
  // belongs on the scale, wherever it is written.
  group('flags an on-scale value inside a named constant', () {
    final cases = <String, (String, List<num>)>{
      'abstract final class S {\n'
          '  static const gap = EdgeInsets.all(12);\n'
          '}\n': (
        'EdgeInsets.all',
        [12],
      ),
      'const kPad = EdgeInsets.only(top: 14, bottom: 16);\n': (
        'EdgeInsets.only',
        [16],
      ),
      'enum Gap {\n'
          '  tight(EdgeInsets.all(4)),\n'
          '  loose(EdgeInsets.all(14));\n'
          '\n'
          '  const Gap(this.padding);\n'
          '  final EdgeInsets padding;\n'
          '}\n': (
        'EdgeInsets.all',
        [4],
      ),
      'abstract final class S {\n'
          '  static final radius = BorderRadius.circular(8);\n'
          '}\n': (
        'BorderRadius.circular',
        [8],
      ),
      'abstract final class S {\n'
          '  static const pill = BorderRadius.all(Radius.circular(999));\n'
          '}\n': (
        'Radius.circular',
        [999],
      ),
    };
    cases.forEach((source, expected) {
      test(source.split('\n')[source.startsWith('abstract') ? 1 : 0], () {
        final found = scanSource(source);
        expect(values(found), expected.$2);
        expect(found.map((l) => l.call).toSet(), {expected.$1});
      });
    });

    test('but not a radius-scale value used as spacing, or the reverse', () {
      // 32 is on the spacing scale only and 999 on the radius scale only.
      expect(
        scanSource('''
abstract final class S {
  static const radius = BorderRadius.all(Radius.circular(32));
  static const pad = EdgeInsets.only(left: 999);
}
'''),
        isEmpty,
      );
    });
  });

  test('reads the scales from lib/core/theme/spacing.dart', () {
    final scales = SpacingScales.app();
    expect(scales.spacing, {2, 4, 6, 8, 12, 16, 20, 24, 32, 40, 48});
    expect(scales.radii, {2, 4, 6, 8, 12, 16, 20, 24, 999});
  });

  test('reports the line and source span of each literal', () {
    const source =
        'Widget build() => EdgeInsets.fromLTRB(\n'
        '  16,\n'
        '  8,\n'
        '  16,\n'
        '  -4,\n'
        ');\n';
    final found = scanSource(source);
    expect([for (final l in found) l.line], [2, 3, 4, 5]);
    expect(
      [for (final l in found) source.substring(l.offset, l.offset + l.length)],
      ['16', '8', '16', '-4'],
    );
    expect(found.first.toString(), 'w.dart:2  EdgeInsets.fromLTRB  16');
  });
}
