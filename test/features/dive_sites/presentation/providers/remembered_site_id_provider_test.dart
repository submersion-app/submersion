import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

/// The site a list returned to reopens: its last-opened one, while the
/// list still shows it (#3301).
void main() {
  AsyncValue<String?> remembered(String? highlighted) {
    final container = ProviderContainer(
      overrides: [
        sortedSitesWithCountsProvider.overrideWithValue(
          const AsyncData([
            SiteWithDiveCount(
              site: DiveSite(id: 'r1', name: 'Reef'),
              diveCount: 0,
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(highlightedSiteIdProvider.notifier).state = highlighted;
    return container.read(rememberedSiteIdProvider);
  }

  test('a listed site is remembered', () {
    expect(remembered('r1'), const AsyncData<String?>('r1'));
  });

  test('a site the list does not show is not', () {
    expect(remembered('gone'), const AsyncData<String?>(null));
  });
}
