// Arabic counts 3-10 take a plural noun and 11-99 the singular accusative,
// so "Keep the last {count} backups" needs both forms (review of #3541).

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final ar = lookupAppLocalizations(const Locale('ar'));

  test('Arabic uses the plural noun for 5 and 10', () {
    expect(ar.settings_backups_keepLast(5), contains('نسخ احتياطية'));
    expect(ar.settings_backups_keepLast(10), contains('نسخ احتياطية'));
  });

  test('Arabic uses the singular noun for 15, 20 and 30', () {
    for (final n in [15, 20, 30]) {
      expect(ar.settings_backups_keepLast(n), contains('نسخة احتياطية'));
    }
  });

  test('English keeps one form', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.settings_backups_keepLast(20), 'Keep the last 20 backups');
  });
}
