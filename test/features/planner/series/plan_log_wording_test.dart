import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The planned dives messages read properly for one dive and several, in every
/// language (issue #3565).
void main() {
  for (final locale in AppLocalizations.supportedLocales) {
    test('$locale builds each count', () {
      final l10n = lookupAppLocalizations(locale);
      for (final count in const [1, 2, 5]) {
        expect(l10n.plannerSeries_created(count), isNotEmpty);
        expect(l10n.plannerSeries_updated(count), isNotEmpty);
        expect(l10n.plannerSeries_orphans_body(count), isNotEmpty);
      }
    });
  }

  test('English matches the count', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(l10n.plannerSeries_created(1), '1 planned dive added to the log');
    expect(l10n.plannerSeries_created(3), '3 planned dives added to the log');
    expect(l10n.plannerSeries_updated(1), '1 planned dive updated in the log');
    expect(l10n.plannerSeries_updated(3), '3 planned dives updated in the log');
    expect(
      l10n.plannerSeries_orphans_body(1),
      '1 planned dive no longer in this series is still in the log.',
    );
  });
}
