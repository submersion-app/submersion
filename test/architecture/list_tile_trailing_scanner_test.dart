import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'list_tile_trailing_scanner.dart';

/// Unit tests for the scanner that backs
/// `test/architecture/list_tile_trailing_width_test.dart`.
///
/// Uses synthetic source in a temp directory rather than the real `lib/` tree,
/// so the accept/reject shapes stay pinned even as the codebase moves.
void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('trailing_scanner'));
  tearDown(() => temp.deleteSync(recursive: true));

  TrailingScanResult scan(String body) {
    final file = File(p.join(temp.path, 'tile.dart'))
      ..writeAsStringSync('''
Widget build() {
  return $body;
}
''');
    return scanForTextBearingTrailing(files: [file], relativize: p.basename);
  }

  group('flags', () {
    for (final widget in [
      "Chip(label: Text('a'))",
      "ActionChip(label: Text('a'), onPressed: f)",
      "FilterChip(label: Text('a'), onSelected: f)",
      "InputChip(label: Text('a'))",
      "ChoiceChip(label: Text('a'), selected: true)",
      "TextButton(onPressed: f, child: Text('a'))",
      "TextButton.icon(onPressed: f, icon: i, label: Text('a'))",
      "OutlinedButton(onPressed: f, child: Text('a'))",
      "FilledButton(onPressed: f, child: Text('a'))",
      "FilledButton.tonal(onPressed: f, child: Text('a'))",
      "ElevatedButton(onPressed: f, child: Text('a'))",
    ]) {
      test(widget, () {
        final result = scan('ListTile(title: t, trailing: $widget)');

        expect(result.violations, hasLength(1));
        expect(result.violations.single.widgets, [widget.split('(').first]);
      });
    }

    test('a const chip', () {
      final result = scan("ListTile(trailing: const Chip(label: Text('a')))");

      expect(result.violations.single.widgets, ['Chip']);
    });

    test('an ExpansionTile trailing button', () {
      final result = scan(
        "ExpansionTile(title: t, trailing: TextButton(onPressed: f, child: "
        "Text('a')))",
      );

      expect(result.violations.single.tile, 'ExpansionTile');
    });

    test('a chip beside an icon button in a Row, as #2692 had it', () {
      final result = scan('''
ListTile(
  trailing: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Chip(label: Text('a')),
      IconButton(icon: i, onPressed: f),
    ],
  ),
)''');

      expect(result.violations.single.widgets, ['Chip']);
    });

    test('through Padding, Align, a conditional and a collection if', () {
      final result = scan('''
ListTile(
  trailing: Padding(
    padding: e,
    child: Align(
      child: busy
          ? null
          : Wrap(children: [if (x) TextButton(onPressed: f, child: c)]),
    ),
  ),
)''');

      expect(result.violations.single.widgets, ['TextButton']);
    });

    test('a SizedBox that only sets a height does not fix the width', () {
      final result = scan(
        'ListTile(trailing: SizedBox(height: 40, child: '
        'FilledButton(onPressed: f, child: c)))',
      );

      expect(result.violations.single.widgets, ['FilledButton']);
    });

    test('reports the line of the trailing argument', () {
      final result = scan('''
ListTile(
  title: t,
  trailing: Chip(label: c),
)''');

      // Line 1 is `Widget build() {`, line 2 opens `return ListTile(`.
      expect(result.violations.single.line, 4);
      expect(result.violations.single.file, 'tile.dart');
    });
  });

  group('accepts', () {
    for (final widget in [
      'IconButton(icon: i, onPressed: f)',
      'PopupMenuButton<String>(itemBuilder: b)',
      'Icon(Icons.chevron_right)',
      'Switch(value: true, onChanged: f)',
      'Checkbox(value: true, onChanged: f)',
      // A trailing Text is usually a short value ('12', '40 m'), which a
      // syntactic scan cannot size, so it is out of scope.
      "Text('12')",
      // A custom widget may or may not be text-bearing; it is not resolvable
      // without type analysis.
      'MyStatusBadge(status: s)',
    ]) {
      test(widget, () {
        expect(scan('ListTile(trailing: $widget)').violations, isEmpty);
      });
    }

    test('a button given a fixed width by a SizedBox', () {
      final result = scan(
        'ListTile(trailing: SizedBox(width: 96, child: '
        'TextButton(onPressed: f, child: c)))',
      );

      expect(result.violations, isEmpty);
    });

    test('a chip in the subtitle, as #935 and #2692 place it', () {
      final result = scan('''
ListTile(
  title: t,
  subtitle: Column(children: [Text('s'), Chip(label: c)]),
  trailing: IconButton(icon: i, onPressed: f),
)''');

      expect(result.violations, isEmpty);
    });

    test('a button in trailing of a widget that is not a tile', () {
      final result = scan(
        'MyRow(trailing: TextButton(onPressed: f, child: c))',
      );

      expect(result.violations, isEmpty);
    });
  });

  test('counts every tile with a trailing argument, flagged or not', () {
    final result = scan('''
Column(children: [
  ListTile(trailing: Icon(i)),
  ListTile(title: t),
  ExpansionTile(trailing: Chip(label: c)),
])''');

    expect(result.tilesWithTrailing, 2);
    expect(result.violations, hasLength(1));
  });
}
