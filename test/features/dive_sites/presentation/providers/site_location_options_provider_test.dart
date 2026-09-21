import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

void main() {
  Future<ProviderContainer> containerFor(List<DiveSite> sites) async {
    final container = ProviderContainer(
      overrides: [sitesProvider.overrideWith((ref) async => sites)],
    );
    // Resolves sitesProvider once, so the derived providers below can be read
    // synchronously as AsyncData instead of racing AsyncLoading.
    await container.read(sitesProvider.future);
    return container;
  }

  group('siteCountryOptionsProvider (issue #1373)', () {
    test('lists distinct, deduplicated countries across all sites', () async {
      final container = await containerFor([
        const DiveSite(id: '1', name: 'A', country: 'Egypt'),
        const DiveSite(id: '2', name: 'B', country: 'egypt'),
        const DiveSite(id: '3', name: 'C', country: 'Thailand'),
        const DiveSite(id: '4', name: 'D'),
      ]);
      addTearDown(container.dispose);

      final options = container.read(siteCountryOptionsProvider).value;
      expect(options, ['Egypt', 'Thailand']);
    });

    test('is empty when no site has a country', () async {
      final container = await containerFor([
        const DiveSite(id: '1', name: 'A'),
      ]);
      addTearDown(container.dispose);

      final result = container.read(siteCountryOptionsProvider);
      expect(result.value, isEmpty);
    });
  });

  group('siteRegionOptionsProvider (issue #1373 cascading region list)', () {
    final sites = [
      const DiveSite(id: '1', name: 'A', country: 'Egypt', region: 'Red Sea'),
      const DiveSite(id: '2', name: 'B', country: 'egypt', region: 'Sinai'),
      const DiveSite(id: '3', name: 'C', country: 'Thailand', region: 'Phuket'),
      const DiveSite(id: '4', name: 'D', region: 'Unassigned Region'),
    ];

    test('with no country selected, lists regions across all sites', () async {
      final container = await containerFor(sites);
      addTearDown(container.dispose);

      final result = container.read(siteRegionOptionsProvider(null));
      expect(result.value, ['Phuket', 'Red Sea', 'Sinai', 'Unassigned Region']);
    });

    test('narrows to the regions of the selected country', () async {
      final container = await containerFor(sites);
      addTearDown(container.dispose);

      final result = container.read(siteRegionOptionsProvider('Egypt'));
      expect(result.value, ['Red Sea', 'Sinai']);
    });

    test('matches the country case-/whitespace-insensitively', () async {
      final container = await containerFor(sites);
      addTearDown(container.dispose);

      final result = container.read(siteRegionOptionsProvider(' egypt '));
      expect(result.value, ['Red Sea', 'Sinai']);
    });

    test('is empty for a country no site has', () async {
      final container = await containerFor(sites);
      addTearDown(container.dispose);

      final result = container.read(siteRegionOptionsProvider('Fiji'));
      expect(result.value, isEmpty);
    });
  });
}
