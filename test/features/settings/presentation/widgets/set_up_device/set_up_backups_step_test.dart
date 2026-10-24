import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_group_service.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_flow_provider.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_backups_step.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_navigation.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

AccountGroup _group(
  String id,
  AccountKind kind,
  String label, {
  bool syncs = false,
}) => groupAccounts(
  rows: [
    ConnectedAccount(
      id: id,
      kind: kind,
      label: label,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    ),
  ],
  statusById: {id: AccountStatus.signedIn},
  localLocationById: const {},
  usagesOf: (_) =>
      syncs ? const [AccountUsage(AccountUsageKind.databaseSync)] : const [],
).single;

final _drive = _group(
  'gd',
  AccountKind.googledrive,
  'Google Drive',
  syncs: true,
);
final _dropbox = _group('db', AccountKind.dropbox, 'Dropbox');
final _server = _group('s3', AccountKind.s3, 'My bucket');

/// An own server with no keys on this device: its sync row cannot be made.
class _NoKeysService implements AccountGroupService {
  @override
  Future<ConnectedAccount> ensureRole(
    AccountGroup group,
    AccountRole role, {
    String? libraryFolder,
  }) async => throw StateError('no keys');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Step 3, "A backup that survives a lost device" (issue #3482, Part B
/// Task 11).
void main() {
  late List<String> nav;
  late ProviderContainer container;

  BackupSettings settings() => container.read(backupSettingsProvider);

  Future<void> pump(
    WidgetTester tester, {
    AccountGroup? chosen,
    List<AccountGroup>? groups,
    Map<String, Object> prefs = const {},
  }) async {
    nav = [];
    SharedPreferences.setMockInitialValues(prefs);
    final backupPrefs = BackupPreferences(
      await SharedPreferences.getInstance(),
    );
    container = ProviderContainer(
      overrides: [
        backupPreferencesProvider.overrideWithValue(backupPrefs),
        setUpFlowProvider.overrideWith(() => _Flow(chosen)),
        accountGroupsProvider.overrideWith(
          (ref) async => groups ?? [_drive, _dropbox],
        ),
        accountGroupServiceProvider.overrideWithValue(_NoKeysService()),
      ],
    );
    addTearDown(container.dispose);
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SetUpBackupsStep(
              navigation: SetUpStepNavigation(
                onNext: () => nav.add('next'),
                onBack: () => nav.add('back'),
                onNotNow: () => nav.add('notNow'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool switchOn(WidgetTester tester, String title) => tester
      .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title))
      .value;

  testWidgets('both switches start on, with the schedule and the account', (
    tester,
  ) async {
    await pump(tester, chosen: _drive);

    expect(find.textContaining('A backup that survives a lost'), findsOne);
    expect(switchOn(tester, 'Back up automatically'), isTrue);
    expect(find.text('Weekly. The last 10 are kept here.'), findsOneWidget);
    expect(switchOn(tester, 'Also keep a copy in Google Drive'), isTrue);
    expect(find.text('Same account as sync'), findsOneWidget);
  });

  testWidgets('Next with the sync account turns backups on, the copy '
      'following sync, and keeps the schedule', (tester) async {
    await pump(
      tester,
      chosen: _drive,
      prefs: {'backup_frequency': BackupFrequency.monthly.name},
    );
    expect(find.text('Monthly. The last 10 are kept here.'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(settings().enabled, isTrue);
    expect(settings().frequency, BackupFrequency.monthly);
    expect(settings().cloudBackupEnabled, isTrue);
    expect(settings().copyAccountId, isNull);
    expect(nav, ['next']);
  });

  testWidgets('another account pins the copy to it', (tester) async {
    await pump(tester, chosen: _dropbox);
    expect(find.text('Same account as sync'), findsNothing);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(settings().cloudBackupEnabled, isTrue);
    expect(settings().copyAccountId, 'db');
    expect(nav, ['next']);
  });

  testWidgets('a copy that cannot be made changes nothing and stays', (
    tester,
  ) async {
    await pump(tester, chosen: _server, groups: [_drive, _server]);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(settings().enabled, isFalse);
    expect(settings().cloudBackupEnabled, isFalse);
    expect(find.text('Sign in to My bucket'), findsOneWidget);
    expect(nav, isEmpty);
  });

  testWidgets('with the copy off, Next keeps no copy off this device', (
    tester,
  ) async {
    await pump(
      tester,
      chosen: _drive,
      prefs: {
        'backup_cloud_enabled': true,
        'backup_copy_account_id': 'db',
        'backup_copy_account_kind': AccountKind.dropbox.name,
      },
    );

    await tester.tap(find.text('Also keep a copy in Google Drive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(settings().enabled, isTrue);
    expect(settings().cloudBackupEnabled, isFalse);
    expect(settings().copyAccountId, isNull);
  });

  testWidgets('with automatic backups off, Next turns them off', (
    tester,
  ) async {
    await pump(tester, chosen: _drive, prefs: {'backup_enabled': true});

    await tester.tap(find.text('Back up automatically'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(settings().enabled, isFalse);
  });

  testWidgets('Back and Not now write nothing', (tester) async {
    await pump(tester, chosen: _drive);

    await tester.tap(find.text('Back'));
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(settings().enabled, isFalse);
    expect(settings().cloudBackupEnabled, isFalse);
    expect(nav, ['back', 'notNow']);
  });

  testWidgets('with no account, the copy is explained instead', (tester) async {
    await pump(tester, groups: const []);

    expect(find.textContaining('Also keep a copy'), findsNothing);
    expect(
      find.text('A copy off this device needs an account or a backup folder.'),
      findsOneWidget,
    );
    expect(find.text('Open Backups'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(settings().enabled, isTrue);
    expect(settings().cloudBackupEnabled, isFalse);
    expect(nav, ['next']);
  });
}

class _Flow extends SetUpFlowNotifier {
  _Flow(this.chosen);

  final AccountGroup? chosen;

  @override
  AccountGroup? build() => chosen;
}
