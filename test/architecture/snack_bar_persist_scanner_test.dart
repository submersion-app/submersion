import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'snack_bar_persist_scanner.dart';

/// Unit tests for the scanner that backs
/// `test/architecture/snack_bar_action_times_out_test.dart`.
///
/// Uses synthetic source in a temp directory rather than the real `lib/` tree,
/// so the accept/reject shapes stay pinned even as the codebase moves.
void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('persist_scanner'));
  tearDown(() => temp.deleteSync(recursive: true));

  PersistScanResult scan(String expression) {
    final file = File(p.join(temp.path, 'snack.dart'))
      ..writeAsStringSync('''
Widget build() {
  return $expression;
}
''');
    return scanForActionWithoutPersist(files: [file], relativize: p.basename);
  }

  test('flags an action with no persist, at the line of the SnackBar', () {
    final result = scan('''
SnackBar(
    content: Text('a'),
    action: SnackBarAction(label: 'b', onPressed: f),
  )''');

    expect(result.snackBarsWithAction, 1);
    expect(result.violations.map((v) => v.toString()), ['snack.dart:2']);
  });

  test('flags an action held in a variable', () {
    final result = scan("SnackBar(content: Text('a'), action: undo)");

    expect(result.violations, hasLength(1));
  });

  test('flags a SnackBar written with new', () {
    final result = scan("new SnackBar(content: Text('a'), action: undo)");

    expect(result.violations, hasLength(1));
  });

  test('flags a SnackBar nested in the action of another', () {
    final result = scan('''
SnackBar(
    content: Text('a'),
    persist: false,
    action: SnackBarAction(
      label: 'b',
      onPressed: () => show(SnackBar(content: Text('c'), action: redo)),
    ),
  )''');

    expect(result.snackBarsWithAction, 2);
    expect(result.violations, hasLength(1));
  });

  test('accepts an action that says it times out', () {
    final result = scan(
      "SnackBar(content: Text('a'), persist: false, action: undo)",
    );

    expect(result.snackBarsWithAction, 1);
    expect(result.violations, isEmpty);
  });

  test('accepts an action that says it stays on purpose', () {
    final result = scan(
      "SnackBar(content: Text('a'), persist: true, action: undo)",
    );

    expect(result.violations, isEmpty);
  });

  test('ignores a SnackBar with no action, which times out anyway', () {
    final result = scan("SnackBar(content: Text('a'))");

    expect(result.snackBarsWithAction, 0);
    expect(result.violations, isEmpty);
  });

  test('ignores other widgets that take an action', () {
    final result = scan("MaterialBanner(content: Text('a'), action: undo)");

    expect(result.snackBarsWithAction, 0);
  });
}
