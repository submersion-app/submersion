// Issue #3782: the Backups page lists the accounts each backup is also
// copied to, under the main copy, and adds or removes them.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/presentation/providers/backup_copy_providers.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_extra_copy_rows.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

final _t = DateTime.utc(2026);

ConnectedAccount _row(String id, AccountKind kind, String label) =>
    ConnectedAccount(
      id: id,
      kind: kind,
      label: label,
      createdAt: _t,
      updatedAt: _t,
    );

/// Google Drive (sync, and so the main copy), a Git repository and Dropbox.
final _groups = groupAccounts(
  rows: [
    _row('gd-row', AccountKind.googledrive, 'Google Drive'),
    _row('git-row', AccountKind.git, 'diver/backups @ github.com'),
    _row('db-row', AccountKind.dropbox, 'Dropbox'),
  ],
  statusById: const {
    'gd-row': AccountStatus.signedIn,
    'git-row': AccountStatus.signedIn,
    'db-row': AccountStatus.signedIn,
  },
  localLocationById: const {},
  usagesOf: (a) => a.id == 'gd-row'
      ? const [AccountUsage(AccountUsageKind.databaseSync)]
      : const [],
);

const _gitExtra = '{"id":"git-row","kind":"git"}';

void main() {
  late SharedPreferences prefs;

  Future<void> pumpRows(
    WidgetTester tester, {
    BackupCopyTarget? target,
    String extras = '[$_gitExtra]',
    List<String> missed = const [],
  }) async {
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      'backup_cloud_enabled': true,
      'backup_extra_copy_accounts': extras,
      'backup_last_extra_copy_missing': missed,
    });
    prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          accountGroupsProvider.overrideWith((ref) async => _groups),
          // The sheet reads these once Google Drive is left out of its kinds.
          accountGroupsOfKindsProvider.overrideWith(
            (ref, kindsKey) async => _groups,
          ),
          offerableAccountKindsProvider.overrideWithValue(const []),
          backupCopyTargetProvider.overrideWith(
            (ref) async => target ?? CopyFollowsSync(_groups.holding('gd-row')),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: BackupExtraCopyRows()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  List<String> savedExtras() => [
    for (final a in BackupPreferences(prefs).getSettings().extraCopyAccounts)
      a.accountId,
  ];

  testWidgets('hidden while there is no copy', (tester) async {
    await pumpRows(tester, target: const NoCopy());
    expect(find.byKey(const Key('backup-extra-copy-add')), findsNothing);
    expect(find.textContaining('Also copy to'), findsNothing);
  });

  testWidgets('hidden while the copy follows a sync that is not set up', (
    tester,
  ) async {
    await pumpRows(tester, target: const CopyFollowsSync(null));
    expect(find.byKey(const Key('backup-extra-copy-add')), findsNothing);
  });

  testWidgets('lists each extra account', (tester) async {
    await pumpRows(
      tester,
      extras: '[$_gitExtra,{"id":"gone-row","kind":"dropbox"}]',
    );
    expect(
      find.text('Also copy to diver/backups @ github.com'),
      findsOneWidget,
    );
    expect(find.text("The copy's account was removed"), findsOneWidget);
    expect(find.text('Copy to another account too'), findsOneWidget);
  });

  testWidgets('shows a missed copy', (tester) async {
    await pumpRows(tester, missed: const ['git-row']);
    expect(
      find.descendant(
        of: find.byKey(const Key('backup-extra-copy-git-row')),
        matching: find.text('The last backup did not reach this account'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('remove drops the account', (tester) async {
    await pumpRows(tester);
    await tester.tap(find.byKey(const Key('backup-extra-copy-remove-git-row')));
    await tester.pumpAndSettle();
    expect(savedExtras(), isEmpty);
    expect(find.textContaining('Also copy to'), findsNothing);
  });

  testWidgets('add excludes accounts already used, then adds the choice', (
    tester,
  ) async {
    await pumpRows(tester);
    await tester.tap(find.byKey(const Key('backup-extra-copy-add')));
    await tester.pumpAndSettle();

    final sheet = find.byType(BottomSheet);
    // The main copy's account and the existing extra are not offered.
    expect(
      find.descendant(of: sheet, matching: find.text('Google Drive')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.text('diver/backups @ github.com'),
      ),
      findsNothing,
    );

    await tester.tap(
      find.descendant(of: sheet, matching: find.text('Dropbox')),
    );
    await tester.pumpAndSettle();

    expect(savedExtras(), ['git-row', 'db-row']);
    expect(find.text('Also copy to Dropbox'), findsOneWidget);
  });
}
