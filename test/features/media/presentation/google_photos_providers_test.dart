import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_registry.dart';
import 'package:submersion/core/services/accounts/adapters/google_photos_account_adapter.dart';
import 'package:submersion/core/services/google_photos/google_photos_auth_store.dart';
import 'package:submersion/core/services/google_photos/google_photos_redirect_capture.dart';
import 'package:submersion/features/media/presentation/providers/google_photos_providers.dart';

import '../../../helpers/test_database.dart';
import '../../../support/fake_keychain_storage.dart';

void main() {
  late ProviderContainer container;
  late InMemoryKeychain keychain;

  setUp(() async {
    await setUpTestDatabase();
    keychain = InMemoryKeychain();
    final adapter = GooglePhotosAccountAdapter(
      authStoreFactory: (key) =>
          GooglePhotosAuthStore(storage: keychain, storageKey: key),
    );
    container = ProviderContainer(
      overrides: [
        accountProviderRegistryProvider.overrideWithValue(
          AccountProviderRegistry([adapter]),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  tearDown(tearDownTestDatabase);

  test('redirect capture defaults to the flutter_web_auth capturer', () {
    expect(
      container.read(googlePhotosRedirectCaptureProvider),
      isA<FlutterWebAuthGooglePhotosRedirectCapture>(),
    );
  });

  test('device status is notConnected with no roster row', () async {
    expect(
      await container.read(googlePhotosDeviceStatusProvider.future),
      GooglePhotosDeviceStatus.notConnected,
    );
  });

  test('a roster row without local credentials reads as needsSignIn', () async {
    await container
        .read(connectedAccountsRepositoryProvider)
        .create(kind: AccountKind.googlePhotos, label: 'diver@example.com');
    container.invalidate(googlePhotosAccountProvider);

    expect(
      await container.read(googlePhotosDeviceStatusProvider.future),
      GooglePhotosDeviceStatus.needsSignIn,
    );
  });

  test('a roster row with a stored grant reads as connected', () async {
    final account = await container
        .read(connectedAccountsRepositoryProvider)
        .create(kind: AccountKind.googlePhotos, label: 'diver@example.com');
    await keychain.write(
      key: AccountCredentialsStore.keyFor(account.id),
      value: '{"refreshToken":"rt"}',
    );
    container.invalidate(googlePhotosAccountProvider);
    container.invalidate(googlePhotosDeviceStatusProvider);

    expect(
      await container.read(googlePhotosDeviceStatusProvider.future),
      GooglePhotosDeviceStatus.connected,
    );
  });

  test('the checked adapter provider resolves the registered adapter', () {
    expect(
      container.read(googlePhotosAccountAdapterProvider),
      isA<GooglePhotosAccountAdapter>(),
    );
  });
}
