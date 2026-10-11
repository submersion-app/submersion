import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_client.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_preset.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/media_store/media_store_credentials_store.dart';
import 'package:submersion/features/media_store/data/media_store_service.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';

import '../../helpers/fake_webdav_server.dart';
import '../../helpers/test_database.dart';
import '../../support/fake_keychain_storage.dart';

void main() {
  late FakeWebDavServer server;
  late MediaStoreAttachState attachState;
  late AccountCredentialsStore accountCredentials;
  late ConnectedAccountsRepository accounts;
  late MediaStoreService service;

  final config = WebDavConfig(
    preset: WebDavPreset.other,
    serverUrl: 'https://dav.test/dav',
    username: 'alice',
    password: 'secret',
    folder: kDefaultWebDavMediaFolder,
  );

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    server = FakeWebDavServer();
    attachState = MediaStoreAttachState(
      prefs: await SharedPreferences.getInstance(),
    );
    accountCredentials = AccountCredentialsStore(storage: InMemoryKeychain());
    accounts = ConnectedAccountsRepository();
    service = MediaStoreService(
      credentials: MediaStoreCredentialsStore(storage: InMemoryKeychain()),
      attachState: attachState,
      storesRepository: MediaStoresRepository(),
      accountsRepository: accounts,
      accountCredentials: accountCredentials,
      markerRetryBackoff: const [],
      webdavClientFactory: (c) => WebDavClient(
        c,
        httpClient: server.client,
        backoff: (_) => Duration.zero,
      ),
    );
  });

  tearDown(() => tearDownTestDatabase());

  test('testWebDav probes and leaves nothing behind', () async {
    await service.testWebDav(config);
    expect(server.files.keys.where((k) => k.contains('probe')), isEmpty);
  });

  test(
    'connectWebDav writes the marker, account, credentials and attach state',
    () async {
      final result = await service.connectWebDav(config);
      expect(
        server.files.keys,
        contains('/dav/Submersion Media/smv1/store.json'),
      );
      expect(await attachState.attachedStoreId(), result.storeId);
      expect(
        await attachState.attachedProviderType(),
        CloudProviderType.webdav,
      );
      final accountId = await attachState.attachedAccountId();
      final account = await accounts.getById(accountId!);
      expect(account!.kind, AccountKind.webdav);
      expect(
        account.id,
        accountIdFor(
          kind: AccountKind.webdav,
          naturalKey: webdavNaturalKey(config),
        ),
      );
      expect(
        await accountCredentials.read(account.id),
        contains('"folder":"Submersion Media"'),
      );
    },
  );

  test('a second device adopts the existing store', () async {
    final first = await service.connectWebDav(config);
    await attachState.clear();
    final second = await service.connectWebDav(config);
    expect(second.storeId, first.storeId);
    expect(second.createdNewStore, isFalse);
  });

  test('a wrong password is an auth MediaStoreException', () async {
    await expectLater(
      service.connectWebDav(config.copyWith(password: 'nope')),
      throwsA(
        isA<MediaStoreException>().having(
          (e) => e.kind,
          'kind',
          MediaStoreErrorKind.auth,
        ),
      ),
    );
  });

  test(
    'a server that refuses the principal lookup still connects with the login name',
    () async {
      server = FakeWebDavServer(
        seedCollections: const ['/remote.php/dav/files/alice'],
      );
      server.forcedStatuses.add(405);
      final result = await service.connectWebDav(
        WebDavConfig(
          preset: WebDavPreset.nextcloud,
          serverUrl: 'https://dav.test',
          username: 'alice',
          password: 'secret',
          folder: kDefaultWebDavMediaFolder,
        ),
      );
      expect(result.storeId, isNotEmpty);
    },
  );
}
