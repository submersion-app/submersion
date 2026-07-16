import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/divelogs_account_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/divelogs/divelogs_credentials.dart';

import '../../../../support/fake_keychain_storage.dart';

void main() {
  late InMemoryKeychain keychain;
  late AccountCredentialsStore store;
  late DivelogsAccountAdapter adapter;

  ConnectedAccount account(String id) => ConnectedAccount(
    id: id,
    kind: AccountKind.divelogs,
    label: 'divelogs.de',
    accountIdentifier: 'eric',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  setUp(() {
    keychain = InMemoryKeychain();
    store = AccountCredentialsStore(storage: keychain);
    adapter = DivelogsAccountAdapter(credentials: store);
  });

  test('kind is divelogs and adapter is LogbookSyncCapable', () {
    expect(adapter.kind, AccountKind.divelogs);
    expect(adapter, isA<LogbookSyncCapable>());
  });

  test('status is needsSignIn without credentials, signedIn with', () async {
    expect(await adapter.status(account('a1')), AccountStatus.needsSignIn);
    await store.write(
      'a1',
      const DivelogsCredentials(username: 'e', password: 'p').toJsonString(),
    );
    expect(await adapter.status(account('a1')), AccountStatus.signedIn);
  });

  test('disconnect deletes only this account credentials', () async {
    await store.write(
      'a1',
      const DivelogsCredentials(username: 'e', password: 'p').toJsonString(),
    );
    await store.write(
      'a2',
      const DivelogsCredentials(username: 'f', password: 'q').toJsonString(),
    );
    await adapter.disconnect(account('a1'));
    expect(await store.read('a1'), isNull);
    expect(await store.read('a2'), isNotNull);
  });

  test('authManagerFor caches one manager per account id', () {
    final m1 = adapter.authManagerFor(account('a1'));
    expect(identical(m1, adapter.authManagerFor(account('a1'))), isTrue);
    expect(identical(m1, adapter.authManagerFor(account('a2'))), isFalse);
  });
}
