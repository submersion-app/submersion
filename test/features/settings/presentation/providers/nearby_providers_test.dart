import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/settings/presentation/providers/nearby_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart'
    show sharedPreferencesProvider;
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

import '../../../../helpers/test_database.dart';
import '../../../../support/in_memory_nearby_carrier.dart';
import '../../../../support/memory_nearby_secrets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(tearDownTestDatabase);

  test('choosing another cloud backend does not rebuild the nearby link '
      '(it would drop a running session and its foreground state)', () async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        nearbyCarrierProvider.overrideWithValue(InMemoryNearbyHub().join('me')),
        nearbyPairSecretsProvider.overrideWithValue(MemoryNearbySecrets()),
      ],
    );
    addTearDown(container.dispose);
    final first = container.read(nearbyLinkManagerProvider);
    container.invalidate(syncServiceProvider);
    container.invalidate(cloudStorageProviderProvider);
    expect(identical(container.read(nearbyLinkManagerProvider), first), isTrue);
  });
}
