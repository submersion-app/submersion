// Issue #3482 phase 2: sync picks its account through the account sheet; the
// "Switch sync backend?" explanation shows inside the sheet, and choosing the
// account sync already uses changes nothing.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/sync/sync_initializer.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/sync/sync_account_switch.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/fake_cloud_storage_provider.dart';

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
  }) async {
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

  test('the account sync uses is the one whose usage says so', () {
    expect(currentSyncGroup([drive, dropbox])!.key, dropbox.key);
    expect(currentSyncGroup([drive]), isNull);
  });
}
