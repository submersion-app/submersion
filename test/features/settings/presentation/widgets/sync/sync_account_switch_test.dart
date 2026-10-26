// Issue #3482 phase 2: sync picks its account through the account sheet; the
// "Switch sync backend?" explanation shows inside the sheet, and choosing the
// account sync already uses changes nothing.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateNotifier;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_location.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/git/git_config.dart';
import 'package:submersion/core/services/cloud_storage/git/git_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/git_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/s3_storage_provider.dart';
import 'package:submersion/core/services/sync/established_provider_store.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart';
import 'package:submersion/features/settings/presentation/providers/git_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_sync_actions.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/sync_account_switch.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../../support/fake_keychain_storage.dart';

/// Holds a [SyncState] and counts recorded departures; everything else the
/// switch never calls.
class _Notifier extends StateNotifier<SyncState> implements SyncNotifier {
  _Notifier(super.state);
  int departures = 0;
  String? lastTo;

  @override
  Future<void> recordBackendDeparture({
    required CloudStorageProvider oldProvider,
    required String toProviderId,
    String? toProviderName,
  }) async {
    departures++;
    lastTo = toProviderId;
  }

  @override
  Future<void> refreshState() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records each sync account write, with what it saw when it ran.
class _RecordingRepository extends SyncRepository {
  _RecordingRepository(this.onSet);
  final void Function(String accountId, CloudProviderType type) onSet;

  @override
  Future<void> setSyncAccount({
    required String accountId,
    required CloudProviderType providerType,
  }) async => onSet(accountId, providerType);

  final retired = <String>[];

  @override
  Future<void> retireCursor(String providerId) async => retired.add(providerId);
}

/// Counts sign-ins, so a test can tell a save from a re-authentication.
class _CountingProvider extends FakeCloudStorageProvider {
  int authenticateCalls = 0;

  @override
  Future<void> authenticate() async {
    authenticateCalls++;
    await super.authenticate();
  }
}

final _t = DateTime.utc(2026);

AccountGroup _group(
  String id,
  AccountKind kind,
  String label, {
  bool sync = false,
}) => groupAccounts(
  rows: [
    ConnectedAccount(
      id: id,
      kind: kind,
      label: label,
      createdAt: _t,
      updatedAt: _t,
    ),
  ],
  statusById: {id: AccountStatus.signedIn},
  localLocationById: const {},
  usagesOf: (_) => [
    if (sync) const AccountUsage(AccountUsageKind.databaseSync),
  ],
).single;

void main() {
  final drive = _group('gd', AccountKind.googledrive, 'Google Drive');
  final dropbox = _group('db', AccountKind.dropbox, 'Dropbox', sync: true);

  late _Notifier notifier;
  late SharedPreferences sharedPrefs;

  Future<(BuildContext, WidgetRef)> pumpHost(
    WidgetTester tester, {
    DateTime? lastSync,
    InMemoryKeychain? keychain,
    SyncRepository? repository,
    FakeCloudStorageProvider? cloudProvider,
    List<AccountGroup>? groups,
    List<Override> extra = const [],
  }) async {
    final keys = keychain ?? InMemoryKeychain();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    sharedPrefs = prefs;
    notifier = _Notifier(SyncState(lastSync: lastSync));
    late BuildContext context;
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          syncStateProvider.overrideWith((ref) => notifier),
          cloudStorageProviderProvider.overrideWithValue(
            cloudProvider ?? FakeCloudStorageProvider(),
          ),
          accountCredentialsStoreProvider.overrideWithValue(
            AccountCredentialsStore(storage: keys),
          ),
          s3StorageProviderInstanceProvider.overrideWithValue(
            S3StorageProvider(store: S3CredentialsStore(storage: keys)),
          ),
          gitStorageProviderInstanceProvider.overrideWithValue(
            GitStorageProvider(store: GitCredentialsStore(storage: keys)),
          ),
          gitCredentialsStoreProvider.overrideWithValue(
            GitCredentialsStore(storage: keys),
          ),
          if (repository != null)
            syncRepositoryProvider.overrideWithValue(repository),
          if (groups != null)
            accountGroupsProvider.overrideWith((ref) async => groups),
          ...extra,
          syncInitializerProvider.overrideWithValue(
            SyncInitializer(syncRepository: SyncRepository(), prefs: prefs),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (c, r, _) {
              context = c;
              ref = r;
              return const Scaffold();
            },
          ),
        ),
      ),
    );
    return (context, ref);
  }

  testWidgets('choosing the account sync uses asks nothing', (tester) async {
    final (context, ref) = await pumpHost(tester, lastSync: _t);
    expect(
      syncSwitchConsequence(context, ref, dropbox, current: dropbox),
      isNull,
    );
  });

  testWidgets('with no sync history a switch asks nothing', (tester) async {
    final (context, ref) = await pumpHost(tester);
    expect(
      syncSwitchConsequence(context, ref, drive, current: dropbox),
      isNull,
    );
  });

  testWidgets('another account after syncing explains the switch first', (
    tester,
  ) async {
    final (context, ref) = await pumpHost(tester, lastSync: _t);
    final text = syncSwitchConsequence(context, ref, drive, current: dropbox);
    expect(text, contains('Dropbox'));
    expect(text, contains('Google Drive'));
  });

  testWidgets('switching records the departure once and asks no second time', (
    tester,
  ) async {
    final (context, ref) = await pumpHost(tester, lastSync: _t);
    await useAccountForSync(context, ref, drive, current: dropbox);
    await tester.pump();

    expect(notifier.departures, 1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      ref.read(selectedCloudProviderTypeProvider),
      CloudProviderType.googledrive,
    );
  });

  testWidgets('choosing the current account changes nothing', (tester) async {
    final (context, ref) = await pumpHost(tester, lastSync: _t);
    ref.read(selectedCloudProviderTypeProvider.notifier).state =
        CloudProviderType.dropbox;
    await useAccountForSync(context, ref, dropbox, current: dropbox);
    expect(notifier.departures, 0);
    expect(
      ref.read(selectedCloudProviderTypeProvider),
      CloudProviderType.dropbox,
    );
  });

  // Review of #3527: a failed or cancelled sign-in leaves "Using: X" with
  // nothing selected; choosing X again selects it, and leaves nothing.
  testWidgets('choosing the current account with sync off selects it again', (
    tester,
  ) async {
    final (context, ref) = await pumpHost(tester, lastSync: _t);
    await useAccountForSync(context, ref, dropbox, current: dropbox);
    await tester.pump();
    expect(notifier.departures, 0);
    expect(
      ref.read(selectedCloudProviderTypeProvider),
      CloudProviderType.dropbox,
    );
  });

  // Review: an own server with no keys here cannot take sync; the old
  // backend must not be marked departed, and nothing may throw.
  testWidgets('an own server not signed in here records no departure', (
    tester,
  ) async {
    final (context, ref) = await pumpHost(tester, lastSync: _t);
    final server = groupAccounts(
      rows: [
        ConnectedAccount(
          id: 's3row',
          kind: AccountKind.s3,
          label: 'dives @ minio',
          createdAt: _t,
          updatedAt: _t,
          location: const S3AccountLocation(
            displayHost: 'minio',
            endpoint: 'https://minio',
            bucket: 'dives',
            region: 'us-east-1',
            prefix: 'submersion-sites/reef/',
            pathStyle: true,
          ),
        ),
      ],
      statusById: const {'s3row': AccountStatus.signedIn},
      localLocationById: const {},
      usagesOf: (_) => const [],
    ).single;

    await useAccountForSync(context, ref, server, current: dropbox);
    await tester.pump();

    expect(notifier.departures, 0);
    expect(tester.takeException(), isNull);
    expect(find.text('Sign in to dives @ minio'), findsOneWidget);
  });

  // Review: the sync account derivation prefers the persisted account of a
  // kind, so moving S3 sync to another folder must persist the new row
  // before S3 is selected, or the old row takes the new settings.
  testWidgets('a switch persists the new row before selecting its kind', (
    tester,
  ) async {
    final keychain = InMemoryKeychain();
    final log = <String>[];
    late WidgetRef hostRef;
    final repository = _RecordingRepository(
      (id, type) => log.add(
        '$id ${type.name} ${hostRef.read(selectedCloudProviderTypeProvider)}',
      ),
    );
    final (context, ref) = await pumpHost(
      tester,
      keychain: keychain,
      repository: repository,
    );
    hostRef = ref;
    final config = S3Config(
      endpoint: 'https://minio.home',
      bucket: 'dives',
      prefix: 'dive-log/',
      accessKeyId: 'AKIA1',
      secretAccessKey: 'shh',
    );
    await AccountCredentialsStore(
      storage: keychain,
    ).write('s3row', jsonEncode(config.toJson()));
    final row = ConnectedAccount(
      id: 's3row',
      kind: AccountKind.s3,
      label: 'dives @ minio.home',
      createdAt: _t,
      updatedAt: _t,
    );

    await switchSyncToRow(context, ref, row);
    await tester.pump();

    expect(log, ['s3row s3 null']);
    expect(ref.read(selectedCloudProviderTypeProvider), CloudProviderType.s3);
  });

  testWidgets('a Git account without keys here records no departure', (
    tester,
  ) async {
    final (context, ref) = await pumpHost(tester, lastSync: _t);
    final git = _group('gitrow', AccountKind.git, 'you/dive-log @ github.com');

    await useAccountForSync(context, ref, git, current: dropbox);
    await tester.pump();

    expect(notifier.departures, 0);
    expect(
      ref.read(selectedCloudProviderTypeProvider),
      isNot(CloudProviderType.git),
    );
  });

  group("Set up's connect", () {
    testWidgets('reports a Git account without keys here as not connected, '
        'though another account is still selected', (tester) async {
      final git = _group(
        'gitrow',
        AccountKind.git,
        'you/dive-log @ github.com',
      );
      final (context, ref) = await pumpHost(
        tester,
        lastSync: _t,
        groups: [dropbox, git],
      );
      ref.read(selectedCloudProviderTypeProvider.notifier).state =
          CloudProviderType.dropbox;

      final connected = await const SetUpSyncActions().connect(
        context,
        ref,
        git,
      );

      expect(connected, SetUpConnect.failed);
    });

    testWidgets('reads which account syncs afresh after the switch, not a '
        'usage snapshot from before it', (tester) async {
      ConnectedAccount row(String id, AccountKind kind, String label) =>
          ConnectedAccount(
            id: id,
            kind: kind,
            label: label,
            createdAt: _t,
            updatedAt: _t,
          );
      var syncId = 'db';
      final (context, ref) = await pumpHost(
        tester,
        extra: [
          connectedAccountsWithStatusProvider.overrideWith(
            (ref) async => [
              (
                row('db', AccountKind.dropbox, 'Dropbox'),
                AccountStatus.signedIn,
              ),
              (
                row('gd', AccountKind.googledrive, 'Google Drive'),
                AccountStatus.signedIn,
              ),
            ],
          ),
          connectedAccountUsageProvider.overrideWith(
            (ref) async => AccountUsageSnapshot(syncAccountId: syncId),
          ),
        ],
      );
      // The page keeps the groups, and with them a usage snapshot, alive.
      ref.listenManual(accountGroupsProvider, (_, _) {});
      final before = await ref.read(accountGroupsProvider.future);
      ref.read(selectedCloudProviderTypeProvider.notifier).state =
          CloudProviderType.dropbox;
      // The switch moves sync; the sync event bus has not said so yet.
      syncId = 'gd';

      final connected = await const SetUpSyncActions().connect(
        context,
        ref,
        before.singleWhere((g) => g.kind == AccountKind.googledrive),
      );

      expect(connected, SetUpConnect.connected);
    });

    testWidgets('reports a device that has synced with that account as in '
        'step', (tester) async {
      final (context, ref) = await pumpHost(
        tester,
        lastSync: _t,
        groups: [dropbox, drive],
      );
      ref.read(selectedCloudProviderTypeProvider.notifier).state =
          CloudProviderType.dropbox;

      final connected = await const SetUpSyncActions().connect(
        context,
        ref,
        dropbox,
      );

      expect(connected, SetUpConnect.inStep);
    });

    testWidgets('reports the account sync already uses as connected', (
      tester,
    ) async {
      final (context, ref) = await pumpHost(tester, groups: [dropbox, drive]);
      ref.read(selectedCloudProviderTypeProvider.notifier).state =
          CloudProviderType.dropbox;

      final connected = await const SetUpSyncActions().connect(
        context,
        ref,
        dropbox,
      );

      expect(connected, SetUpConnect.connected);
    });
  });

  testWidgets('choosing a Git account points sync at it, with its keys', (
    tester,
  ) async {
    final keychain = InMemoryKeychain();
    final log = <String>[];
    final repository = _RecordingRepository(
      (id, type) => log.add('$id ${type.name}'),
    );
    final (context, ref) = await pumpHost(
      tester,
      keychain: keychain,
      repository: repository,
    );
    final config = GitConfig(
      repoUrl: 'https://github.com/you/dive-log',
      username: 'you',
      token: 'ghp_secret',
    );
    await AccountCredentialsStore(
      storage: keychain,
    ).write('gitrow', jsonEncode(config.toJson()));
    final git = groupAccounts(
      rows: [
        ConnectedAccount(
          id: 'gitrow',
          kind: AccountKind.git,
          label: config.displayLabel,
          createdAt: _t,
          updatedAt: _t,
        ),
      ],
      statusById: {'gitrow': AccountStatus.signedIn},
      localLocationById: const {},
      usagesOf: (_) => const [],
    ).single;

    await useAccountForSync(context, ref, git);
    await tester.pump();

    expect(log, ['gitrow git']);
    expect(ref.read(selectedCloudProviderTypeProvider), CloudProviderType.git);
    // Sync reads the Git settings blob, now this account's.
    final synced = await ref
        .read(gitStorageProviderInstanceProvider)
        .loadConfig();
    expect(synced?.repoUrl, 'https://github.com/you/dive-log.git');
  });

  // Review of #3527: saving the sync account's server details (or moving
  // between two accounts of the kind sync uses) signs nothing in again: a
  // probe there used the previous row's cached provider and turned sync off
  // when the old key was revoked.
  testWidgets('a switch on the kind sync uses signs nothing in again', (
    tester,
  ) async {
    final keychain = InMemoryKeychain();
    final log = <String>[];
    final counting = _CountingProvider();
    final (context, ref) = await pumpHost(
      tester,
      keychain: keychain,
      repository: _RecordingRepository((id, type) => log.add(id)),
      cloudProvider: counting,
    );
    ref.read(selectedCloudProviderTypeProvider.notifier).state =
        CloudProviderType.s3;
    await AccountCredentialsStore(storage: keychain).write(
      's3row',
      jsonEncode(
        S3Config(
          endpoint: 'https://minio.home',
          bucket: 'dives',
          prefix: 'dive-log/',
          accessKeyId: 'AKIA2',
          secretAccessKey: 'new',
        ).toJson(),
      ),
    );
    final row = ConnectedAccount(
      id: 's3row',
      kind: AccountKind.s3,
      label: 'dives @ minio.home',
      createdAt: _t,
      updatedAt: _t,
    );

    await switchSyncToRow(context, ref, row);
    await tester.pump();

    expect(log, ['s3row']);
    expect(counting.authenticateCalls, 0);
    expect(ref.read(selectedCloudProviderTypeProvider), CloudProviderType.s3);
  });

  // Review of #3527: after Stop syncing, the folder this device synced to
  // has no usage left; picking the server again returns to it rather than
  // starting an empty default folder.
  testWidgets('picking a server again goes back to the folder last synced', (
    tester,
  ) async {
    final keychain = InMemoryKeychain();
    final log = <String>[];
    final (context, ref) = await pumpHost(
      tester,
      keychain: keychain,
      repository: _RecordingRepository((id, type) => log.add(id)),
    );
    final dives = S3Config(
      endpoint: 'https://minio.home',
      bucket: 'dives',
      prefix: 'dives/',
      accessKeyId: 'AKIA1',
      secretAccessKey: 'shh',
    );
    final divesId = accountIdFor(
      kind: AccountKind.s3,
      naturalKey: s3NaturalKey(dives),
    );
    await AccountCredentialsStore(
      storage: keychain,
    ).write(divesId, jsonEncode(dives.toJson()));
    await S3CredentialsStore(storage: keychain).save(dives);
    final server = groupAccounts(
      rows: [
        ConnectedAccount(
          id: divesId,
          kind: AccountKind.s3,
          label: 'dives @ minio.home',
          createdAt: _t,
          updatedAt: _t,
          location: S3AccountLocation.fromConfig(dives),
        ),
      ],
      statusById: {divesId: AccountStatus.signedIn},
      localLocationById: const {},
      usagesOf: (_) => const [],
    ).single;

    await useAccountForSync(context, ref, server);
    await tester.pump();

    expect(log, [divesId]);
  });

  // Review of #3527: S3 bucket X to S3 bucket Y was keyed 's3' throughout,
  // so Y's first sync skipped the Combine check and reused X's cursor, and
  // devices on X ignored the moved marker.
  testWidgets('another account of the same kind starts as first contact', (
    tester,
  ) async {
    final keychain = InMemoryKeychain();
    final repo = _RecordingRepository((_, _) {});
    final (context, ref) = await pumpHost(
      tester,
      lastSync: _t,
      keychain: keychain,
      repository: repo,
    );
    await EstablishedProviderStore(sharedPrefs).add('s3');
    final y = S3Config(
      endpoint: 'https://other.home',
      bucket: 'logs',
      prefix: 'submersion-sync/',
      accessKeyId: 'AKIA9',
      secretAccessKey: 'y',
    );
    final yId = accountIdFor(kind: AccountKind.s3, naturalKey: s3NaturalKey(y));
    await AccountCredentialsStore(
      storage: keychain,
    ).write(yId, jsonEncode(y.toJson()));
    AccountGroup s3Group(String id, S3AccountLocation location, bool sync) =>
        groupAccounts(
          rows: [
            ConnectedAccount(
              id: id,
              kind: AccountKind.s3,
              label: '${location.bucket} @ ${location.displayHost}',
              createdAt: _t,
              updatedAt: _t,
              location: location,
            ),
          ],
          statusById: {id: AccountStatus.signedIn},
          localLocationById: const {},
          usagesOf: (_) => [
            if (sync) const AccountUsage(AccountUsageKind.databaseSync),
          ],
        ).single;
    final x = s3Group(
      'x',
      S3AccountLocation.fromConfig(y.copyWith(bucket: 'dives')),
      true,
    );
    final yGroup = s3Group(yId, S3AccountLocation.fromConfig(y), false);

    await useAccountForSync(context, ref, yGroup, current: x);
    await tester.pump();

    expect(notifier.lastTo, 's3:$yId');
    expect(repo.retired, ['s3']);
    expect(EstablishedProviderStore(sharedPrefs).contains('s3'), isFalse);
  });

  test('the account sync uses is the one whose usage says so', () {
    expect(currentSyncGroup([drive, dropbox])!.key, dropbox.key);
    expect(currentSyncGroup([drive]), isNull);
  });
}
