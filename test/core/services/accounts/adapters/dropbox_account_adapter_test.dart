import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/dropbox_storage_provider.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/dropbox_account_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_store.dart';

import '../../../../support/fake_keychain_storage.dart';

void main() {
  late InMemoryKeychain keychain;
  late DropboxAccountAdapter adapter;
  late List<http.Request> requests;

  final account = domain.ConnectedAccount(
    id: 'acc-db',
    kind: AccountKind.dropbox,
    label: 'Dropbox',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  setUp(() {
    keychain = InMemoryKeychain();
    requests = [];
    // Dropbox itself: disconnect refreshes the access token, then revokes it.
    final dropbox = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/oauth2/token') {
        return http.Response(
          jsonEncode({'access_token': 'fresh-token', 'expires_in': 14400}),
          200,
        );
      }
      return http.Response('null', 200);
    });
    adapter = DropboxAccountAdapter(
      authStoreFactory: (key) =>
          DropboxAuthStore(storage: keychain, storageKey: key),
      httpClient: dropbox,
    );
  });

  test('kind is dropbox', () {
    expect(adapter.kind, AccountKind.dropbox);
  });

  test(
    'status reflects presence of the per-account refresh-token blob',
    () async {
      expect(await adapter.status(account), AccountStatus.needsSignIn);

      keychain.values[AccountCredentialsStore.keyFor(account.id)] = jsonEncode({
        'refreshToken': 'rt',
        'email': 'e@x.com',
        'displayName': 'E',
      });
      expect(await adapter.status(account), AccountStatus.signedIn);
    },
  );

  test('status ignores the legacy sync key', () async {
    keychain.values['sync_dropbox_auth'] = jsonEncode({'refreshToken': 'rt'});
    expect(await adapter.status(account), AccountStatus.needsSignIn);
  });

  test('disconnect clears only the per-account blob', () async {
    final key = AccountCredentialsStore.keyFor(account.id);
    keychain.values[key] = jsonEncode({'refreshToken': 'rt'});
    keychain.values['sync_dropbox_auth'] = 'legacy';
    await adapter.disconnect(account);
    expect(keychain.values.containsKey(key), isFalse);
    expect(keychain.values['sync_dropbox_auth'], 'legacy');
  });

  test('disconnect revokes the token with a freshly refreshed one', () async {
    keychain.values[AccountCredentialsStore.keyFor(account.id)] = jsonEncode({
      'refreshToken': 'rt',
    });
    await adapter.disconnect(account);

    expect(requests.map((r) => r.url.path), [
      '/oauth2/token',
      '/2/auth/token/revoke',
    ]);
    expect(requests.last.headers['Authorization'], 'Bearer fresh-token');
  });

  test('mediaObjectStore returns null without credentials', () async {
    expect(await adapter.mediaObjectStore(account), isNull);
  });

  test('syncProvider returns a DropboxStorageProvider (account-first raw '
      'provider for sync resolution)', () {
    expect(adapter.syncProvider(account), isA<DropboxStorageProvider>());
  });
}
