import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  test('Species page strings exist in English', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(l10n.marineLife_speciesPage_title, 'Species');
    expect(l10n.marineLife_speciesPage_speciesCount(1), '1 species');
    expect(l10n.marineLife_speciesPage_sightingsCount(7), '7 sightings');
    expect(l10n.marineLife_speciesPage_divesCount(1), '1 dive');
    expect(
      l10n.marineLife_speciesPage_lastSeen('Jan 15, 2024'),
      'Last seen Jan 15, 2024',
    );
    expect(l10n.marineLife_speciesDetail_showAll(12), 'Show all (12)');
    expect(l10n.marineLife_speciesDetail_countTimes(3), '× 3');
    expect(l10n.statistics_marineLife_seeAllSpecies_title, 'See all species');
  });

  test('Species page strings are translated, not English, in German', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('de'));

    expect(l10n.marineLife_speciesPage_title, 'Arten');
    expect(l10n.marineLife_speciesPage_divesCount(2), '2 Tauchgänge');
    expect(
      l10n.statistics_marineLife_seeAllSpecies_title,
      isNot('See all species'),
    );
  });
}
