// Issue #3503: the "count backups from all devices" switch, its confirmation,
// and lowering "Keep" while it is on.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_attribution.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/presentation/providers/backup_copy_providers.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/providers/quarantined_database_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_advanced_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/unused_backup_database_adapter.dart';

class _Device extends SyncRepository {
  @override
  Future<String> getDeviceId() async => 'dev-A';

  @override
  Future<String?> getSyncAccountId() async => 'acct';
}

final _t = DateTime.utc(2026);
final _stamp = DateFormat('yyyy-MM-dd_HHmmss');

final _syncing = groupAccounts(
  rows: [
    ConnectedAccount(
      id: 'acct',
      kind: AccountKind.dropbox,
      label: 'Dropbox',
      createdAt: _t,
      updatedAt: _t,
    ),
  ],
  statusById: const {'acct': AccountStatus.signedIn},
  localLocationById: const {},
  usagesOf: (_) => const [AccountUsage(AccountUsageKind.databaseSync)],
).holding('acct');

void main() {
  late SharedPreferences prefs;
  late FakeCloudStorageProvider cloud;

  /// Seeds a backup [daysAgo] old from another device; returns its name.
  String seed(int daysAgo) {
    final at = DateTime.now().subtract(Duration(days: daysAgo));
    final name =
        'submersion_backup_${_stamp.format(at)}__d${deviceTag('dev-B')}.db';
    cloud.seedFile(name, Uint8List.fromList([1, 2, 3]), modified: at);
    return name;
  }

  Future<void> pump(
    WidgetTester tester, {
    BackupCopyTarget? target,
    Map<String, Object> initial = const {},
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'backup_cloud_enabled': true,
      'backup_retention_count': 5,
      ...initial,
    });
    prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localeProvider.overrideWithValue('en'),
          sharedPreferencesProvider.overrideWithValue(prefs),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          backupServiceProvider.overrideWithValue(
            BackupService(
              dbAdapter: UnusedBackupDatabaseAdapter(),
              preferences: BackupPreferences(prefs),
              cloudProvider: cloud,
              syncRepository: _Device(),
            ),
          ),
          backupCopyTargetProvider.overrideWith(
            (ref) async => target ?? CopyFollowsSync(_syncing),
          ),
          quarantinedDatabasesProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: BackupAdvancedSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final switchTile = find.widgetWithText(
    SwitchListTile,
    'Count backups from all devices',
  );
  bool isOn(WidgetTester tester) =>
      tester.widget<SwitchListTile>(switchTile).value;
  bool savedOn() =>
      BackupPreferences(prefs).getSettings().crossDeviceRetentionFor('acct');
  bool has(String name) => cloud.bytesOf(name) != null;

  setUp(() => cloud = FakeCloudStorageProvider());

  testWidgets('no switch without a cloud copy', (tester) async {
    await pump(tester, target: const NoCopy());
    expect(switchTile, findsNothing);
  });

  testWidgets('the switch is off by default', (tester) async {
    await pump(tester);
    expect(isOn(tester), isFalse);
    expect(
      find.text('Off: this device removes only the backups it made'),
      findsOneWidget,
    );
  });

  testWidgets('nothing to remove: it turns on with no dialog', (tester) async {
    await pump(tester);
    await tester.tap(switchTile);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(savedOn(), isTrue);
    expect(isOn(tester), isTrue);
    expect(find.textContaining('keeps the last 5 backups'), findsOneWidget);
  });

  group('with backups to remove', () {
    late List<String> names;
    setUp(() => names = [for (var d = 2; d <= 8; d++) seed(d)]);

    testWidgets('Cancel leaves it off and deletes nothing', (tester) async {
      await pump(tester);
      await tester.tap(switchTile);
      await tester.pumpAndSettle();
      expect(find.text('Remove 2 backups?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(savedOn(), isFalse);
      expect(names.every(has), isTrue);
    });

    testWidgets('confirming deletes exactly the listed backups', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(switchTile);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove 2 backups'));
      await tester.pumpAndSettle();

      expect(savedOn(), isTrue);
      expect(
        [for (final n in names) has(n)],
        [...List.filled(5, true), false, false],
      );
      expect(
        find.text('Removed 2 backups from the cloud folder'),
        findsOneWidget,
      );
    });

    testWidgets('a failed listing says so and stays off', (tester) async {
      await pump(tester);
      cloud.failLists = true;
      await tester.tap(switchTile);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Could not read the cloud backup folder, so nothing was changed.',
        ),
        findsOneWidget,
      );
      expect(savedOn(), isFalse);
    });

    testWidgets('lowering Keep while on asks first; Cancel keeps it', (
      tester,
    ) async {
      await pump(
        tester,
        initial: {
          'backup_retention_count': 10,
          'backup_retention_all_devices_account': 'acct',
        },
      );
      await tester.tap(find.text('Keep the last 10 backups'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5').last);
      await tester.pumpAndSettle();
      expect(find.text('Remove 2 backups?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(BackupPreferences(prefs).getSettings().retentionCount, 10);
      expect(names.every(has), isTrue);
    });

    testWidgets('lowering Keep while on and confirming saves and prunes', (
      tester,
    ) async {
      await pump(
        tester,
        initial: {
          'backup_retention_count': 10,
          'backup_retention_all_devices_account': 'acct',
        },
      );
      await tester.tap(find.text('Keep the last 10 backups'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove 2 backups'));
      await tester.pumpAndSettle();
      expect(BackupPreferences(prefs).getSettings().retentionCount, 5);
      expect(has(names.last), isFalse);
    });

    testWidgets('raising Keep needs no dialog', (tester) async {
      await pump(
        tester,
        initial: {'backup_retention_all_devices_account': 'acct'},
      );
      await tester.tap(find.text('Keep the last 5 backups'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('10').last);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(BackupPreferences(prefs).getSettings().retentionCount, 10);
    });

    testWidgets('lowering Keep with the switch off needs no dialog', (
      tester,
    ) async {
      await pump(tester, initial: {'backup_retention_count': 10});
      await tester.tap(find.text('Keep the last 10 backups'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5').last);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(names.every(has), isTrue);
    });

    testWidgets('when on, the footprint describes the cloud folder', (
      tester,
    ) async {
      await pump(
        tester,
        initial: {'backup_retention_all_devices_account': 'acct'},
      );
      expect(
        find.text('7 backups in the cloud folder use 21 B'),
        findsOneWidget,
      );
    });
  });
}
