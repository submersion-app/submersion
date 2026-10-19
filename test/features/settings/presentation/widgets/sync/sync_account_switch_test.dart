// Issue #3482 phase 2: sync picks its account through the account sheet; the
// "Switch sync backend?" explanation shows inside the sheet, and choosing the
// account sync already uses changes nothing.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_location.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/s3_storage_provider.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/sync_account_switch.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../../support/fake_keychain_storage.dart';

/// Holds a [SyncState] and counts recorded departures; everything else the
/// switch never calls.
class _Notifier extends StateNotifier<SyncState> implements SyncNotifier {
  _Notifier(super.state);
  int departures = 0;

  @override
  Future<void> recordBackendDeparture({
    required CloudStorageProvider oldProvider,
    required String toProviderId,
    String? toProviderName,
  }) async => departures++;

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

  Future<(BuildContext, WidgetRef)> pumpHost(
    WidgetTester tester, {
    DateTime? lastSync,
    InMemoryKeychain? keychain,
    SyncRepository? repository,
  }) async {
    final keys = keychain ?? InMemoryKeychain();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    notifier = _Notifier(SyncState(lastSync: lastSync));
    late BuildContext context;
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncStateProvider.overrideWith((ref) => notifier),
          cloudStorageProviderProvider.overrideWithValue(
            FakeCloudStorageProvider(),
          ),
          accountCredentialsStoreProvider.overrideWithValue(
            AccountCredentialsStore(storage: keys),
          ),
          s3StorageProviderInstanceProvider.overrideWithValue(
            S3StorageProvider(store: S3CredentialsStore(storage: keys)),
          ),
          if (repository != null)
            syncRepositoryProvider.overrideWithValue(repository),
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
    await useAccountForSync(context, ref, dropbox, current: dropbox);
    expect(notifier.departures, 0);
    expect(ref.read(selectedCloudProviderTypeProvider), isNull);
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

  test('the account sync uses is the one whose usage says so', () {
    expect(currentSyncGroup([drive, dropbox])!.key, dropbox.key);
    expect(currentSyncGroup([drive]), isNull);
  });
}
