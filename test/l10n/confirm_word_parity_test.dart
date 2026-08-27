import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Type-to-confirm dialogs compare the user's input against a `confirmWord`
/// ARB key and tell them what to type via a `confirmHint` key. If a locale
/// translates the hint but not the word (or vice versa), the user types
/// exactly what they were told and the button never enables -- the dialog
/// becomes impossible to confirm in that language.
///
/// That shipped: seven locales instructed users to type a translated word
/// while the code compared against a hardcoded English 'Delete', making
/// Database Reset unusable in those languages. This guards every such pair.
void main() {
  final dir = Directory('lib/l10n/arb');

  /// The confirmation words are quoted in the hint. Locales use straight
  /// quotes; Chinese uses corner brackets.
  final quoted = RegExp(r'["“「]([^"”」]+)["”」]');

  const pairs = {
    'settings_storage_resetDialog_confirmWord':
        'settings_storage_resetDialog_confirmHint',
    'settings_cloudSync_replaceLibrary_confirmWord':
        'settings_cloudSync_replaceLibrary_confirmHint',
  };

  final arbs =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.arb'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  test('every locale quotes its own confirm word in the matching hint', () {
    final failures = <String>[];
    for (final file in arbs) {
      final arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in pairs.entries) {
        final word = arb[entry.key] as String?;
        final hint = arb[entry.value] as String?;
        if (word == null || hint == null) {
          failures.add(
            '${file.uri.pathSegments.last}: missing ${entry.key} '
            'or ${entry.value}',
          );
          continue;
        }
        final match = quoted.firstMatch(hint);
        if (match == null) {
          failures.add(
            '${file.uri.pathSegments.last}: ${entry.value} does not quote a '
            'word, so the user is not told what to type: "$hint"',
          );
          continue;
        }
        if (match.group(1) != word) {
          failures.add(
            '${file.uri.pathSegments.last}: ${entry.value} tells the user to '
            'type "${match.group(1)}" but ${entry.key} is "$word" -- the '
            'dialog cannot be confirmed in this locale',
          );
        }
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}
