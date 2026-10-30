import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The set up card's screen-reader count reads grammatically for one step
/// where the language would inflect the noun for the number done: the noun
/// goes in a label, so nothing has to agree (issue #3482 review).
void main() {
  String count(String locale, int done) => lookupAppLocalizations(
    Locale(locale),
  ).settings_setUpDevice_countSemantics(done, 4);

  test('French', () {
    expect(count('fr', 1), 'Étapes terminées : 1 sur 4');
  });

  test('Italian', () {
    expect(count('it', 1), 'Passaggi completati: 1 su 4');
  });

  test('Hebrew', () {
    expect(count('he', 1), 'שלבים שהושלמו: 1 מתוך 4');
  });
}
