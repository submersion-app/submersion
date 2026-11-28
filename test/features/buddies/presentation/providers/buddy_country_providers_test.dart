import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_country_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The buddy Country field's suggestions (issue #4457): countries already
/// used on buddies and sites first, then the other countries in the diver's
/// place-name language (issue #5019), worked out once per change rather
/// than on every rebuild of the form.
void main() {
  ProviderContainer containerWith({
    required List<String> buddyCountries,
    required String siteCountry,
    required String language,
  }) {
    final container = ProviderContainer(
      overrides: [
        usedBuddyCountriesProvider.overrideWith((ref) async => buddyCountries),
        sitesProvider.overrideWith(
          (ref) async => [
            DiveSite(id: 's1', name: 'Reef', country: siteCountry),
          ],
        ),
        placeNameLanguageProvider.overrideWithValue(language),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('used buddy and site countries come first, then the ISO list', () async {
    final container = containerWith(
      buddyCountries: ['Malta'],
      siteCountry: 'Bonaire',
      language: 'en',
    );

    final suggestions = await container.read(
      buddyCountrySuggestionsProvider.future,
    );
    expect(suggestions.take(2), ['Bonaire', 'Malta']);
    expect(suggestions, contains('Italy'));
  });

  test('the rest follow the place-name language, without a used country '
      'twice (issue #5019)', () async {
    final container = containerWith(
      buddyCountries: ['Deutschland'],
      siteCountry: 'Frankreich',
      language: 'de',
    );

    final suggestions = await container.read(
      buddyCountrySuggestionsProvider.future,
    );
    expect(suggestions.take(2), ['Deutschland', 'Frankreich']);
    expect(suggestions, containsAll(['Niederlande', 'Italien']));
    for (final twin in ['France', 'Germany', 'Netherlands', 'Italy']) {
      expect(suggestions, isNot(contains(twin)));
    }
  });
}
