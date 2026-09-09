import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// A bare [TextButton] takes its foreground from `colorScheme.primary`, which
/// the Tropical theme sets to the very color of its app bar background and
/// Console sets to a near neighbour of it. An app bar action written that way
/// paints its label onto an identical ground and disappears: #736 reported it
/// on the diver profile pages, #1231 reported the same invisible Save on the
/// checklist editors after only those six pages were migrated.
///
/// Guard the whole tree rather than the pages that regressed, because the next
/// one will be somewhere new. [AppBarTextAction] pins the label to the app
/// bar's own foreground color and is the only sanctioned way to put a text
/// action in an app bar.
void main() {
  final wrapper = p.join(
    'lib',
    'shared',
    'widgets',
    'app_bar_text_action.dart',
  );

  test('every app bar text action goes through AppBarTextAction', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (p.equals(entity.path, wrapper)) continue;

      final source = _withoutCommentsAndStrings(entity.readAsStringSync());
      for (final offset in _bareAppBarTextButtons(source)) {
        final line = '\n'.allMatches(source.substring(0, offset)).length + 1;
        offenders.add('${entity.path}:$line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Use AppBarTextAction from lib/shared/widgets/app_bar_text_action.dart '
          'for AppBar.actions text buttons, so the label stays visible on the '
          'themes whose primary color matches their app bar background.',
    );
  });
}

/// Offsets of every `TextButton(` / `TextButton.icon(` that sits inside the
/// `actions:` list of an `AppBar(` or `SliverAppBar(`.
///
/// Both enclosures are matched by balancing brackets rather than by line
/// proximity: a `TextButton` in a dialog's `actions:` is legitimate (a dialog
/// surface renders `primary` legibly) and lives only a few lines away from an
/// app bar in the same build method.
List<int> _bareAppBarTextButtons(String source) {
  final found = <int>[];
  final appBars = RegExp(r'\b(?:Sliver)?AppBar\s*\(');
  final actions = RegExp(r'\bactions:\s*(?:\.\.\.)?\[');
  final textButtons = RegExp(r'\bTextButton\s*(?:\.\s*icon\s*)?\(');

  for (final appBar in appBars.allMatches(source)) {
    final open = appBar.end - 1;
    final close = _matchingBracket(source, open);
    final arguments = source.substring(open, close);

    for (final action in actions.allMatches(arguments)) {
      final listOpen = action.end - 1;
      final listClose = _matchingBracket(arguments, listOpen);
      final list = arguments.substring(listOpen, listClose);
      for (final button in textButtons.allMatches(list)) {
        found.add(open + listOpen + button.start);
      }
    }
  }
  return found;
}

/// Index of the bracket closing the one at [open], counting `(` and `[`
/// together so an argument list and a widget list nest correctly.
int _matchingBracket(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final char = source[i];
    if (char == '(' || char == '[') {
      depth++;
    } else if (char == ')' || char == ']') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return source.length;
}

/// Blanks out comments and string literals, preserving every offset so the
/// reported line numbers still point at the real source.
///
/// Without this a doc comment naming `TextButton` inside an app bar's build
/// method, or a string holding a bracket, would either invent an offender or
/// throw the bracket balance off.
String _withoutCommentsAndStrings(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    final rest = source.length - i;
    if (rest >= 2 && source.startsWith('//', i)) {
      while (i < source.length && source[i] != '\n') {
        out.write(' ');
        i++;
      }
      continue;
    }
    if (rest >= 2 && source.startsWith('/*', i)) {
      while (i < source.length && !source.startsWith('*/', i)) {
        out.write(source[i] == '\n' ? '\n' : ' ');
        i++;
      }
      // Blank the terminator too, when the comment is closed at all.
      for (var k = 0; k < 2 && i < source.length; k++, i++) {
        out.write(' ');
      }
      continue;
    }
    final quote = source[i];
    if (quote == "'" || quote == '"') {
      final triple = rest >= 3 && source.startsWith(quote * 3, i);
      final terminator = triple ? quote * 3 : quote;
      out.write(' ' * terminator.length);
      i += terminator.length;
      while (i < source.length && !source.startsWith(terminator, i)) {
        if (source[i] == r'\' && i + 1 < source.length) {
          out.write('  ');
          i += 2;
          continue;
        }
        out.write(source[i] == '\n' ? '\n' : ' ');
        i++;
      }
      out.write(' ' * (i < source.length ? terminator.length : 0));
      i += i < source.length ? terminator.length : 0;
      continue;
    }
    out.write(source[i]);
    i++;
  }
  return out.toString();
}
