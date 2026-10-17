import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/shared_library/library_account_setup.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/shared_library/presentation/providers/library_connection_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';

import '../../../../helpers/test_database.dart';

class _FakeSetup extends LibraryAccountSetup {
  @override
  Future<String?> s3Bucket(String accountId) async => 'bucket-of-$accountId';

  @override
  Future<String?> webdavServer(String accountId) async =>
      'https://dav.example.com/$accountId';
}

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<LibraryConnectionDetails?> detailsFor(String accountId) async {
    final container = ProviderContainer(
      overrides: [
        libraryAccountSetupProvider.overrideWithValue(_FakeSetup()),
        sharedLibrariesProvider.overrideWith(
          (ref) => Stream.value([
            SharedLibrary(
              id: 'L',
              name: 'Reef Survey',
              connectedAccountId: accountId,
              prefix: 'reef',
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(
      libraryConnectionDetailsProvider('L'),
      (_, _) {},
    );
    addTearDown(sub.close);
    return container.read(libraryConnectionDetailsProvider('L').future);
  }

  test('an S3 account comes with its bucket', () async {
    final a = await ConnectedAccountsRepository().ensure(
      kind: AccountKind.s3,
      naturalKey: 's3-key',
      label: 'Survey bucket',
    );
    final d = (await detailsFor(a.id))!;
    expect(d.account!.label, 'Survey bucket');
    expect(d.bucket, 'bucket-of-${a.id}');
    expect(d.server, isNull);
    expect(d.folder, 'submersion-sites/reef');
  });

  test('a WebDAV account comes with its server', () async {
    final a = await ConnectedAccountsRepository().ensure(
      kind: AccountKind.webdav,
      naturalKey: 'dav-key',
      label: 'Group server',
    );
    final d = (await detailsFor(a.id))!;
    expect(d.server, 'https://dav.example.com/${a.id}');
    expect(d.bucket, isNull);
  });

  test('a library not connected here has no details', () async {
    final container = ProviderContainer(
      overrides: [
        libraryAccountSetupProvider.overrideWithValue(_FakeSetup()),
        sharedLibrariesProvider.overrideWith(
          (ref) => Stream.value(const <SharedLibrary>[]),
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(
      libraryConnectionDetailsProvider('L'),
      (_, _) {},
    );
    addTearDown(sub.close);
    expect(
      await container.read(libraryConnectionDetailsProvider('L').future),
      isNull,
    );
  });

  test('an account no longer on the device is null', () async {
    final d = (await detailsFor('gone'))!;
    expect(d.account, isNull);
    expect(d.prefix, 'reef');
  });
}
