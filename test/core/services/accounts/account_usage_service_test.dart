import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';

import '../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ConnectedAccountsRepository accounts;
  late SyncRepository sync;
  late MediaStoreAttachState attach;
  late SharedLibraryStore libraries;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    accounts = ConnectedAccountsRepository();
    sync = SyncRepository();
    attach = MediaStoreAttachState(prefs: prefs);
    libraries = SharedLibraryStore();
    await sync.getOrCreateMetadata();
  });

  tearDown(() => tearDownTestDatabase());

  AccountUsageService service() => AccountUsageService(
    syncRepository: sync,
    attachState: attach,
    libraries: libraries,
  );

  Future<void> addLibrary(String id, String name, String accountId) =>
      libraries.upsertLibrary(
        SharedLibrary(
          id: id,
          name: name,
          connectedAccountId: accountId,
          prefix: '',
        ),
      );

  group('backup copies', () {
    Future<AccountUsageService> withBackupPrefs(Map<String, Object> v) async {
      SharedPreferences.setMockInitialValues(v);
      return AccountUsageService(
        syncRepository: sync,
        attachState: attach,
        libraries: libraries,
        backupPreferences: BackupPreferences(
          await SharedPreferences.getInstance(),
        ),
      );
    }

    test(
      'the account the copy is pinned to is used for backup copies',
      () async {
        final account = await accounts.create(
          kind: AccountKind.dropbox,
          label: 'Dropbox',
        );
        final usage = await withBackupPrefs({
          'backup_cloud_enabled': true,
          'backup_copy_account_id': account.id,
          'backup_copy_account_kind': 'dropbox',
        });

        expect((await usage.load()).usagesOf(account), const [
          AccountUsage(AccountUsageKind.backupCopy),
        ]);
      },
    );

    test('a pinned copy that is off uses nothing', () async {
      final account = await accounts.create(
        kind: AccountKind.dropbox,
        label: 'Dropbox',
      );
      final usage = await withBackupPrefs({
        'backup_copy_account_id': account.id,
        'backup_copy_account_kind': 'dropbox',
      });

      expect((await usage.load()).usagesOf(account), isEmpty);
    });
  });

  test('an account nothing on this device uses has no usages', () async {
    final account = await accounts.create(
      kind: AccountKind.dropbox,
      label: 'Dropbox',
    );

    final usages = (await service().load()).usagesOf(account);

    expect(usages, isEmpty);
  });

  test('the selected sync account is used for database sync', () async {
    final account = await accounts.create(kind: AccountKind.s3, label: 'S3');
    await sync.setSyncAccount(
      accountId: account.id,
      providerType: CloudProviderType.s3,
    );

    final usages = (await service().load()).usagesOf(account);

    expect(usages, [const AccountUsage(AccountUsageKind.databaseSync)]);
  });

  test('turning sync off drops the database sync usage', () async {
    final account = await accounts.create(kind: AccountKind.s3, label: 'S3');
    await sync.setSyncAccount(
      accountId: account.id,
      providerType: CloudProviderType.s3,
    );
    await sync.setCloudProvider(null);

    final usages = (await service().load()).usagesOf(account);

    expect(usages, isEmpty);
  });

  test('the attached media store account is used for media storage', () async {
    final account = await accounts.create(
      kind: AccountKind.dropbox,
      label: 'Dropbox',
    );
    await attach.setAttached(
      'store-1',
      providerType: CloudProviderType.dropbox,
      accountId: account.id,
    );

    final usages = (await service().load()).usagesOf(account);

    expect(usages, [const AccountUsage(AccountUsageKind.mediaStorage)]);
  });

  test('each shared library on the account is listed by name', () async {
    final account = await accounts.create(
      kind: AccountKind.googledrive,
      label: 'Drive',
    );
    final other = await accounts.create(kind: AccountKind.s3, label: 'S3');
    await addLibrary('lib-2', 'Wreck Club', account.id);
    await addLibrary('lib-1', 'Club Sites', account.id);
    await addLibrary('lib-3', 'Elsewhere', other.id);

    final usages = (await service().load()).usagesOf(account);

    // Sorted by name so the row reads the same on every load.
    expect(usages, [
      const AccountUsage(
        AccountUsageKind.sharedLibrary,
        libraryName: 'Club Sites',
      ),
      const AccountUsage(
        AccountUsageKind.sharedLibrary,
        libraryName: 'Wreck Club',
      ),
    ]);
  });

  test('a Lightroom account is the Lightroom connector', () async {
    final account = await accounts.create(
      kind: AccountKind.adobeLightroom,
      label: 'Lightroom',
    );

    final usages = (await service().load()).usagesOf(account);

    expect(usages, [const AccountUsage(AccountUsageKind.lightroom)]);
  });

  test('every usage of one account, in a fixed order', () async {
    final account = await accounts.create(
      kind: AccountKind.dropbox,
      label: 'Dropbox',
    );
    await addLibrary('lib-1', 'Club Sites', account.id);
    await attach.setAttached(
      'store-1',
      providerType: CloudProviderType.dropbox,
      accountId: account.id,
    );
    await sync.setSyncAccount(
      accountId: account.id,
      providerType: CloudProviderType.dropbox,
    );

    final usages = (await service().load()).usagesOf(account);

    expect(usages, [
      const AccountUsage(AccountUsageKind.databaseSync),
      const AccountUsage(AccountUsageKind.mediaStorage),
      const AccountUsage(
        AccountUsageKind.sharedLibrary,
        libraryName: 'Club Sites',
      ),
    ]);
  });
}
