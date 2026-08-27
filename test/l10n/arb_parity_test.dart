import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the project rule that every ARB key is translated into all ten
/// non-English locales, not just added to the template.
void main() {
  final dir = Directory('lib/l10n/arb');

  Map<String, dynamic> load(File f) =>
      jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;

  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  final en = load(File('${dir.path}/app_en.arb'));
  final enKeys = messageKeys(en);

  final locales =
      dir
          .listSync()
          .whereType<File>()
          .where(
            (f) => f.path.endsWith('.arb') && !f.path.endsWith('app_en.arb'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('all ten non-English locales are present', () {
    expect(locales.length, 10);
  });

  test('every locale defines every English key', () {
    final failures = <String>[];
    for (final file in locales) {
      final missing = enKeys.difference(messageKeys(load(file)));
      if (missing.isNotEmpty) {
        final sample = (missing.toList()..sort()).take(5).join(', ');
        failures.add(
          '${file.uri.pathSegments.last}: ${missing.length} missing '
          '($sample${missing.length > 5 ? ', ...' : ''})',
        );
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('no locale defines a key English does not', () {
    final failures = <String>[];
    for (final file in locales) {
      final extra = messageKeys(load(file)).difference(enKeys);
      if (extra.isNotEmpty) {
        failures.add('${file.uri.pathSegments.last}: ${extra.length} extra');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('placeholders match English in every locale', () {
    /// Extract ICU argument names.
    ///
    /// Only depth-1 braces are arguments, and a complex argument is named by
    /// the text before its first comma: `{count, plural, =1{dive} other{dives}}`
    /// contributes `count`, not `dive` and `dives`. Those inner braces hold
    /// branch text, and their wording legitimately differs per locale --
    /// Arabic has six plural categories where English has two.
    Set<String> names(String s) {
      final found = <String>{};
      var depth = 0;
      var start = -1;
      for (var i = 0; i < s.length; i++) {
        final c = s[i];
        if (c == '{') {
          if (depth == 0) start = i + 1;
          depth++;
        } else if (c == '}') {
          depth--;
          if (depth == 0 && start >= 0) {
            final body = s.substring(start, i);
            final name = body.split(',').first.trim();
            if (name.isNotEmpty) found.add(name);
            start = -1;
          }
        }
      }
      return found;
    }

    final failures = <String>[];
    for (final file in locales) {
      final arb = load(file);
      for (final key in enKeys) {
        final translated = arb[key];
        if (translated is! String) continue;
        final expected = names(en[key] as String);
        final actual = names(translated);
        if (expected.difference(actual).isNotEmpty ||
            actual.difference(expected).isNotEmpty) {
          failures.add(
            '${file.uri.pathSegments.last} $key: '
            'expected $expected, got $actual',
          );
        }
      }
    }
    expect(failures, isEmpty, reason: failures.take(10).join('\n'));
  });
}
