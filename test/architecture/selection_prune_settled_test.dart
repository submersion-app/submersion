import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// An async list prunes its selection through `pruneToSettled` and nowhere
/// else (#2581).
///
/// A bare `pruneTo` on an async list either prunes to the empty frame of a
/// first load, dropping every check, or needs a hand-written `hasSettled`
/// guard whose ids must come from the same getter it checked. That rule was
/// copied into 18 call sites and drifted in three of them. The helper owns
/// it now; this keeps new lists on it.
void main() {
  const controller = 'lib/shared/selection/selection_controller.dart';

  /// Files permitted to call `pruneTo`, with the reason.
  const allowed = <String, String>{
    'lib/features/media/presentation/pages/media_library_view.dart':
        'its rows are a paged list, not an AsyncValue',
  };

  final bareCall = RegExp(r'\.pruneTo\(');
  final anyPrune = RegExp(r'\.pruneTo(Settled)?\(');

  Iterable<(String, List<String>)> libFiles() sync* {
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path == controller) continue;
      yield (path, entity.readAsLinesSync());
    }
  }

  bool isComment(String line) => line.trimLeft().startsWith('//');

  test('only allowlisted files call pruneTo', () {
    final offenders = <String>[];
    for (final (path, lines) in libFiles()) {
      if (allowed.containsKey(path)) continue;
      for (var i = 0; i < lines.length; i++) {
        if (isComment(lines[i])) continue;
        if (bareCall.hasMatch(lines[i])) offenders.add('$path:${i + 1}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'prune an async list with _selection.pruneToSettled(rowsAsync, '
          '(rows) => ...ids), so a first load keeps the checks and the ids '
          'come from the value the settled check read',
    );
  });

  test('no hand-written hasSettled guard sits beside a prune', () {
    final offenders = <String>[];
    for (final (path, lines) in libFiles()) {
      for (var i = 0; i < lines.length; i++) {
        if (isComment(lines[i]) || !anyPrune.hasMatch(lines[i])) continue;
        final from = i < 3 ? 0 : i - 3;
        for (var j = from; j <= i; j++) {
          if (!isComment(lines[j]) && lines[j].contains('hasSettled')) {
            offenders.add('$path:${j + 1}');
          }
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'pruneToSettled checks hasSettled itself; drop the caller guard',
    );
  });

  test('every allowlisted file exists and still calls pruneTo', () {
    // A stale exemption is how a guard quietly stops guarding.
    for (final entry in allowed.entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: '${entry.key} is missing');
      expect(
        bareCall.hasMatch(file.readAsStringSync()),
        isTrue,
        reason:
            '${entry.key} is allowlisted as "${entry.value}" but no longer '
            'calls pruneTo; remove it from the allowlist',
      );
    }
  });
}
