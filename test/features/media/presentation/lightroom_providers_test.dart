import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/lightroom/adobe_ims_auth_manager.dart';
import 'package:submersion/core/services/lightroom/lightroom_api_client.dart';
import 'package:submersion/core/services/lightroom/lightroom_auth_store.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/presentation/providers/lightroom_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_resolver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/test_database.dart';
import '../../../support/fake_keychain_storage.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LightroomAuthStore(storage: InMemoryKeychain());
    await store.save(
      const LightroomAuthData(clientId: 'cid', refreshToken: 'rt'),
    );
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        lightroomApiClientProvider.overrideWithValue(
          LightroomApiClient(
            auth: AdobeImsAuthManager(
              store: store,
              httpClient: MockClient(
                (_) async => http.Response('unavailable', 500),
              ),
            ),
            httpClient: MockClient(
              (_) async => http.Response('unavailable', 500),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  MediaItem connectorItem() => MediaItem(
    id: 'm1',
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.serviceConnector,
    remoteAssetId: 'lr1',
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('registry resolves serviceConnector without UnsupportedError', () {
    final MediaSourceResolverRegistry registry = container.read(
      mediaSourceResolverRegistryProvider,
    );
    final resolver = registry.resolverFor(MediaSourceType.serviceConnector);
    expect(resolver.sourceType, MediaSourceType.serviceConnector);
  });

  test('resolver declines connector items while no account exists', () async {
    // Let lightroomAccountProvider settle (null: no account row).
    await container.read(lightroomAccountProvider.future);
    final resolver = container.read(connectorMediaResolverProvider);
    expect(resolver.canResolveOnThisDevice(connectorItem()), isFalse);
  });

  test('account creation flips the resolver after invalidation', () async {
    await container.read(lightroomAccountProvider.future);
    await container
        .read(connectedAccountsRepositoryProvider)
        .create(
          kind: AccountKind.adobeLightroom,
          label: 'Eric',
          accountIdentifier: 'cat1',
        );
    container.invalidate(lightroomAccountProvider);
    await container.read(lightroomAccountProvider.future);

    final resolver = container.read(connectorMediaResolverProvider);
    expect(resolver.canResolveOnThisDevice(connectorItem()), isTrue);
  });

  test('auto-poll is a no-op without an account', () async {
    await container.read(lightroomAutoPollProvider.future);
    // Nothing to assert beyond not throwing: no account means no state
    // writes and no API construction.
  });

  test('with an account, resolve exercises the api/catalog/cache getters '
      'and degrades to networkError when the network is unavailable', () async {
    await container
        .read(connectedAccountsRepositoryProvider)
        .create(
          kind: AccountKind.adobeLightroom,
          label: 'Eric',
          accountIdentifier: 'cat1',
        );
    container.invalidate(lightroomAccountProvider);
    await container.read(lightroomAccountProvider.future);

    final resolver = container.read(connectorMediaResolverProvider);
    expect(resolver.canResolveOnThisDevice(connectorItem()), isTrue);

    // Widget-test HTTP always fails (400) and the auth store is empty, so
    // the rendition fetch cannot succeed -- what matters is that the
    // provider-supplied getters run and the failure maps to a graceful
    // UnavailableData, never a throw.
    final data = await resolver.resolve(connectorItem());
    expect(data, isA<UnavailableData>());
  });
}
