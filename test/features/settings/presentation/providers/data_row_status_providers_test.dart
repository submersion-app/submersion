// Issue #3482: the row status providers read the same health list as the
// strip plus small overridable leaf inputs, never build the media runtime,
// never probe an account, and never leave a row on "Checking..." forever.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/pending_setup_service.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/domain/data_health/data_row_status.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/domain/data_health/media_health.dart';
import 'package:submersion/features/settings/presentation/providers/data_health_providers.dart';
import 'package:submersion/features/settings/presentation/providers/data_row_status_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/pending_setup_card.dart';

const _r2Host = '149b84f66d5479265f3e4d4ad4740926.r2.cloudflarestorage.com';

const _healthy = [
  FeatureHealth(
    feature: DataFeature.backup,
    level: HealthLevel.healthy,
    reason: HealthReason.ok,
  ),
  FeatureHealth(
    feature: DataFeature.sync,
    level: HealthLevel.healthy,
    reason: HealthReason.ok,
  ),
  FeatureHealth(
    feature: DataFeature.sharedLibraries,
    level: HealthLevel.healthy,
    reason: HealthReason.ok,
  ),
  FeatureHealth(
    feature: DataFeature.media,
    level: HealthLevel.notSetUp,
    reason: HealthReason.notSetUp,
  ),
];

final _providersSource = p.join(
  'lib',
  'features',
  'settings',
  'presentation',
  'providers',
  'data_row_status_providers.dart',
);

class _FakeStores extends Fake implements MediaStoresRepository {
  _FakeStores(this.hints, {this.active});
  final Map<String, String> hints;
  final String? active;

  @override
  Stream<void> watchStoresChanges() => const Stream.empty();

  @override
  Future<MediaStoreDescriptor?> getById(String storeId) async {
    final hint = hints[storeId];
    return hint == null ? null : _descriptor(storeId, hint);
  }

  @override
  Future<MediaStoreDescriptor?> getActive() async =>
      active == null ? null : _descriptor(active!, hints[active!] ?? '');

  MediaStoreDescriptor _descriptor(String id, String hint) =>
      (id: id, providerType: 's3', displayHint: hint, lastSweepAt: null);
}

class _FakeAccounts extends Fake implements ConnectedAccountsRepository {
  _FakeAccounts(this.labels, {this.nicknames = const {}});
  final Map<String, String> labels;
  final Map<String, String> nicknames;

  @override
  Stream<void> watchAccountsChanges() => const Stream.empty();

  @override
  Future<domain.ConnectedAccount?> getById(String id) async {
    final label = labels[id];
    return label == null ? null : _account(id, label);
  }

  @override
  Future<List<domain.ConnectedAccount>> getAll() async => [
    for (final e in labels.entries) _account(e.key, e.value),
  ];

  domain.ConnectedAccount _account(String id, String label) {
    final at = DateTime(2026);
    return domain.ConnectedAccount(
      id: id,
      kind: AccountKind.googledrive,
      label: label,
      nickname: nicknames[id],
      createdAt: at,
      updatedAt: at,
    );
  }
}

PendingSetupItem _signIn(String key, {bool dismissed = false}) =>
    PendingSetupItem(
      kind: SetupItemKind.accountSignIn,
      key: key,
      label: key,
      route: '/settings/cloud-sync',
      dismissed: dismissed,
    );

MediaHealthInputs _inputs({required bool attached}) => MediaHealthInputs(
  storeAttachedHere: attached,
  storeAnnounced: attached,
  lightroomConnected: false,
  mediaSetupItems: 0,
  transfersWaitingWithReason: false,
);

void main() {
  final when = DateTime(2026, 10, 18, 9);

  ProviderContainer container(
    List<Override> overrides, {
    List<FeatureHealth> health = _healthy,
  }) {
    final c = ProviderContainer(
      overrides: [dataHealthProvider.overrideWithValue(health), ...overrides],
    );
    addTearDown(c.dispose);
    return c;
  }

  // Riverpod pauses a provider nobody listens to, so a stream read with
  // `read(.future)` alone never emits. Subscribe first, the way the page does.
  void keep(ProviderContainer c, ProviderListenable<Object?> p) =>
      c.listen(p, (_, _) {});

  group('sync row', () {
    test('names the single peer', () async {
      final c = container([
        lastSyncTimeProvider.overrideWithValue(when),
        peerDeviceNamesProvider.overrideWith(
          (ref) => Stream.value(const {'id-1': "Eric's iPhone"}),
        ),
      ]);
      keep(c, syncRowStatusProvider);
      await c.read(peerDeviceNamesProvider.future);
      final s = c.read(syncRowStatusProvider);
      expect(
        (s.kind, s.name, s.when),
        (DataRowStatusKind.syncWithOne, "Eric's iPhone", when),
      );
    });

    test('reads the stored names while the name stream is loading', () async {
      SharedPreferences.setMockInitialValues({
        'sync_peer_device_names': '{"id-1":"Eric\'s iPhone"}',
      });
      final prefs = await SharedPreferences.getInstance();
      final c = container([
        sharedPreferencesProvider.overrideWithValue(prefs),
        lastSyncTimeProvider.overrideWithValue(when),
        peerDeviceNamesProvider.overrideWith(
          (ref) => StreamController<Map<String, String>>().stream,
        ),
      ]);
      expect(c.read(syncPeerNamesProvider), ["Eric's iPhone"]);
    });
  });

  group('backups row', () {
    test(
      'names the sync account for a backup that reached the cloud',
      () async {
        final c = container([
          lastBackupTimeProvider.overrideWithValue(when),
          lastBackupDestinationProvider.overrideWithValue(
            LastBackupDestination.cloud,
          ),
          lastBackupCloudAccountLabelProvider.overrideWith(
            (ref) async => 'Google Drive',
          ),
        ]);
        keep(c, backupsRowStatusProvider);
        await c.read(lastBackupCloudAccountLabelProvider.future);
        final s = c.read(backupsRowStatusProvider);
        expect(
          (s.kind, s.name, s.when),
          (DataRowStatusKind.backupsCloud, 'Google Drive', when),
        );
      },
    );

    // PR #3500 review: after switching sync accounts, an older cloud backup
    // is still in the account it went to, not the one that syncs now.
    test(
      'names the account the backup went to, not the sync account',
      () async {
        final c = container([
          lastBackupCloudAccountIdProvider.overrideWithValue('acct-old'),
          connectedAccountsRepositoryProvider.overrideWithValue(
            _FakeAccounts({'acct-old': 'Old Drive', 'acct-new': 'New Drive'}),
          ),
        ]);
        keep(c, lastBackupCloudAccountLabelProvider);
        expect(
          await c.read(lastBackupCloudAccountLabelProvider.future),
          'Old Drive',
        );
      },
    );

    // Issue #3522: the backup account reads by its short name.
    test('names the backup account by its short name or nickname', () async {
      final c = container([
        lastBackupCloudAccountIdProvider.overrideWithValue('acct-r2'),
        connectedAccountsRepositoryProvider.overrideWithValue(
          _FakeAccounts({'acct-r2': 'backups @ $_r2Host'}),
        ),
      ]);
      keep(c, lastBackupCloudAccountLabelProvider);
      expect(
        await c.read(lastBackupCloudAccountLabelProvider.future),
        'backups @ Cloudflare R2',
      );

      final named = container([
        lastBackupCloudAccountIdProvider.overrideWithValue('acct-r2'),
        connectedAccountsRepositoryProvider.overrideWithValue(
          _FakeAccounts(
            {'acct-r2': 'backups @ $_r2Host'},
            nicknames: {'acct-r2': 'Backups'},
          ),
        ),
      ]);
      keep(named, lastBackupCloudAccountLabelProvider);
      expect(
        await named.read(lastBackupCloudAccountLabelProvider.future),
        'Backups',
      );
    });

    test('a removed account falls back to the generic cloud wording', () async {
      final c = container([
        lastBackupCloudAccountIdProvider.overrideWithValue('acct-gone'),
        connectedAccountsRepositoryProvider.overrideWithValue(
          _FakeAccounts({}),
        ),
      ]);
      keep(c, lastBackupCloudAccountLabelProvider);
      expect(await c.read(lastBackupCloudAccountLabelProvider.future), isNull);
    });

    test('reads the recorded cloud account from the backup settings', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final backupPrefs = BackupPreferences(prefs);
      await backupPrefs.setLastBackupDestination(
        LastBackupDestination.cloud,
        cloudAccountId: 'acct-drive',
      );
      final c = container([
        backupPreferencesProvider.overrideWithValue(backupPrefs),
      ]);
      expect(c.read(lastBackupCloudAccountIdProvider), 'acct-drive');
    });

    test('never reads the account label for a local backup', () {
      var built = false;
      final c = container([
        lastBackupTimeProvider.overrideWithValue(when),
        lastBackupDestinationProvider.overrideWithValue(
          LastBackupDestination.device,
        ),
        lastBackupCloudAccountLabelProvider.overrideWith((ref) async {
          built = true;
          return 'Google Drive';
        }),
      ]);
      expect(
        c.read(backupsRowStatusProvider).kind,
        DataRowStatusKind.backupsLocal,
      );
      expect(built, isFalse);
    });
  });

  group('photos row', () {
    test('never builds the media runtime', () {
      final source = File(_providersSource).readAsStringSync();
      expect(source, isNot(contains('mediaStoreRuntimeProvider')));
      expect(source, isNot(contains('mediaStoreStatusHintProvider')));
    });

    test('names the attached store, not the announced one', () async {
      SharedPreferences.setMockInitialValues({
        MediaStoreAttachState.storeIdKey: 'store-a',
      });
      final prefs = await SharedPreferences.getInstance();
      final c = container([
        sharedPreferencesProvider.overrideWithValue(prefs),
        mediaStoreAttachStateProvider.overrideWithValue(
          MediaStoreAttachState(prefs: prefs),
        ),
        mediaStoreAttachedProvider.overrideWith((ref) async => true),
        mediaStoresRepositoryProvider.overrideWithValue(
          _FakeStores({
            'store-a': 'photos @ nas',
            'store-b': 'dive @ minio',
          }, active: 'store-b'),
        ),
        connectedAccountsRepositoryProvider.overrideWithValue(
          _FakeAccounts({}),
        ),
      ]);
      keep(c, attachedStoreHintProvider);
      expect(await c.read(attachedStoreHintProvider.future), 'photos @ nas');
    });

    // Issue #3522: the store reads by a short name, not its endpoint host.
    test('shortens the attached store of a well-known service', () async {
      SharedPreferences.setMockInitialValues({
        MediaStoreAttachState.storeIdKey: 'store-a',
      });
      final prefs = await SharedPreferences.getInstance();
      final c = container([
        sharedPreferencesProvider.overrideWithValue(prefs),
        mediaStoreAttachStateProvider.overrideWithValue(
          MediaStoreAttachState(prefs: prefs),
        ),
        mediaStoreAttachedProvider.overrideWith((ref) async => true),
        mediaStoresRepositoryProvider.overrideWithValue(
          _FakeStores({'store-a': 'submersion-sync @ $_r2Host'}),
        ),
        connectedAccountsRepositoryProvider.overrideWithValue(
          _FakeAccounts({}),
        ),
      ]);
      keep(c, attachedStoreHintProvider);
      expect(
        await c.read(attachedStoreHintProvider.future),
        'submersion-sync @ Cloudflare R2',
      );
    });

    test('names the attached store by its account\'s nickname', () async {
      SharedPreferences.setMockInitialValues({
        MediaStoreAttachState.storeIdKey: 'store-a',
        MediaStoreAttachState.accountIdKey: 'acct-r2',
      });
      final prefs = await SharedPreferences.getInstance();
      final c = container([
        sharedPreferencesProvider.overrideWithValue(prefs),
        mediaStoreAttachStateProvider.overrideWithValue(
          MediaStoreAttachState(prefs: prefs),
        ),
        mediaStoreAttachedProvider.overrideWith((ref) async => true),
        mediaStoresRepositoryProvider.overrideWithValue(
          _FakeStores({'store-a': 'submersion-sync @ $_r2Host'}),
        ),
        connectedAccountsRepositoryProvider.overrideWithValue(
          _FakeAccounts(
            {'acct-r2': 'submersion-sync @ $_r2Host'},
            nicknames: {'acct-r2': 'Dive photos'},
          ),
        ),
      ]);
      keep(c, attachedStoreHintProvider);
      expect(await c.read(attachedStoreHintProvider.future), 'Dive photos');
    });

    test('reads as checking while the store state loads', () {
      final c = container([
        mediaStoreAttachedHereProvider.overrideWithValue(null),
        attachedStoreHintProvider.overrideWith((ref) async => null),
      ]);
      expect(c.read(photosRowStatusProvider).kind, DataRowStatusKind.checking);
    });

    test('a failed refresh keeps the last attach state', () {
      // Riverpod keeps the previous value on a refresh error, and the strip
      // reads it; the row must read the same snapshot.
      expect(attachedHereOf(_inputs(attached: true), hasError: true), isTrue);
      expect(attachedHereOf(null, hasError: true), isFalse);
      expect(attachedHereOf(null, hasError: false), isNull);
    });
  });

  group('libraries row', () {
    test('dates the libraries by the stalest sync', () {
      final old = DateTime(2026, 9, 1);
      expect(summarizeLibrarySyncs([when, old]), (count: 2, lastSync: old));
      expect(summarizeLibrarySyncs([when, null]), (count: 2, lastSync: null));
      expect(summarizeLibrarySyncs(const []), (count: 0, lastSync: null));
    });

    test('a failed refresh keeps the last library list', () {
      final kept = [when];
      expect(librariesOrNull(kept, hasError: true), kept);
      expect(librariesOrNull<DateTime>(null, hasError: true), isEmpty);
      expect(librariesOrNull<DateTime>(null, hasError: false), isNull);
    });

    test('reads as checking until the library health has loaded', () {
      final c = container([
        sharedLibrarySummaryProvider.overrideWithValue((
          count: 2,
          lastSync: when,
        )),
        libraryHealthSettledProvider.overrideWithValue(false),
      ]);
      expect(
        c.read(librariesRowStatusProvider).kind,
        DataRowStatusKind.checking,
      );
    });

    test('reads as checking while the library list loads', () {
      final c = container([
        sharedLibrarySummaryProvider.overrideWithValue(null),
        libraryHealthSettledProvider.overrideWithValue(true),
      ]);
      expect(
        c.read(librariesRowStatusProvider).kind,
        DataRowStatusKind.checking,
      );
    });

    test('counts and dates the libraries once both have loaded', () {
      final c = container([
        sharedLibrarySummaryProvider.overrideWithValue((
          count: 2,
          lastSync: when,
        )),
        libraryHealthSettledProvider.overrideWithValue(true),
      ]);
      final s = c.read(librariesRowStatusProvider);
      expect(
        (s.kind, s.count, s.when),
        (DataRowStatusKind.librariesSome, 2, when),
      );
    });
  });

  group('accounts row', () {
    test('lists the roster without waiting for the sign-in check', () async {
      final c = container([
        accountLabelsProvider.overrideWith(
          (ref) async => const ['Google Drive', 'nas.home'],
        ),
        accountSignInsNeededProvider.overrideWithValue(0),
      ]);
      keep(c, accountsRowStatusProvider);
      await c.read(accountLabelsProvider.future);
      final s = c.read(accountsRowStatusProvider);
      expect(
        (s.kind, s.name),
        (DataRowStatusKind.accountsListed, 'Google Drive, nas.home'),
      );
    });

    test('counts sign-ins needed', () async {
      final c = container([
        accountLabelsProvider.overrideWith((ref) async => const ['a', 'b']),
        accountSignInsNeededProvider.overrideWithValue(1),
      ]);
      keep(c, accountsRowStatusProvider);
      await c.read(accountLabelsProvider.future);
      final s = c.read(accountsRowStatusProvider);
      expect((s.kind, s.count), (DataRowStatusKind.accountsNeedSignIn, 1));
    });

    test('labels come from the roster', () async {
      final c = container([
        connectedAccountsRepositoryProvider.overrideWithValue(
          _FakeAccounts({'a': 'Google Drive', 'b': 'nas.home'}),
        ),
      ]);
      keep(c, accountLabelsProvider);
      expect(await c.read(accountLabelsProvider.future), [
        'Google Drive',
        'nas.home',
      ]);
    });

    // Issue #3522: the roster reads by short names, not endpoint hosts.
    test('labels read by nickname or short name', () async {
      final c = container([
        connectedAccountsRepositoryProvider.overrideWithValue(
          _FakeAccounts(
            {'a': 'submersion-sync @ $_r2Host', 'b': 'photos @ $_r2Host'},
            nicknames: {'b': 'Dive photos'},
          ),
        ),
      ]);
      keep(c, accountLabelsProvider);
      expect(await c.read(accountLabelsProvider.future), [
        'submersion-sync @ Cloudflare R2',
        'Dive photos',
      ]);
    });

    // A dismissed prompt hides the card entry, not the need to sign in.
    test('counts every sign-in needed, dismissed prompts included', () async {
      final c = container([
        pendingSetupItemsProvider.overrideWith(
          (ref) async => [
            _signIn('account_1'),
            _signIn('account_2', dismissed: true),
            const PendingSetupItem(
              kind: SetupItemKind.mediaStoreAttach,
              key: 'store_1',
              label: 'photos @ nas',
              route: '/settings/media-storage',
            ),
          ],
        ),
      ]);
      keep(c, accountSignInsNeededProvider);
      await c.read(pendingSetupItemsProvider.future);
      expect(c.read(accountSignInsNeededProvider), 2);
    });

    test('reads as checking while the roster loads', () {
      final c = container([
        accountLabelsProvider.overrideWith(
          (ref) => Completer<List<String>>().future,
        ),
        accountSignInsNeededProvider.overrideWithValue(0),
      ]);
      expect(
        c.read(accountsRowStatusProvider).kind,
        DataRowStatusKind.checking,
      );
    });

    test('a failed roster read says so instead of checking forever', () async {
      final c = container([
        accountLabelsProvider.overrideWith(
          (ref) => Future<List<String>>.error(StateError('db closed')),
        ),
        accountSignInsNeededProvider.overrideWithValue(0),
      ]);
      keep(c, accountsRowStatusProvider);
      await expectLater(
        c.read(accountLabelsProvider.future),
        throwsA(isA<StateError>()),
      );
      expect(
        c.read(accountsRowStatusProvider).kind,
        DataRowStatusKind.accountsUnavailable,
      );
    });

    test('never probes an account itself', () {
      final source = File(_providersSource).readAsStringSync();
      expect(source, isNot(contains('connectedAccountsWithStatusProvider')));
      expect(source, isNot(contains('.status(')));
    });
  });

  test('a keychain exception in the setup check is not retried', () {
    // Riverpod retries an Exception up to ten times (about 38 s); while it
    // does, every row waiting on the setup items reads "Checking...".
    final retry = pendingSetupItemsProvider.retry;
    expect(retry, isNotNull);
    expect(retry!(0, PlatformException(code: 'keychain')), isNull);
  });

  test('a membership exception does not hold the libraries row', () {
    final retry = libraryHealthInputsProvider.retry;
    expect(retry, isNotNull);
    expect(retry!(0, PlatformException(code: 'keychain')), isNull);
  });

  test('statuses compare by value', () {
    final a = DataRowStatus(
      DataRowStatusKind.syncWithOne,
      when: DateTime(2026),
      name: 'iPad',
    );
    final b = DataRowStatus(
      DataRowStatusKind.syncWithOne,
      when: DateTime(2026),
      name: 'iPad',
    );
    expect(identical(a, b), isFalse);
    expect(a, b);
    expect(
      a,
      isNot(
        DataRowStatus(
          DataRowStatusKind.syncWithOne,
          when: DateTime(2026),
          name: 'iPad',
          offersSetUp: true,
        ),
      ),
    );
  });
}
