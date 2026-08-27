import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';

import '../../../support/fake_keychain_storage.dart';

void main() {
  late InMemoryKeychain keychain;
  late AccountCredentialsStore store;

  setUp(() {
    keychain = InMemoryKeychain();
    store = AccountCredentialsStore(storage: keychain);
  });

  test('keyFor embeds the account id', () {
    expect(
      AccountCredentialsStore.keyFor('acc-1'),
      'account_acc-1_credentials',
    );
  });

  test('write/read/delete round-trip under the per-account key', () async {
    await store.write('acc-1', '{"a":1}');
    expect(await store.read('acc-1'), '{"a":1}');
    expect(keychain.values['account_acc-1_credentials'], '{"a":1}');
    await store.delete('acc-1');
    expect(await store.read('acc-1'), isNull);
  });

  test('rekeyFromLegacy copies the blob and keeps the legacy entry', () async {
    keychain.values['sync_dropbox_auth'] = '{"t":"x"}';
    await store.rekeyFromLegacy(
      legacyKey: 'sync_dropbox_auth',
      accountId: 'acc-2',
    );
    expect(await store.read('acc-2'), '{"t":"x"}');
    expect(keychain.values['sync_dropbox_auth'], '{"t":"x"}');
  });

  test('rekeyFromLegacy is a no-op when legacy key is absent', () async {
    await store.rekeyFromLegacy(legacyKey: 'missing', accountId: 'acc-3');
    expect(await store.read('acc-3'), isNull);
  });

  test(
    'rekeyFromLegacy never overwrites an existing per-account blob',
    () async {
      await store.write('acc-4', '{"new":true}');
      keychain.values['legacy'] = '{"old":true}';
      await store.rekeyFromLegacy(legacyKey: 'legacy', accountId: 'acc-4');
      expect(await store.read('acc-4'), '{"new":true}');
    },
  );

  test('mirrorLegacy copies the legacy blob when present', () async {
    keychain.values['sync_s3_config'] = '{"v":1}';
    await store.mirrorLegacy(legacyKey: 'sync_s3_config', accountId: 'acc-7');
    expect(await store.read('acc-7'), '{"v":1}');
  });

  test('mirrorLegacy deletes the per-account key when the legacy key is '
      'absent (a cleared credential is never resurrected)', () async {
    await store.write('acc-8', '{"stale":true}');
    // legacy key not present
    await store.mirrorLegacy(legacyKey: 'sync_s3_config', accountId: 'acc-8');
    expect(await store.read('acc-8'), isNull);
  });

  test(
    'mirrorLegacy leaves the legacy key untouched (source of truth)',
    () async {
      keychain.values['sync_s3_config'] = '{"v":1}';
      await store.mirrorLegacy(legacyKey: 'sync_s3_config', accountId: 'acc-9');
      expect(keychain.values['sync_s3_config'], '{"v":1}');
    },
  );

  test(
    'rekeyFromLegacy overwrite refreshes an existing per-account blob',
    () async {
      await store.write('acc-5', '{"stale":true}');
      keychain.values['sync_dropbox_auth'] = '{"fresh":true}';
      await store.rekeyFromLegacy(
        legacyKey: 'sync_dropbox_auth',
        accountId: 'acc-5',
        overwrite: true,
      );
      expect(await store.read('acc-5'), '{"fresh":true}');
    },
  );

  test('rekeyFromLegacy overwrite is a no-op when legacy is absent', () async {
    await store.write('acc-6', '{"keep":true}');
    await store.rekeyFromLegacy(
      legacyKey: 'missing',
      accountId: 'acc-6',
      overwrite: true,
    );
    expect(await store.read('acc-6'), '{"keep":true}');
  });
}
