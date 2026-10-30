// Issue #3482 phase 3: the Backups page leads with what is true (the status
// line), then how backups run, where the copy goes, and the two actions;
// History and the Advanced section follow (spec section 8.2).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_group_service.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_location.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/backup/presentation/pages/backup_settings_page.dart';
import 'package:submersion/features/backup/presentation/providers/backup_copy_providers.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/backup/presentation/providers/quarantined_database_providers.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_cloud_storage_provider.dart';
import '../../../../helpers/mock_file_picker_platform.dart';

final _t = DateTime.utc(2026);

ConnectedAccount _row(
  String id,
  AccountKind kind,
  String label, {
  AccountLocation? location,
}) => ConnectedAccount(
  id: id,
  kind: kind,
  label: label,
  createdAt: _t,
  updatedAt: _t,
  location: location,
);

/// Google Drive (sync uses it), Dropbox, and a server with only a club's
/// library folder on it.
final _groups = groupAccounts(
  rows: [
    _row('gd-row', AccountKind.googledrive, 'Google Drive'),
    _row('db-row', AccountKind.dropbox, 'Dropbox'),
    _row(
      's3-lib',
      AccountKind.s3,
      'dives @ minio.home',
      location: const S3AccountLocation(
        displayHost: 'minio.home',
        endpoint: 'https://minio.home',
        bucket: 'dives',
        region: 'us-east-1',
        prefix: 'submersion-sites/club/',
        pathStyle: true,
      ),
    ),
  ],
  statusById: const {
    'gd-row': AccountStatus.signedIn,
    'db-row': AccountStatus.signedIn,
    's3-lib': AccountStatus.signedIn,
  },
  localLocationById: const {},
  usagesOf: (a) => a.id == 'gd-row'
      ? const [AccountUsage(AccountUsageKind.databaseSync)]
      : const [],
);

AccountGroup _group(String rowId) => _groups.holding(rowId)!;

class _FakeAdapter implements BackupDatabaseAdapter {
  @override
  Future<void> backup(String destinationPath, {String? note}) async {}

  @override
  Future<void> restore(
    String backupPath, {
    void Function(int, int)? onMigrationProgress,
  }) async {}

  @override
  Future<String> get databasePath async => '/fake/db/path';

  @override
  AppDatabase get database => throw UnimplementedError();

  @override
  String? get databaseKeyHex => null;
}

/// Creates the sync-role row on a server, as [AccountGroupService.ensureRole]
/// does, without a keychain.
class _FakeGroupService extends Fake implements AccountGroupService {
  final ensured = <(String, AccountRole)>[];

  /// Thrown from [ensureRole] when set.
  Object? failure;

  @override
  Future<ConnectedAccount> ensureRole(
    AccountGroup group,
    AccountRole role, {
    String? libraryFolder,
  }) async {
    ensured.add((group.key, role));
    if (failure case final f?) throw f;
    return _row('s3-sync', AccountKind.s3, 'dives @ minio.home');
  }
}

void main() {
  late SharedPreferences prefs;
  late BackupPreferences backupPrefs;
  late _FakeGroupService groupService;
  late MockFilePickerPlatform mockPicker;
  late FilePickerPlatform originalPicker;

  setUp(() {
    originalPicker = FilePickerPlatform.instance;
    mockPicker = MockFilePickerPlatform();
    FilePickerPlatform.instance = mockPicker;
    groupService = _FakeGroupService();
  });
  tearDown(() => FilePickerPlatform.instance = originalPicker);

  Future<void> pumpPage(
    WidgetTester tester, {
    Map<String, Object> initialPrefs = const {},
    BackupCopyTarget? target,
    List<BackupRecord> history = const [],
    Object? historyError,
    Object? targetError,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues(initialPrefs);
    prefs = await SharedPreferences.getInstance();
    backupPrefs = BackupPreferences(prefs);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localeProvider.overrideWithValue('en'),
          sharedPreferencesProvider.overrideWithValue(prefs),
          backupServiceProvider.overrideWithValue(
            BackupService(dbAdapter: _FakeAdapter(), preferences: backupPrefs),
          ),
          cloudStorageProviderProvider.overrideWithValue(
            FakeCloudStorageProvider(),
          ),
          backupHistoryProvider.overrideWith(
            (ref) async => historyError == null ? history : throw historyError,
          ),
          quarantinedDatabasesProvider.overrideWith((ref) async => const []),
          accountGroupsProvider.overrideWith((ref) async => _groups),
          offerableAccountKindsProvider.overrideWithValue(const []),
          accountGroupServiceProvider.overrideWithValue(groupService),
          if (target != null || targetError != null)
            backupCopyTargetProvider.overrideWith(
              (ref) async => targetError == null ? target! : throw targetError,
            ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BackupSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double y(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

  testWidgets('status, schedule, copy, actions, history, then Advanced', (
    tester,
  ) async {
    await pumpPage(tester);

    final order = [
      find.text('Not backed up yet'),
      find.text('Back up automatically'),
      find.text('No copy off this device'),
      find.text('Back up now'),
      find.text('Restore from a file'),
      find.text('History'),
      find.text('Advanced'),
      find.textContaining('Keep the last'),
      find.text('Backup folder on this device'),
      find.text('Save a backup file'),
      find.text('Password protection'),
    ];
    for (final f in order) {
      expect(f, findsOneWidget, reason: '$f');
    }
    final ys = [for (final f in order) y(tester, f)];
    expect(ys, [...ys]..sort());
  });

  group('the status line and History', () {
    testWidgets('a failed automatic backup reads as failed', (tester) async {
      await pumpPage(
        tester,
        initialPrefs: {
          'backup_enabled': true,
          'backup_last_time': DateTime(2026, 10, 1).millisecondsSinceEpoch,
          'backup_last_scheduled_failure_at': DateTime(
            2026,
            10,
            2,
          ).millisecondsSinceEpoch,
          'backup_last_scheduled_failure_message': 'disk full',
        },
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('backup-status-line')),
          matching: find.byIcon(Icons.error_outline),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a backup with a cloud copy names where it went', (
      tester,
    ) async {
      await pumpPage(
        tester,
        initialPrefs: {
          'backup_last_time': DateTime.now().millisecondsSinceEpoch,
          'backup_last_destination': 'cloud',
        },
      );
      expect(find.textContaining('copy in the cloud'), findsOneWidget);
    });

    testWidgets('no backups yet says so under History', (tester) async {
      await pumpPage(tester);
      expect(find.text('No backups yet'), findsOneWidget);
    });

    testWidgets('a history that cannot be read says why', (tester) async {
      await pumpPage(tester, historyError: StateError('prefs gone'));
      expect(find.textContaining('prefs gone'), findsOneWidget);
    });

    testWidgets('accounts that cannot be read say so on Copy to', (
      tester,
    ) async {
      await pumpPage(tester, targetError: StateError('keychain'));
      expect(find.text('Could not load accounts'), findsOneWidget);
    });
  });

  group('the Copy to row', () {
    testWidgets('following sync names the account and says so', (tester) async {
      await pumpPage(tester, target: CopyFollowsSync(_group('gd-row')));
      expect(find.text('Copy to Google Drive'), findsOneWidget);
      expect(find.text('Same account as sync'), findsOneWidget);
      expect(find.text('Change'), findsWidgets);
    });

    testWidgets('a chosen account names it', (tester) async {
      final g = _group('db-row');
      await pumpPage(tester, target: CopyToAccount(g, g.rows.single));
      expect(find.text('Copy to Dropbox'), findsOneWidget);
      expect(find.text('Same account as sync'), findsNothing);
    });

    testWidgets('a removed account says so and offers a choice', (
      tester,
    ) async {
      await pumpPage(tester, target: const CopyAccountGone('gone'));
      expect(find.text("The copy's account was removed"), findsOneWidget);
      expect(find.text('Choose an account'), findsOneWidget);
    });

    testWidgets('no copy offers a choice', (tester) async {
      await pumpPage(tester, target: const NoCopy());
      expect(find.text('No copy off this device'), findsOneWidget);
      expect(find.text('Choose an account'), findsOneWidget);
    });

    testWidgets('following sync with no sync account reads as no copy', (
      tester,
    ) async {
      await pumpPage(tester, target: const CopyFollowsSync(null));
      expect(find.text('No copy off this device'), findsOneWidget);
      expect(find.text('Choose an account'), findsOneWidget);
    });
  });

  group('choosing where the copy goes', () {
    Future<void> openSheet(WidgetTester tester, String action) async {
      await tester.tap(find.byKey(const Key('backup-copy-change')));
      await tester.pumpAndSettle();
      expect(find.text('Your accounts'), findsOneWidget, reason: action);
    }

    Finder inSheet(String text) => find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(text),
    );

    testWidgets('No copy turns the copy off', (tester) async {
      await pumpPage(tester, initialPrefs: {'backup_cloud_enabled': true});
      await openSheet(tester, 'Change');

      await tester.tap(inSheet('No copy off this device'));
      await tester.pumpAndSettle();

      expect(backupPrefs.getSettings().cloudBackupEnabled, isFalse);
      expect(find.text('No copy off this device'), findsOneWidget);
    });

    testWidgets('the account sync uses makes the copy follow sync', (
      tester,
    ) async {
      await pumpPage(
        tester,
        initialPrefs: {
          'backup_cloud_enabled': true,
          'backup_copy_account_id': 'db-row',
          'backup_copy_account_kind': 'dropbox',
        },
      );
      await openSheet(tester, 'Change');

      await tester.tap(inSheet('Google Drive'));
      await tester.pumpAndSettle();

      final s = backupPrefs.getSettings();
      expect(s.cloudBackupEnabled, isTrue);
      expect(s.copyAccountId, isNull);
      expect(find.text('Same account as sync'), findsOneWidget);
    });

    testWidgets('another account pins its row and turns the copy on', (
      tester,
    ) async {
      await pumpPage(tester);
      await openSheet(tester, 'Choose an account');

      await tester.tap(inSheet('Dropbox'));
      await tester.pumpAndSettle();

      final s = backupPrefs.getSettings();
      expect(s.cloudBackupEnabled, isTrue);
      expect(s.copyAccountId, 'db-row');
      expect(s.copyAccountKind, AccountKind.dropbox);
      expect(find.text('Copy to Dropbox'), findsOneWidget);
    });

    testWidgets('a server with no sync folder row gets one, then is pinned', (
      tester,
    ) async {
      await pumpPage(tester);
      await openSheet(tester, 'Choose an account');

      await tester.tap(inSheet('dives @ minio.home'));
      await tester.pumpAndSettle();

      expect(groupService.ensured, [(_group('s3-lib').key, AccountRole.sync)]);
      final s = backupPrefs.getSettings();
      expect(s.copyAccountId, 's3-sync');
      expect(s.copyAccountKind, AccountKind.s3);
    });

    testWidgets('a failure making the sync folder row says so', (tester) async {
      await pumpPage(tester);
      groupService.failure = Exception('keychain locked');
      await openSheet(tester, 'Choose an account');

      await tester.tap(inSheet('dives @ minio.home'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in to dives @ minio.home'), findsOneWidget);
      expect(backupPrefs.getSettings().cloudBackupEnabled, isFalse);
    });

    testWidgets('backing out changes nothing', (tester) async {
      await pumpPage(tester, initialPrefs: {'backup_cloud_enabled': true});
      await openSheet(tester, 'Change');

      await tester.tapAt(const Offset(600, 20));
      await tester.pumpAndSettle();

      expect(backupPrefs.getSettings().cloudBackupEnabled, isTrue);
      expect(backupPrefs.getSettings().copyAccountId, isNull);
    });
  });

  group('Back up automatically', () {
    testWidgets('the frequency shows in the subtitle and opens a picker', (
      tester,
    ) async {
      await pumpPage(tester, initialPrefs: {'backup_enabled': true});
      expect(find.text('Weekly'), findsOneWidget);

      await tester.tap(find.text('Weekly'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Daily'));
      await tester.pumpAndSettle();

      expect(backupPrefs.getSettings().frequency, BackupFrequency.daily);
      expect(find.text('Daily'), findsOneWidget);
    });

    testWidgets('a screen reader hears the frequency itself', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester, initialPrefs: {'backup_enabled': true});

      expect(find.bySemanticsLabel(RegExp('Weekly')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('off hides the frequency', (tester) async {
      await pumpPage(tester);
      expect(find.text('Weekly'), findsNothing);
    });
  });

  group('Advanced', () {
    testWidgets('Keep the last shows whatever the schedule, and picks', (
      tester,
    ) async {
      await pumpPage(tester);
      expect(find.text('Keep the last 10 backups'), findsOneWidget);

      await tester.tap(find.text('Keep the last 10 backups'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();

      expect(backupPrefs.getSettings().retentionCount, 20);
      expect(find.text('Keep the last 20 backups'), findsOneWidget);
    });

    testWidgets('Keep the last shows what the retained backups cost', (
      tester,
    ) async {
      BackupRecord record(String id, int sizeBytes) => BackupRecord(
        id: id,
        filename: '$id.db',
        timestamp: _t,
        sizeBytes: sizeBytes,
        location: BackupLocation.local,
      );
      await pumpPage(
        tester,
        history: [record('a', 1024 * 1024), record('b', 2 * 1024 * 1024)],
      );

      expect(find.text('2 backups currently use 3.0 MB'), findsOneWidget);
    });

    testWidgets('no footprint while there are no backups', (tester) async {
      await pumpPage(tester);
      expect(
        find.byKey(const ValueKey('backup_retention_footprint')),
        findsNothing,
      );
    });

    testWidgets('Use default shows only with a folder chosen', (tester) async {
      await pumpPage(tester);
      expect(find.text('Use default'), findsNothing);
      expect(find.text('Default location'), findsOneWidget);
    });

    testWidgets('Use default clears the folder and keeps the copy', (
      tester,
    ) async {
      await pumpPage(
        tester,
        initialPrefs: {
          'backup_location': '/custom/dir',
          'backup_cloud_enabled': true,
        },
      );
      expect(find.text('/custom/dir'), findsOneWidget);

      await tester.tap(find.text('Use default'));
      await tester.pumpAndSettle();

      expect(backupPrefs.getSettings().backupLocation, isNull);
      expect(backupPrefs.getSettings().cloudBackupEnabled, isTrue);
      expect(find.text('Default location'), findsOneWidget);
    });

    testWidgets('choosing a folder keeps the cloud copy on', (tester) async {
      // On Apple hosts the picker mints a security-scoped bookmark through
      // this channel; answer it so the pick completes.
      const bookmarks = MethodChannel('app.submersion/backup_bookmark');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        bookmarks,
        (call) async => call.method == 'createBookmark'
            ? Uint8List.fromList([1, 2, 3])
            : null,
      );
      addTearDown(() => messenger.setMockMethodCallHandler(bookmarks, null));
      await pumpPage(tester, initialPrefs: {'backup_cloud_enabled': true});
      mockPicker.directoryPathResult = '/custom/dir';

      await tester.tap(find.byKey(const Key('backup-folder-change')));
      await tester.pumpAndSettle();

      expect(backupPrefs.getSettings().backupLocation, '/custom/dir');
      expect(backupPrefs.getSettings().cloudBackupEnabled, isTrue);
      expect(find.text('/custom/dir'), findsOneWidget);
    });
  });
}
