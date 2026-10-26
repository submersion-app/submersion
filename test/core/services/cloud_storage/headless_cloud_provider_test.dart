import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/encrypting_cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/headless_cloud_provider.dart';
import 'package:submersion/core/services/sync/crypto/encryption_key_store.dart';
import 'package:submersion/core/services/sync/sync_preferences.dart';

import '../../../support/fake_cloud_storage_provider.dart';
import '../../../support/fake_keychain_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EncryptionKeyStore keyStore;
  final built = <CloudProviderType>[];

  CloudStorageProvider instanceFor(CloudProviderType type) {
    built.add(type);
    return FakeCloudStorageProvider(providerId: type.name);
  }

  setUp(() {
    keyStore = EncryptionKeyStore(storage: InMemoryKeychain());
    built.clear();
  });

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  Future<CloudStorageProvider?> resolve(SharedPreferences prefs) =>
      resolveHeadlessCloudProvider(
        prefs: prefs,
        encryptionKeyStore: keyStore,
        instanceFor: instanceFor,
      );

  test('resolves the provider recorded by the foreground app', () async {
    final prefs = await prefsWith({'sync_last_provider': 'dropbox'});

    final provider = await resolve(prefs);

    expect(provider, isA<FakeCloudStorageProvider>());
    expect(provider!.providerId, 'dropbox');
    expect(built, [CloudProviderType.dropbox]);
  });

  test('null when no provider has been selected', () async {
    final prefs = await prefsWith({});

    expect(await resolve(prefs), isNull);
    expect(built, isEmpty);
  });

  test('null for an unrecognized stored provider name', () async {
    final prefs = await prefsWith({'sync_last_provider': 'mystery-drive'});

    expect(await resolve(prefs), isNull);
    expect(built, isEmpty);
  });

  test('null in custom-folder storage mode, where an external service '
      'owns the sync', () async {
    final prefs = await prefsWith({
      'sync_last_provider': 'dropbox',
      'db_storage_mode': 'customFolder',
    });

    expect(await resolve(prefs), isNull);
    expect(built, isEmpty);
  });

  test('wraps in the encrypting decorator when sync encryption is on and '
      'the key is on this device', () async {
    final prefs = await prefsWith({'sync_last_provider': 's3'});
    await SyncPreferences(prefs).setSyncEncryptionEnabled(true);
    await keyStore.saveKey(
      libraryKeyId: 'lib-1',
      mlkBytes: List<int>.generate(32, (i) => i),
    );

    final provider = await resolve(prefs);

    expect(provider, isA<EncryptingCloudStorageProvider>());
    expect((provider as EncryptingCloudStorageProvider).inner.providerId, 's3');
  });

  test(
    'stays raw when sync encryption is on but no key is cached here',
    () async {
      final prefs = await prefsWith({'sync_last_provider': 's3'});
      await SyncPreferences(prefs).setSyncEncryptionEnabled(true);

      final provider = await resolve(prefs);

      expect(provider, isA<FakeCloudStorageProvider>());
    },
  );

  test('stays raw when a key exists but sync encryption is off', () async {
    final prefs = await prefsWith({'sync_last_provider': 's3'});
    await keyStore.saveKey(
      libraryKeyId: 'lib-1',
      mlkBytes: List<int>.generate(32, (i) => i),
    );

    final provider = await resolve(prefs);

    expect(provider, isA<FakeCloudStorageProvider>());
  });

  test('a decorator failure resolves to no provider rather than throwing '
      'the whole scheduled backup away', () async {
    final prefs = await prefsWith({'sync_last_provider': 's3'});
    await SyncPreferences(prefs).setSyncEncryptionEnabled(true);
    await keyStore.saveKey(
      libraryKeyId: 'lib-1',
      mlkBytes: List<int>.generate(32, (i) => i),
    );

    final provider = await resolveHeadlessCloudProvider(
      prefs: prefs,
      encryptionKeyStore: _ThrowingKeyStore(),
      instanceFor: instanceFor,
    );

    expect(provider, isNull);
  });
  group('the backup copy', () {
    final pinned = <(AccountKind, String)>[];

    CloudStorageProvider forAccount(AccountKind kind, String id) {
      pinned.add((kind, id));
      return FakeCloudStorageProvider(providerId: 'copy:$id');
    }

    setUp(pinned.clear);

    Future<CloudStorageProvider?> resolveCopy(
      SharedPreferences prefs, {
      bool onRoster = true,
    }) => resolveHeadlessBackupCopyProvider(
      prefs: prefs,
      encryptionKeyStore: keyStore,
      instanceFor: instanceFor,
      forAccount: forAccount,
      accountOnRoster: (_) async => onRoster,
    );

    test(
      'a chosen account resolves to it, not to the sync selection',
      () async {
        final prefs = await prefsWith({
          'sync_last_provider': 's3',
          'backup_cloud_enabled': true,
          'backup_copy_account_id': 'acct-b',
          'backup_copy_account_kind': 's3',
        });

        final provider = await resolveCopy(prefs);

        expect(provider!.providerId, 'copy:acct-b');
        expect(pinned, [(AccountKind.s3, 'acct-b')]);
        expect(built, isEmpty);
      },
    );

    test('with no account chosen it resolves exactly as sync does', () async {
      final prefs = await prefsWith({
        'sync_last_provider': 'dropbox',
        'backup_cloud_enabled': true,
      });

      expect((await resolveCopy(prefs))!.providerId, 'dropbox');
      expect(pinned, isEmpty);
    });

    test('a chosen account resolves even with sync off', () async {
      final prefs = await prefsWith({
        'backup_cloud_enabled': true,
        'backup_copy_account_id': 'acct-d',
        'backup_copy_account_kind': 'dropbox',
      });

      expect((await resolveCopy(prefs))!.providerId, 'copy:acct-d');
    });

    // As in the foreground: the copy's account has nothing to do with
    // where the database lives.
    test('a chosen account copies in custom-folder storage mode too', () async {
      final prefs = await prefsWith({
        'db_storage_mode': 'customFolder',
        'backup_cloud_enabled': true,
        'backup_copy_account_id': 'acct-b',
        'backup_copy_account_kind': 's3',
      });

      expect((await resolveCopy(prefs))!.providerId, 'copy:acct-b');
    });

    test('a chosen account removed from the roster copies nowhere', () async {
      final prefs = await prefsWith({
        'sync_last_provider': 's3',
        'backup_cloud_enabled': true,
        'backup_copy_account_id': 'acct-b',
        'backup_copy_account_kind': 's3',
      });

      expect(await resolveCopy(prefs, onRoster: false), isNull);
      expect(pinned, isEmpty);
      expect(built, isEmpty);
    });
  });
}

/// Models a keychain read that fails (locked device, revoked entitlement).
class _ThrowingKeyStore implements EncryptionKeyStore {
  @override
  Future<UnlockedKey?> loadKey() async => throw StateError('keychain locked');

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
