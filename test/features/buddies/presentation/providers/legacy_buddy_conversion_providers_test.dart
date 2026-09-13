import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/presentation/providers/legacy_buddy_conversion_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../helpers/fake_legacy_buddy_conversion_service.dart';

void main() {
  test('the bulk page re-plans on every visit instead of caching', () async {
    // A cached result would keep an empty state after the diver imports
    // dives with buddy text and comes back to the page.
    final service = FakeLegacyBuddyConversionService();
    final container = ProviderContainer(
      overrides: [
        legacyBuddyConversionServiceProvider.overrideWithValue(service),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'me'),
      ],
    );
    addTearDown(container.dispose);

    final visit = container.listen(
      linkBuddyNamesDataProvider.future,
      (_, _) {},
    );
    await container.read(linkBuddyNamesDataProvider.future);
    visit.close();
    await pumpEventQueue();

    final again = container.listen(
      linkBuddyNamesDataProvider.future,
      (_, _) {},
    );
    addTearDown(again.close);
    await container.read(linkBuddyNamesDataProvider.future);

    expect(service.planCandidatesCalls, 2);
  });
}
