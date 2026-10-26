// Issue #3482 phase 3: the backup copy goes to the account the diver chose,
// built the way sync builds its provider, or follows sync when none is chosen.

import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_provider_registry.dart';
import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/encrypting_cloud_storage_provider.dart';
import 'package:submersion/core/services/sync/crypto/encryption_key_store.dart';
import 'package:submersion/features/backup/presentation/providers/backup_copy_providers.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

final _t = DateTime.utc(2026);

ConnectedAccount _row(String id, AccountKind kind) => ConnectedAccount(
  id: id,
  kind: kind,
  label: id,
  createdAt: _t,
  updatedAt: _t,
);

/// The sync account ('acct-sync', iCloud) and another ('acct-b', S3).
List<AccountGroup> _groups() => groupAccounts(
  rows: [_row('acct-sync', AccountKind.icloud), _row('acct-b', AccountKind.s3)],
  statusById: const {
    'acct-sync': AccountStatus.signedIn,
    'acct-b': AccountStatus.signedIn,
  },
  localLocationById: const {},
  usagesOf: (a) => a.id == 'acct-sync'
      ? const [AccountUsage(AccountUsageKind.databaseSync)]
      : const [],
);

class _Provider extends Fake implements CloudStorageProvider {
  _Provider(this.name);
  final String name;

  @override
  String get providerName => name;
}

/// An S3 adapter that records which row it was asked to build.
class _RecordingSyncAdapter extends AccountProviderAdapter
    implements SyncCapable {
  final built = <String>[];

  @override
  AccountKind get kind => AccountKind.s3;

  @override
  Future<AccountStatus> status(ConnectedAccount account) async =>
      AccountStatus.signedIn;

  @override
  Future<void> disconnect(ConnectedAccount account) async {}

  @override
  CloudStorageProvider syncProvider(ConnectedAccount account) {
    built.add(account.id);
    return _Provider('copy:${account.id}');
  }
}

class _SeededKeyNotifier extends EncryptionKeyNotifier {
  _SeededKeyNotifier(
    super.keyStore,
    super.preferences,
    EncryptionSessionState s,
  ) {
    state = s;
  }
}

void main() {
  late _RecordingSyncAdapter adapter;
  final syncProvider = _Provider('sync');

  Future<ProviderContainer> container(
    Map<String, Object> prefs, {
    bool unlocked = false,
    bool onRoster = true,
    Future<bool> Function()? rosterLookup,
    bool customFolder = false,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final shared = await SharedPreferences.getInstance();
    adapter = _RecordingSyncAdapter();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(shared),
        accountGroupsProvider.overrideWith((ref) async => _groups()),
        accountProviderRegistryProvider.overrideWithValue(
          AccountProviderRegistry([adapter]),
        ),
        cloudStorageProviderProvider.overrideWithValue(syncProvider),
        copyRowOnRosterProvider.overrideWith(
          (ref, id) => (rosterLookup ?? () async => onRoster)(),
        ),
        isCloudSyncDisabledByCustomFolderProvider.overrideWithValue(
          customFolder,
        ),
        if (unlocked)
          encryptionKeyNotifierProvider.overrideWith(
            (ref) => _SeededKeyNotifier(
              ref.watch(encryptionKeyStoreProvider),
              ref.watch(syncPreferencesProvider),
              EncryptionSessionState(
                key: UnlockedKey(
                  libraryKeyId: 'k',
                  mlk: SecretKey(List<int>.filled(32, 1)),
                ),
                dataKey: SecretKey(List<int>.filled(32, 2)),
              ),
            ),
          ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Reads the copy provider once the roster lookup has settled, as the
  /// app sees it after its first rebuild.
  Future<CloudStorageProvider?> settledCopyProvider(ProviderContainer c) async {
    c.listen(backupCopyProviderProvider, (_, _) {});
    try {
      await c.read(copyRowOnRosterProvider('acct-b').future);
    } on Object {
      // An unreadable roster settles too.
    }
    return c.read(backupCopyProviderProvider);
  }

  const pinned = {
    'backup_cloud_enabled': true,
    'backup_copy_account_id': 'acct-b',
    'backup_copy_account_kind': 's3',
  };

  group('backupCopyTargetProvider', () {
    test('the copy off reads as no copy', () async {
      final c = await container({});
      expect(await c.read(backupCopyTargetProvider.future), isA<NoCopy>());
    });

    test('on with no account chosen follows the sync account', () async {
      final c = await container({'backup_cloud_enabled': true});
      final target = await c.read(backupCopyTargetProvider.future);
      expect(target, isA<CopyFollowsSync>());
      expect((target as CopyFollowsSync).group?.rows.single.id, 'acct-sync');
    });

    // Sync has no provider while the database is in a custom folder.
    test('following sync in custom-folder mode reads as no account', () async {
      final c = await container({
        'backup_cloud_enabled': true,
      }, customFolder: true);
      final target = await c.read(backupCopyTargetProvider.future);
      expect((target as CopyFollowsSync).group, isNull);
    });

    test('a chosen account names its group and row', () async {
      final c = await container(pinned);
      final target = await c.read(backupCopyTargetProvider.future);
      expect(target, isA<CopyToAccount>());
      expect((target as CopyToAccount).row.id, 'acct-b');
      expect(target.group.rows.single.id, 'acct-b');
    });

    test('a chosen account no longer on the roster reads as gone', () async {
      final c = await container({
        ...pinned,
        'backup_copy_account_id': 'acct-gone',
      });
      final target = await c.read(backupCopyTargetProvider.future);
      expect(target, isA<CopyAccountGone>());
      expect((target as CopyAccountGone).accountId, 'acct-gone');
    });
  });

  group('pinnedCopyAccountIdProvider', () {
    test('names the pinned row while the copy is on', () async {
      final c = await container(pinned);
      expect(c.read(pinnedCopyAccountIdProvider), 'acct-b');
    });

    test('ignores a pin left behind with the copy off', () async {
      final c = await container({
        'backup_copy_account_id': 'acct-b',
        'backup_copy_account_kind': 's3',
      });
      expect(c.read(pinnedCopyAccountIdProvider), isNull);
    });
  });

  group('backupCopyProviderProvider', () {
    test('following sync uses the sync provider', () async {
      final c = await container({'backup_cloud_enabled': true});
      expect(c.read(backupCopyProviderProvider), same(syncProvider));
      expect(adapter.built, isEmpty);
    });

    test('a chosen account builds from that row, not the sync one', () async {
      final c = await container(pinned);
      final provider = await settledCopyProvider(c);
      expect(adapter.built, ['acct-b']);
      expect(provider?.providerName, 'copy:acct-b');
    });

    test(
      'with sync encryption unlocked the chosen provider is sealed',
      () async {
        final c = await container(pinned, unlocked: true);
        expect(
          await settledCopyProvider(c),
          isA<EncryptingCloudStorageProvider>(),
        );
      },
    );

    // Removed on another device: its keys may still be here, but nothing
    // is copied to an account the diver removed.
    test('a chosen account gone from the roster copies nowhere', () async {
      final c = await container(pinned, onRoster: false);
      expect(await settledCopyProvider(c), isNull);
    });

    // Review of #3541: a removed account must not get a copy in the window
    // before the roster has answered.
    test('nothing is copied while the roster lookup is pending', () async {
      final c = await container(
        pinned,
        rosterLookup: () => Completer<bool>().future,
      );
      expect(c.read(backupCopyProviderProvider), isNull);
      expect(adapter.built, isEmpty);
    });

    // As in the background: a database hiccup costs a copy nothing.
    test('an unreadable roster still copies', () async {
      final c = await container(
        pinned,
        rosterLookup: () async => throw StateError('database closed'),
      );
      expect((await settledCopyProvider(c))?.providerName, 'copy:acct-b');
    });

    test('the copy off still lists the sync folder, as before', () async {
      final c = await container({
        'backup_copy_account_id': 'acct-b',
        'backup_copy_account_kind': 's3',
      });
      expect(c.read(backupCopyProviderProvider), same(syncProvider));
    });
  });
}
