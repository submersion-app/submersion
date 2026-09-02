import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  test('lookup strings exist in English', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(l10n.marineLife_lookup_button, 'Look up online');
    expect(l10n.marineLife_lookup_search, 'Look up');
    expect(l10n.marineLife_lookup_empty('zzz'), 'No species found for "zzz"');
    expect(l10n.marineLife_lookup_observations(1), '1 observation');
    expect(l10n.marineLife_lookup_observations(42), '42 observations');
    expect(
      l10n.marineLife_speciesDetail_suggestForCatalog,
      'Suggest for the catalog',
    );
    expect(l10n.reef_species_addFromLookup, 'Look up and add to your species');
  });

  test('lookup strings are translated in German', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('de'));

    expect(l10n.marineLife_lookup_button, 'Online nachschlagen');
    expect(l10n.marineLife_lookup_observations(2), '2 Beobachtungen');
  });
}
