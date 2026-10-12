import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/webdav_account_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav_storage_provider.dart';
import 'package:submersion/core/services/media_store/webdav_media_object_store.dart';

import '../../../../support/fake_keychain_storage.dart';

void main() {
  final account = ConnectedAccount(
    id: 'acc-1',
    kind: AccountKind.webdav,
    label: 'alice @ dav.test',
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  final config = WebDavConfig(
    serverUrl: 'https://dav.test/dav',
    username: 'alice',
    password: 'secret',
  );

  test(
    'status follows the per-account blob and disconnect removes it',
    () async {
      final adapter = WebDavAccountAdapter(
        credentials: AccountCredentialsStore(storage: InMemoryKeychain()),
        legacySync: WebDavCredentialsStore(storage: InMemoryKeychain()),
      );
      expect(adapter.kind, AccountKind.webdav);
      expect(await adapter.status(account), AccountStatus.needsSignIn);
      expect(await adapter.mediaObjectStore(account), isNull);
      await adapter.saveConfig(account, config);
      expect(await adapter.status(account), AccountStatus.signedIn);
      expect((await adapter.loadConfig(account))!.toJson(), config.toJson());
      expect(
        await adapter.mediaObjectStore(account),
        isA<WebDavMediaObjectStore>(),
      );
      expect(adapter.syncProvider(account), isA<WebDavStorageProvider>());
      await adapter.disconnect(account);
      expect(await adapter.status(account), AccountStatus.needsSignIn);
    },
  );

  test(
    'disconnecting the sync endpoint account also clears the legacy sync blob',
    () async {
      final keychain = InMemoryKeychain();
      final legacy = WebDavCredentialsStore(storage: keychain);
      await legacy.save(config);
      final adapter = WebDavAccountAdapter(
        credentials: AccountCredentialsStore(storage: keychain),
        legacySync: legacy,
      );
      final media = ConnectedAccount(
        id: accountIdFor(
          kind: AccountKind.webdav,
          naturalKey: webdavNaturalKey(
            config.copyWith(folder: kDefaultWebDavMediaFolder),
          ),
        ),
        kind: AccountKind.webdav,
        label: 'm',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      await adapter.disconnect(media);
      expect(
        await legacy.load(),
        isNotNull,
        reason: 'a media account leaves sync alone',
      );

      final sync = ConnectedAccount(
        id: accountIdFor(
          kind: AccountKind.webdav,
          naturalKey: webdavNaturalKey(config),
        ),
        kind: AccountKind.webdav,
        label: 's',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      await adapter.disconnect(sync);
      expect(await legacy.load(), isNull);
    },
  );

  test(
    'disconnecting the sync endpoint drops the settings provider cache',
    () async {
      final keychain = InMemoryKeychain();
      final legacy = WebDavCredentialsStore(storage: keychain);
      await legacy.save(config);
      final settings = WebDavStorageProvider(store: legacy);
      expect(await settings.loadConfig(), isNotNull); // now cached
      final adapter = WebDavAccountAdapter(
        credentials: AccountCredentialsStore(storage: keychain),
        legacySync: legacy,
        syncSettings: settings,
      );
      await adapter.disconnect(
        ConnectedAccount(
          id: accountIdFor(
            kind: AccountKind.webdav,
            naturalKey: webdavNaturalKey(config),
          ),
          kind: AccountKind.webdav,
          label: 's',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );
      expect(await settings.loadConfig(), isNull);
      expect(await settings.isAuthenticated(), isFalse);
    },
  );
}
