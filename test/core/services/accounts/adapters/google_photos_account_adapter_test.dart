import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/google_photos_account_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/google_photos/google_photos_auth_store.dart';

import '../../../../support/fake_keychain_storage.dart';

void main() {
  final account = domain.ConnectedAccount(
    id: 'acc-gp',
    kind: AccountKind.googlePhotos,
    label: 'Google Photos',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  GooglePhotosAccountAdapter adapterOver(InMemoryKeychain keychain) =>
      GooglePhotosAccountAdapter(
        authStoreFactory: (key) =>
            GooglePhotosAuthStore(storage: keychain, storageKey: key),
      );

  test('is a media-source connector, not a sync/store backend', () {
    final adapter = adapterOver(InMemoryKeychain());
    expect(adapter.kind, AccountKind.googlePhotos);
    expect(adapter, isA<MediaSourceCapable>());
    expect(adapter, isNot(isA<SyncCapable>()));
    expect(adapter, isNot(isA<MediaStoreCapable>()));
  });

  test(
    'status is needsSignIn until a grant is stored, then signedIn',
    () async {
      final keychain = InMemoryKeychain();
      final adapter = adapterOver(keychain);
      expect(await adapter.status(account), AccountStatus.needsSignIn);

      await GooglePhotosAuthStore(
        storage: keychain,
        storageKey: 'account_${account.id}_credentials',
      ).save(const GooglePhotosAuthData(refreshToken: 'rt'));

      expect(await adapter.status(account), AccountStatus.signedIn);
    },
  );

  test('the auth manager is cached per account id', () {
    final adapter = adapterOver(InMemoryKeychain());
    expect(
      identical(
        adapter.authManagerFor(account),
        adapter.authManagerFor(account),
      ),
      isTrue,
    );
  });

  test('disconnect clears the stored grant and drops the cached '
      'manager', () async {
    final keychain = InMemoryKeychain();
    final adapter = adapterOver(keychain);
    final store = GooglePhotosAuthStore(
      storage: keychain,
      storageKey: 'account_${account.id}_credentials',
    );
    await store.save(const GooglePhotosAuthData(refreshToken: 'rt'));

    final before = adapter.authManagerFor(account);
    await adapter.disconnect(account);

    expect(await store.load(), isNull);
    expect(identical(adapter.authManagerFor(account), before), isFalse);
  });

  test('an injected http client factory reaches the per-account auth '
      'manager', () async {
    final keychain = InMemoryKeychain();
    await GooglePhotosAuthStore(
      storage: keychain,
      storageKey: 'account_${account.id}_credentials',
    ).save(const GooglePhotosAuthData(refreshToken: 'rt'));

    var revokeHit = false;
    final adapter = GooglePhotosAccountAdapter(
      authStoreFactory: (key) =>
          GooglePhotosAuthStore(storage: keychain, storageKey: key),
      httpClientFactory: () => MockClient((req) async {
        if (req.url.path == '/revoke') revokeHit = true;
        return http.Response('', 200);
      }),
    );

    await adapter.disconnect(account);
    expect(revokeHit, isTrue);
  });
}
