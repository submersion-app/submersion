// Issue #3503: the "count backups from all devices" switch, its confirmation,
// and lowering "Keep" while it is on.

import 'dart:async';
import 'dart:convert';
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
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_attribution.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
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

/// Holds every listing until [release] is called.
class _GatedCloud extends FakeCloudStorageProvider {
  final gate = Completer<void>();

  void release() => gate.complete();

  @override
  Future<List<CloudFileInfo>> listFiles({
    String? folderId,
    String? namePattern,
  }) async {
    await gate.future;
    return super.listFiles(folderId: folderId, namePattern: namePattern);
  }
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

  testWidgets('the switch is disabled while turning it on is in flight', (
    tester,
  ) async {
    final gated = _GatedCloud();
    cloud = gated;
    await pump(tester);
    await tester.tap(switchTile);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(switchTile).onChanged, isNull);

    expect(
      tester
          .widget<ListTile>(
            find.widgetWithText(ListTile, 'Keep the last 5 backups'),
          )
          .enabled,
      isFalse,
    );

    gated.release();
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(switchTile).onChanged, isNotNull);
    expect(isOn(tester), isTrue);
  });

  testWidgets('leaving the page while it runs does not throw', (tester) async {
    final gated = _GatedCloud();
    cloud = gated;
    await pump(tester);
    await tester.tap(switchTile);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());

    gated.release();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('one backup in the folder reads in the singular', (tester) async {
    seed(3);
    await pump(
      tester,
      initial: {'backup_retention_all_devices_account': 'acct'},
    );
    expect(find.text('1 backup in the cloud folder uses 3 B'), findsOneWidget);
  });

  testWidgets('the folder footprint leaves out copies in another account', (
    tester,
  ) async {
    seed(3);
    final elsewhere = BackupRecord(
      id: 'elsewhere',
      filename: 'submersion_backup_2026-01-01_090000.db',
      timestamp: DateTime(2026),
      sizeBytes: 500,
      location: BackupLocation.cloud,
      cloudFileId: 'gone',
      cloudAccountId: 'other',
    );
    await pump(
      tester,
      initial: {
        'backup_retention_all_devices_account': 'acct',
        'backup_history': jsonEncode([elsewhere.toJson()]),
      },
    );
    expect(find.text('1 backup in the cloud folder uses 3 B'), findsOneWidget);
  });

  testWidgets('a second change while one runs starts nothing', (tester) async {
    for (var d = 2; d <= 8; d++) {
      seed(d);
    }
    final gated = _GatedCloud();
    final seeded = cloud;
    for (final f in await seeded.listFiles()) {
      gated.seedFile(f.name, seeded.bytesOf(f.name)!, modified: f.modifiedTime);
    }
    cloud = gated;
    await pump(
      tester,
      initial: {
        'backup_retention_count': 10,
        'backup_retention_all_devices_account': 'acct',
      },
    );
    gated.release();
    await tester.pumpAndSettle();
    final gate2 = _GatedCloud();
    for (final f in await gated.listFiles()) {
      gate2.seedFile(f.name, gated.bytesOf(f.name)!, modified: f.modifiedTime);
    }
    cloud = gate2;
    await pump(
      tester,
      initial: {
        'backup_retention_count': 10,
        'backup_retention_all_devices_account': 'acct',
      },
    );
    await tester.tap(find.text('Keep the last 10 backups'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('5').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The first change is still listing: neither control starts another.
    final keep = find.widgetWithText(ListTile, 'Keep the last 10 backups');
    expect(tester.widget<ListTile>(keep).enabled, isFalse);
    expect(tester.widget<SwitchListTile>(switchTile).onChanged, isNull);
    await tester.tap(keep, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SimpleDialog), findsNothing);

    gate2.release();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('with the switch on, the page lists the folder once', (
    tester,
  ) async {
    seed(3);
    await pump(
      tester,
      initial: {'backup_retention_all_devices_account': 'acct'},
    );
    expect(find.text('1 backup in the cloud folder uses 3 B'), findsOneWidget);
    expect(cloud.operationLog.where((o) => o == 'list'), hasLength(1));
  });

  testWidgets('the folder footprint counts only what the folder holds', (
    tester,
  ) async {
    seed(3);
    final goneElsewhere = BackupRecord(
      id: 'gone',
      filename: 'submersion_backup_2026-01-01_090000.db',
      timestamp: DateTime(2026),
      sizeBytes: 500,
      location: BackupLocation.both,
      cloudFileId: 'deleted-by-another-device',
      cloudAccountId: 'acct',
      localPath: '/backups/gone.db',
    );
    await pump(
      tester,
      initial: {
        'backup_retention_all_devices_account': 'acct',
        'backup_history': jsonEncode([goneElsewhere.toJson()]),
      },
    );
    expect(find.text('1 backup in the cloud folder uses 3 B'), findsOneWidget);
  });

  testWidgets('turning it off needs no dialog and deletes nothing', (
    tester,
  ) async {
    final name = seed(3);
    await pump(
      tester,
      initial: {'backup_retention_all_devices_account': 'acct'},
    );
    expect(isOn(tester), isTrue);
    await tester.tap(switchTile);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(savedOn(), isFalse);
    expect(has(name), isTrue);
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
