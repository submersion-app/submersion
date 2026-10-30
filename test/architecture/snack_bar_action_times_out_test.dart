import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'snack_bar_persist_scanner.dart';

/// Guards the rule that a snack bar with an action says whether it persists
/// (issues #406 and #3834).
///
/// `SnackBar` defaults `persist` to true as soon as it has an `action`, and a
/// persisting snack bar ignores its `duration`. It then stays on screen until
/// someone clicks it, follows the user onto later pages because it belongs to
/// the app-wide messenger rather than the page that raised it, and holds up
/// every message queued behind it. Issue #3834 is the result: an "Attached 1
/// item" message left over from one attach sat on top of the next attach's
/// commit button.
///
/// The theme cannot change this default, since `SnackBarThemeData` has no
/// `persist`, so each snack bar has to state it.
void main() {
  final dartFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
      .toList();

  final result = scanForActionWithoutPersist(
    files: dartFiles,
    relativize: p.relative,
  );

  test('the scan found the snack bars, so it cannot pass vacuously', () {
    expect(dartFiles.length, greaterThan(1000));
    expect(result.snackBarsWithAction, greaterThanOrEqualTo(40));
  });

  test('every SnackBar with an action states whether it persists', () {
    expect(
      result.violations,
      isEmpty,
      reason:
          'SnackBars with an action and no persist argument. Each one below '
          'never times out, whatever its duration says.\n\n'
          'Add `persist: false`, and `duration: const Duration(seconds: 5)` '
          'if the action is an Undo. A message that truly must wait for the '
          'user says `persist: true`, which is rarely right: it covers '
          'whatever sits at the bottom of every page until it is clicked, '
          'and blocks the queue behind it.\n\n'
          '${result.violations.join('\n')}',
    );
  });
}
