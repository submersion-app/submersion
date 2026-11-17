import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_country_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

/// The buddy Country field's suggestions (issue #4457): countries already
/// used on buddies and sites first, then the ISO list, worked out once per
/// change rather than on every rebuild of the form.
void main() {
  test('used buddy and site countries come first, then the ISO list', () async {
    final container = ProviderContainer(
      overrides: [
        usedBuddyCountriesProvider.overrideWith((ref) async => ['Malta']),
        sitesProvider.overrideWith(
          (ref) async => [
            const DiveSite(id: 's1', name: 'Reef', country: 'Bonaire'),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    final suggestions = await container.read(
      buddyCountrySuggestionsProvider.future,
    );
    expect(suggestions.take(2), ['Bonaire', 'Malta']);
    expect(suggestions, contains('Italy'));
  });
}
