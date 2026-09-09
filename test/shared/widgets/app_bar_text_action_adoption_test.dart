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
      for (final offset in [
        ..._bareAppBarTextButtons(source),
        ..._bareTextButtonsInHoistedActions(source),
      ]) {
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

  // A raw string has no escape processing, so the backslash in `r'\'` does
  // NOT protect the quote that follows it. Treating it as an escape swallows
  // the terminator, and every string literal after it in the file is read
  // with inverted parity: real code gets blanked, and an offender inside it
  // becomes invisible to the scan. `lib/features/universal_import/domain/
  // services/import_media_resolver.dart` writes exactly this literal.
  test('a raw string holding a backslash does not blind the scan', () {
    const source = r'''
class Foo {
  String normalize(String path) => path.replaceAll(r'\', '/');

  PreferredSizeWidget build(BuildContext context) {
    return AppBar(
      actions: [
        TextButton(onPressed: () {}, child: const Text('Save')),
      ],
    );
  }
}
''';

    expect(
      _bareAppBarTextButtons(_withoutCommentsAndStrings(source)),
      hasLength(1),
      reason:
          'the bare TextButton sits after a raw string with a trailing '
          'backslash, which must not be read as an escape',
    );
  });

  // A `${...}` interpolation can hold string literals of the SAME quote as the
  // string enclosing it, and they do not end it. Terminating at the first
  // matching quote hands the inner literal's CONTENT to the scan as code; when
  // that content is a bracket, the span matcher closes the app bar early and
  // the actions list falls outside it, so a real offender goes unreported.
  // 103 files under lib/ interpolate an expression holding a bracketed
  // literal, `readableTextSql('tank_id')` and friends among them.
  test(
    'interpolation holding a same-quote literal does not blind the scan',
    () {
      const source = r'''
class Foo {
  PreferredSizeWidget build(BuildContext context) {
    return AppBar(
      title: Text('${name.replaceAll(')', '')} trip'),
      actions: [
        TextButton(onPressed: () {}, child: const Text('Save')),
      ],
    );
  }
}
''';

      expect(
        _bareAppBarTextButtons(_withoutCommentsAndStrings(source)),
        hasLength(1),
        reason:
            'quotes inside an interpolation must not close the string that '
            'contains them, or its bracket leaks into the scanned code',
      );
    },
  );

  // The other half of the same branch: a NON-raw literal does process
  // escapes, so an escaped quote must not be mistaken for the terminator.
  test('an escaped quote inside a normal string does not blind the scan', () {
    const source = '''
class Foo {
  String get label => 'it\\'s here';

  PreferredSizeWidget build(BuildContext context) {
    return AppBar(
      actions: [
        TextButton(onPressed: () {}, child: const Text('Save')),
      ],
    );
  }
}
''';

    expect(
      _bareAppBarTextButtons(_withoutCommentsAndStrings(source)),
      hasLength(1),
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
  // `const` and a generic type argument are both common in this tree, and
  // either one silently ended the match before this was widened.
  final actions = RegExp(r'\bactions:\s*(?:const\s*)?(?:<[^>]*>\s*)?\[');
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

/// Offsets of every `TextButton(` / `TextButton.icon(` inside a list literal
/// assigned to a local named `actions`, in a file that builds an app bar.
///
/// [_bareAppBarTextButtons] only sees actions written inline, so a page that
/// hoists its list into a local to share it between an app bar and an embedded
/// pane slips straight past it. The deco calculator did exactly that, and its
/// invisible "Add to planner" button survived the first sweep of this bug
/// because of it.
///
/// The `AppBar` requirement is what keeps this from flagging an unrelated
/// local that happens to be called `actions`, such as a dialog's button list.
List<int> _bareTextButtonsInHoistedActions(String source) {
  if (!RegExp(r'\b(?:Sliver)?AppBar\s*\(').hasMatch(source)) return const [];

  final found = <int>[];
  final hoisted = RegExp(r'\bactions\s*=\s*(?:const\s*)?(?:<[^>]*>\s*)?\[');
  final textButtons = RegExp(r'\bTextButton\s*(?:\.\s*icon\s*)?\(');

  for (final match in hoisted.allMatches(source)) {
    final open = match.end - 1;
    final close = _matchingBracket(source, open);
    final list = source.substring(open, close);
    for (final button in textButtons.allMatches(list)) {
      found.add(open + button.start);
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
    if (source.startsWith('//', i)) {
      while (i < source.length && source[i] != '\n') {
        out.write(' ');
        i++;
      }
      continue;
    }
    if (source.startsWith('/*', i)) {
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
    if (_literalBeginsAt(source, i)) {
      i = _blankLiteral(source, i, out);
      continue;
    }
    out.write(source[i]);
    i++;
  }
  return out.toString();
}

/// Whether a string literal begins at [i], counting an `r` prefix as part of
/// it.
///
/// The character before an `r` is checked so that the tail of a name such as
/// `ctr` cannot be read as a raw prefix.
bool _literalBeginsAt(String source, int i) {
  final char = source[i];
  if (char == "'" || char == '"') return true;
  return char == 'r' &&
      i + 1 < source.length &&
      (source[i + 1] == "'" || source[i + 1] == '"') &&
      (i == 0 || !_isIdentifierPart(source[i - 1]));
}

/// Blanks the string literal starting at [start] into [out], returning the
/// index just past it. Newlines are preserved so reported line numbers stay
/// true to the file.
///
/// Two Dart rules make this more than a scan to the next quote:
///
/// - A raw literal has no escape processing, so the backslash in `r'\'` does
///   not protect the quote after it.
/// - A `${...}` interpolation may contain literals quoted the SAME way as the
///   string enclosing it, and they do not end it. Those nest arbitrarily, so
///   the interpolation is walked with this function recursing on each literal
///   it holds.
///
/// Getting either wrong does not merely mis-blank one string: it inverts the
/// parity of the literals that follow, or leaks their content into the scanned
/// code, where a stray bracket moves where the enclosing widget appears to
/// end.
int _blankLiteral(String source, int start, StringBuffer out) {
  var i = start;
  final raw = source[i] == 'r';
  if (raw) {
    out.write(' ');
    i++;
  }

  final quote = source[i];
  final triple = source.startsWith(quote * 3, i);
  final terminator = triple ? quote * 3 : quote;
  out.write(' ' * terminator.length);
  i += terminator.length;

  while (i < source.length && !source.startsWith(terminator, i)) {
    if (!raw && source[i] == r'\' && i + 1 < source.length) {
      out.write('  ');
      i += 2;
      continue;
    }
    if (!raw && source.startsWith(r'${', i)) {
      out.write('  ');
      i += 2;
      var depth = 1;
      while (i < source.length && depth > 0) {
        if (_literalBeginsAt(source, i)) {
          i = _blankLiteral(source, i, out);
          continue;
        }
        final char = source[i];
        if (char == '{') depth++;
        if (char == '}') depth--;
        out.write(char == '\n' ? '\n' : ' ');
        i++;
      }
      continue;
    }
    out.write(source[i] == '\n' ? '\n' : ' ');
    i++;
  }

  // An unterminated literal runs to end of file; there is nothing left to
  // blank in that case.
  if (i < source.length) {
    out.write(' ' * terminator.length);
    i += terminator.length;
  }
  return i;
}

/// Whether [char] can appear inside a Dart identifier.
bool _isIdentifierPart(String char) => RegExp(r'[A-Za-z0-9_$]').hasMatch(char);
