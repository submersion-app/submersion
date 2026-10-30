// Issue #3482: the Settings > Data row statuses count devices, libraries and
// accounts. Arabic needs a distinct form for one, two, few and many; French
// has one and other. These pin the categories so a later edit cannot fold
// them back into a single form.

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final digits = RegExp(r'\p{Nd}+', unicode: true);

  test('Arabic gives one, two, few, many and other their own form', () {
    final ar = lookupAppLocalizations(const Locale('ar'));
    final renders = <String, String Function(int)>{
      'settings_data_sync_status_many': (n) =>
          ar.settings_data_sync_status_many(n, 'x'),
      'settings_data_libraries_status_some': (n) =>
          ar.settings_data_libraries_status_some(n, 'x'),
      'settings_data_libraries_status_someNever':
          ar.settings_data_libraries_status_someNever,
      'settings_data_accounts_status_needSignIn':
          ar.settings_data_accounts_status_needSignIn,
    };
    renders.forEach((key, render) {
      // one (1), two (2), few (3), many (11); other (100) shares many's
      // noun form without the accusative ending in some strings, so it is
      // checked against one and two only.
      final shapes = [
        for (final n in [1, 2, 3, 11]) render(n).replaceAll(digits, '#'),
      ];
      expect(shapes.toSet(), hasLength(4), reason: '$key: $shapes');
      final other = render(100).replaceAll(digits, '#');
      expect(other, isNot(shapes[0]), reason: '$key other vs one');
      expect(other, isNot(shapes[1]), reason: '$key other vs two');
    });
  });

  test('French uses a singular and a plural form', () {
    final fr = lookupAppLocalizations(const Locale('fr'));
    expect(
      fr.settings_data_libraries_status_someNever(1),
      isNot(
        fr.settings_data_libraries_status_someNever(2).replaceAll('2', '1'),
      ),
    );
    expect(
      fr.settings_data_accounts_status_needSignIn(1),
      isNot(
        fr.settings_data_accounts_status_needSignIn(2).replaceAll('2', '1'),
      ),
    );
  });
}
