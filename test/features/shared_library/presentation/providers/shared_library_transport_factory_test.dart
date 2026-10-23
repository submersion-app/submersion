// Issue #3563: an older build's start-up deduplicator removed a shared
// library's account row on every launch, and a device still on that build
// syncs the removal to the others. The library's keys stay on this device,
// so the row is put back from them and the library syncs as before.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/shared_library/library_sync_error.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/test_database.dart';
import '../../../../support/fake_keychain_storage.dart';

void main() {
  late AccountCredentialsStore credentials;
  late ProviderContainer container;
  late List<ConnectedAccount> builtFor;

  final config = S3Config(
    endpoint: 'https://r2.example.com',
    bucket: 'reef-sites',
    prefix: 'submersion-sites/reef-team/',
    accessKeyId: 'AKIA1',
    secretAccessKey: 'shh',
  );
  final accountId = accountIdFor(
    kind: AccountKind.s3,
    naturalKey: s3NaturalKey(config),
  );
  final library = SharedLibrary(
    id: 'L',
    name: 'Reef Survey',
    connectedAccountId: accountId,
    prefix: 'reef-team',
  );

  setUp(() async {
    await setUpTestDatabase();
    credentials = AccountCredentialsStore(storage: InMemoryKeychain());
    builtFor = [];
    container = ProviderContainer(
      overrides: [
        accountCredentialsStoreProvider.overrideWithValue(credentials),
        sharedLibraryAccountTransportProvider.overrideWithValue(({
          required account,
          required prefix,
        }) async {
          builtFor.add(account);
          return SharedLibraryTransport(
            FakeCloudStorageProvider(),
            prefix: prefix,
          );
        }),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  Future<SharedLibraryTransport> transportFor(SharedLibrary l) =>
      container.read(sharedLibraryTransportFactoryProvider)(l);

  test('a removed account row comes back from the keys held here', () async {
    await credentials.write(accountId, jsonEncode(config.toJson()));

    await transportFor(library);

    expect(builtFor.single.id, accountId);
    final row = await ConnectedAccountsRepository().getById(accountId);
    expect(
      row!.label,
      'reef-sites @ r2.example.com (submersion-sites/reef-team)',
    );
  });

  test('with no keys here the library reports its account missing', () async {
    await expectLater(
      transportFor(library),
      throwsA(isA<LibraryAccountMissingError>()),
    );
    expect(builtFor, isEmpty);
  });

  test('the lookup the membership service uses puts it back too', () async {
    await credentials.write(accountId, jsonEncode(config.toJson()));

    final account = await container.read(libraryAccountLookupProvider)(
      accountId,
    );

    expect(account!.id, accountId);
  });
}
