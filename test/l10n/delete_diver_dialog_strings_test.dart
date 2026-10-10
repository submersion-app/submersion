// pre-push: scans lib/l10n/arb/
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The delete-diver dialog warns that a diver and all their dive logs are
/// about to be erased, then asks the user to type a phrase before Delete
/// enables. All three strings shipped in English in every translation
/// (issue #3069). The typed phrase is the locale's own Delete button label
/// followed by the diver's name, so the word the user types matches the
/// button they are about to press. `confirm_word_parity_test.dart` checks
/// that the hint quotes that phrase exactly.
void main() {
  const keys = [
    'divers_detail_deleteDialogContent',
    'divers_detail_deleteDialogConfirmHint',
    'divers_detail_deleteDialogConfirmText',
  ];

  final dir = Directory(p.join('lib', 'l10n', 'arb'));

  Map<String, dynamic> load(String locale) =>
      jsonDecode(File(p.join(dir.path, 'app_$locale.arb')).readAsStringSync())
          as Map<String, dynamic>;

  final en = load('en');
  final locales =
      dir
          .listSync()
          .whereType<File>()
          .map((f) => p.basename(f.path))
          .where((name) => name.startsWith('app_') && name.endsWith('.arb'))
          .map((name) => name.substring(4, name.length - 4))
          .where((locale) => locale != 'en')
          .toList()
        ..sort();

  test('finds the translated locales', () {
    expect(locales, isNotEmpty);
  });

  for (final locale in locales) {
    group(locale, () {
      final arb = load(locale);

      for (final key in keys) {
        test('$key is translated and keeps {name}', () {
          final value = arb[key] as String?;
          expect(value, isNotNull, reason: '$locale is missing $key');
          expect(
            value,
            isNot(en[key]),
            reason: '$locale still has the English $key',
          );
          expect(value, contains('{name}'));
        });
      }

      test('the typed phrase is the Delete button label plus the name', () {
        expect(
          arb['divers_detail_deleteDialogConfirmText'],
          '${arb['divers_detail_deleteButton']} {name}',
        );
      });
    });
  }
}
