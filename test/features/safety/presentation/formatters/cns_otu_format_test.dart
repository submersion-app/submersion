import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/safety/presentation/formatters/cns_otu_format.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final fr = lookupAppLocalizations(const Locale('fr'));

  String since(Duration d, [AppLocalizations? l10n]) =>
      formatTimeSinceLastDive(d, l10n ?? en);

  test('under a minute reads "<1min", not "0min"', () {
    expect(since(const Duration(seconds: 20)), '<1min');
  });

  test('under an hour reads in minutes', () {
    expect(since(const Duration(minutes: 25)), '25min');
  });

  test('under a day reads in hours and minutes', () {
    expect(since(const Duration(hours: 5, minutes: 12)), '5h 12m');
  });

  test('a day or more reads in days and hours', () {
    expect(since(const Duration(days: 3, hours: 4, minutes: 50)), '3d 4h');
    expect(since(const Duration(hours: 24)), '1d 0h');
  });

  test('the day unit follows the locale', () {
    expect(since(const Duration(days: 2, hours: 1), fr), '2j 1h');
  });
}
