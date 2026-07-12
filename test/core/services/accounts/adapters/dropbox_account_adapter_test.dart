import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
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

  final account = domain.ConnectedAccount(
    id: 'acc-db',
    kind: AccountKind.dropbox,
    label: 'Dropbox',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  setUp(() {
    keychain = InMemoryKeychain();
    adapter = DropboxAccountAdapter(
      authStoreFactory: (key) =>
          DropboxAuthStore(storage: keychain, storageKey: key),
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

  test('mediaObjectStore returns null without credentials', () async {
    expect(await adapter.mediaObjectStore(account), isNull);
  });
}
