// Issue #3482: the row status providers read the same health list as the
// strip plus small overridable leaf inputs, and never build the media runtime.

import 'dart:async';
import 'dart:io';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/accounts/pending_setup_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/settings/presentation/widgets/pending_setup_card.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/domain/data_health/data_row_status.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/providers/data_health_providers.dart';
import 'package:submersion/features/settings/presentation/providers/data_row_status_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';

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

  test('sync row names the single peer', () async {
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

  test('backups row names the sync account', () async {
    final c = container([
      lastBackupTimeProvider.overrideWithValue(when),
      backupCopyInputsProvider.overrideWithValue((
        cloudCopyOn: true,
        customFolder: false,
        cloudCopyMissing: false,
      )),
      syncAccountLabelProvider.overrideWith((ref) async => 'Google Drive'),
    ]);
    keep(c, backupsRowStatusProvider);
    await c.read(syncAccountLabelProvider.future);
    final s = c.read(backupsRowStatusProvider);
    expect(
      (s.kind, s.name, s.when),
      (DataRowStatusKind.backupsCloud, 'Google Drive', when),
    );
  });

  test('photos row never builds the media runtime', () async {
    var built = false;
    final c = container([
      mediaStoreRuntimeProvider.overrideWith((ref) {
        built = true;
        return Future.value(null);
      }),
      attachedStoreHintProvider.overrideWith((ref) async => null),
      mediaStoreAttachedHereProvider.overrideWithValue(false),
    ]);
    final s = c.read(photosRowStatusProvider);
    expect((s.kind, s.offersSetUp), (DataRowStatusKind.photosOff, true));
    expect(built, isFalse);
    // The hint provider's own source must not reach for the runtime either.
    final source = File(
      'lib/features/settings/presentation/providers/data_row_status_providers.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('mediaStoreRuntimeProvider')));
    expect(source, isNot(contains('mediaStoreStatusHintProvider')));
  });

  test('photos row names the attached store', () async {
    final c = container(
      [
        attachedStoreHintProvider.overrideWith((ref) async => 'dive @ minio'),
        mediaStoreAttachedHereProvider.overrideWithValue(true),
      ],
      health: [
        for (final h in _healthy)
          h.feature == DataFeature.media
              ? const FeatureHealth(
                  feature: DataFeature.media,
                  level: HealthLevel.healthy,
                  reason: HealthReason.ok,
                )
              : h,
      ],
    );
    keep(c, photosRowStatusProvider);
    await c.read(attachedStoreHintProvider.future);
    final s = c.read(photosRowStatusProvider);
    expect((s.kind, s.name), (DataRowStatusKind.photosOn, 'dive @ minio'));
  });

  test('libraries row counts and dates the libraries', () {
    final c = container([
      sharedLibrarySummaryProvider.overrideWithValue((
        count: 2,
        lastSync: when,
      )),
    ]);
    final s = c.read(librariesRowStatusProvider);
    expect(
      (s.kind, s.count, s.when),
      (DataRowStatusKind.librariesSome, 2, when),
    );
  });

  test('accounts row counts sign-ins needed', () async {
    final c = container([
      accountsSummaryProvider.overrideWith(
        (ref) async =>
            (labels: const ['Google Drive', 'nas.home'], needSignIn: 1),
      ),
    ]);
    keep(c, accountsRowStatusProvider);
    await c.read(accountsSummaryProvider.future);
    final s = c.read(accountsRowStatusProvider);
    expect((s.kind, s.count), (DataRowStatusKind.accountsNeedSignIn, 1));
  });

  test('the accounts summary never probes an account', () {
    // Status probes read the keychain and can refresh a Google token over
    // the network; the Data page must not run them on every visit.
    final source = File(
      'lib/features/settings/presentation/providers/data_row_status_providers.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('connectedAccountsWithStatusProvider')));
    expect(source, isNot(contains('.status(')));
  });

  test('unloaded async inputs count as absent, not as an error', () {
    final c = container([
      syncAccountLabelProvider.overrideWith(
        (ref) => Completer<String?>().future,
      ),
      attachedStoreHintProvider.overrideWith(
        (ref) => Completer<String?>().future,
      ),
      accountsSummaryProvider.overrideWith(
        (ref) => Completer<({List<String> labels, int needSignIn})>().future,
      ),
      backupCopyInputsProvider.overrideWithValue((
        cloudCopyOn: true,
        customFolder: false,
        cloudCopyMissing: false,
      )),
      lastBackupTimeProvider.overrideWithValue(when),
    ]);
    expect(
      c.read(backupsRowStatusProvider).kind,
      DataRowStatusKind.backupsCloud,
    );
    expect(c.read(backupsRowStatusProvider).name, '');
    // Not "None yet" for a diver who has accounts: the roster has not
    // arrived, so the row says it is still checking.
    expect(c.read(accountsRowStatusProvider).kind, DataRowStatusKind.checking);
  });

  test('libraries read as checking while they load, not as none joined', () {
    final c = container([sharedLibrarySummaryProvider.overrideWithValue(null)]);
    expect(c.read(librariesRowStatusProvider).kind, DataRowStatusKind.checking);
  });

  test('photos read as checking while the store state loads', () {
    // Not "Copies are not kept" with a Set up button for a diver who has a
    // store: the attach state has not arrived yet.
    final c = container([
      mediaStoreAttachedHereProvider.overrideWithValue(null),
      attachedStoreHintProvider.overrideWith((ref) async => null),
    ]);
    expect(c.read(photosRowStatusProvider).kind, DataRowStatusKind.checking);
  });

  test('a failed library list does not read as checking forever', () {
    final c = container([
      sharedLibrariesProvider.overrideWith(
        (ref) => Stream<List<SharedLibrary>>.error(StateError('boom')),
      ),
    ]);
    keep(c, librariesRowStatusProvider);
    return Future<void>.delayed(Duration.zero, () {
      expect(
        c.read(librariesRowStatusProvider).kind,
        isNot(DataRowStatusKind.checking),
      );
    });
  });

  test('a failed sign-in check still lists the accounts', () async {
    final c = container([
      pendingSetupItemsProvider.overrideWith(
        (ref) => Future<List<PendingSetupItem>>.error(StateError('keychain')),
      ),
      connectedAccountsRepositoryProvider.overrideWithValue(
        _FakeAccounts(['Google Drive']),
      ),
    ]);
    keep(c, accountsRowStatusProvider);
    await c.read(accountsSummaryProvider.future);
    final s = c.read(accountsRowStatusProvider);
    expect(
      (s.kind, s.name),
      (DataRowStatusKind.accountsListed, 'Google Drive'),
    );
  });
}

class _FakeAccounts extends Fake implements ConnectedAccountsRepository {
  _FakeAccounts(this.labels);
  final List<String> labels;

  @override
  Stream<void> watchAccountsChanges() => const Stream.empty();

  @override
  Future<List<ConnectedAccount>> getAll() async => [
    for (final (i, label) in labels.indexed)
      ConnectedAccount(
        id: 'a$i',
        kind: AccountKind.googledrive,
        label: label,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
  ];
}
