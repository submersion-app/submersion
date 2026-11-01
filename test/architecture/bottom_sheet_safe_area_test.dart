import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'source_mask.dart';

/// Every scroll-controlled modal bottom sheet must say whether its route
/// keeps clear of the status bar.
///
/// `isScrollControlled: true` lifts the sheet's 9/16-height cap, so a sheet
/// whose content is taller than the screen grows to the very top edge. Unless
/// the route is given `useSafeArea: true`, it also strips the top padding
/// from the sheet's `MediaQuery`, so a `SafeArea` inside the sheet cannot see
/// the status bar either. That is how the gear sort sheet's header ended up
/// under a phone's clock and signal icons (issue #4081), and the same call
/// shape was repeated across the app.
///
/// A sheet that really should run under the status bar states
/// `useSafeArea: false`, which this guard accepts as a deliberate choice.
/// Comments and strings are ignored, so a doc comment quoting the call does
/// not count.
void main() {
  test('flags a scroll-controlled sheet that omits useSafeArea', () {
    const source = '''
void open(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const Text('x'),
  );
}
''';
    expect(scrollControlledSheetsWithoutSafeArea(source), [2]);
  });

  test('accepts a sheet that states useSafeArea either way', () {
    const source = '''
void open(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const Text('x'),
  );
  showModalBottomSheet(
    context: context,
    useSafeArea: false,
    isScrollControlled: true,
    builder: (context) => const Text('x'),
  );
}
''';
    expect(scrollControlledSheetsWithoutSafeArea(source), isEmpty);
  });

  test('ignores sheets that keep the height cap', () {
    const source = '''
void open(BuildContext context) {
  showModalBottomSheet(context: context, builder: (c) => const Text('x'));
  showModalBottomSheet(
    context: context,
    isScrollControlled: false,
    builder: (c) => const Text('x'),
  );
}
''';
    expect(scrollControlledSheetsWithoutSafeArea(source), isEmpty);
  });

  test('ignores a call quoted in a comment or a string', () {
    const source = '''
/// `showModalBottomSheet(isScrollControlled: true)` lifts the cap.
const quoted = 'showModalBottomSheet(isScrollControlled: true)';
''';
    expect(scrollControlledSheetsWithoutSafeArea(source), isEmpty);
  });

  test('a nested sheet does not answer for the one around it', () {
    // The inner call's useSafeArea sits inside the outer call's builder, so
    // it must not count as the outer call's own argument.
    const source = '''
void open(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => TextButton(
      onPressed: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => const Text('x'),
      ),
      child: const Text('y'),
    ),
  );
}
''';
    expect(scrollControlledSheetsWithoutSafeArea(source), [2]);
  });

  test('every scroll-controlled sheet in lib states useSafeArea', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      for (final line in scrollControlledSheetsWithoutSafeArea(
        entity.readAsStringSync(),
      )) {
        offenders.add('$path:$line');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Pass useSafeArea: true to these scroll-controlled bottom sheets so '
          'a tall sheet stops below the status bar (issue #4081), or '
          'useSafeArea: false if it must run under it:\n'
          '${offenders.join('\n')}',
    );
  });
}

final _sheetCall = RegExp(r'\bshowModalBottomSheet\s*(?:<[^>()]*>)?\s*\(');
final _scrollControlled = RegExp(r'\bisScrollControlled\s*:\s*(\w+)');
final _safeArea = RegExp(r'\buseSafeArea\s*:');

/// The 1-based lines of the `showModalBottomSheet` calls in [source] that
/// lift the height cap without stating `useSafeArea`.
List<int> scrollControlledSheetsWithoutSafeArea(String source) {
  final masked = MaskedSource(source);
  final code = masked.code;
  final lines = <int>[];
  for (final match in _sheetCall.allMatches(code)) {
    final arguments = _topLevelArguments(code, match.end);
    final scrollControlled = _scrollControlled.firstMatch(arguments);
    if (scrollControlled == null || scrollControlled.group(1) == 'false') {
      continue;
    }
    if (_safeArea.hasMatch(arguments)) continue;
    lines.add(masked.lineOf(match.start));
  }
  return lines;
}

/// The argument list that opens just before [from], with everything nested
/// inside it (a builder's body, a nested call) blanked, so only the call's
/// own arguments remain.
String _topLevelArguments(String code, int from) {
  final buffer = StringBuffer();
  var depth = 0;
  for (var i = from; i < code.length; i++) {
    final char = code[i];
    if (char == '(' || char == '[' || char == '{') {
      depth++;
    } else if (char == ')' || char == ']' || char == '}') {
      if (depth == 0) break;
      depth--;
      continue;
    }
    buffer.write(depth == 0 ? char : ' ');
  }
  return buffer.toString();
}
