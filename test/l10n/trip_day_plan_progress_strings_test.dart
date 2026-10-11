import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The trip day plan line, "1 of 3 planned dives", agrees with its planned
/// count in the locales whose noun changes form at one.
void main() {
  test('English reads singular for one planned dive', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.trips_day_planProgress(0, 1), '0 of 1 planned dive');
    expect(en.trips_day_planProgress(2, 3), '2 of 3 planned dives');
  });

  test('Hebrew reads singular for one planned dive', () {
    final he = lookupAppLocalizations(const Locale('he'));
    expect(he.trips_day_planProgress(1, 1), '1 מתוך צלילה אחת מתוכננת');
    expect(he.trips_day_planProgress(2, 3), '2 מתוך 3 צלילות מתוכננות');
  });
}
