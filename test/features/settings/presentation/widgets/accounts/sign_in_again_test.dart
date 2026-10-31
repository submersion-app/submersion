// Issue #3811: Sign in again runs from the error itself, retries what the
// account was failing, and never lets a different account through.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive_storage_provider.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/presentation/providers/backup_copy_providers.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/data_health_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_sign_in.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/sign_in_again.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/data_health_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/test_database.dart';

import '../../../../../support/sign_in_again_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final h = SignInHarness();

  setUp(h.setUp);
  tearDown(() => tearDownTestDatabase());

  testWidgets('the same account signs in and syncs', (tester) async {
    final group = accountGroup();
    await h.run(tester, await h.pumpHost(tester, group: group), group);

    expect(h.authenticator.calls, 1);
    expect(h.sync.performSyncCalls, 1);
    expect(h.backup.performCalls, 0);
  });

  testWidgets('one account for sync and the copy retries both, sync first', (
    tester,
  ) async {
    await BackupPreferences(h.prefs).setLastCloudCopyMissing(true);
    final group = accountGroup();

    await h.run(
      tester,
      await h.pumpHost(tester, group: group, copy: CopyFollowsSync(group)),
      group,
    );

    expect(h.sync.log, ['sync', 'backup']);
  });

  testWidgets('a good copy is not backed up again', (tester) async {
    final group = accountGroup();

    await h.run(
      tester,
      await h.pumpHost(tester, group: group, copy: CopyFollowsSync(group)),
      group,
    );

    expect(h.sync.log, ['sync']);
  });

  testWidgets('an account only the copy uses does not sync', (tester) async {
    await BackupPreferences(h.prefs).setLastCloudCopyMissing(true);
    final group = accountGroup(syncs: false);

    await h.run(
      tester,
      await h.pumpHost(
        tester,
        group: group,
        copy: CopyToAccount(group, group.rows.first),
      ),
      group,
    );

    expect(h.sync.log, ['backup']);
  });

  testWidgets('a cancelled sign-in changes nothing', (tester) async {
    h.authenticator.error = const CloudStorageException(
      'Google Sign-In was cancelled',
    );
    final group = accountGroup();

    await h.run(tester, await h.pumpHost(tester, group: group), group);

    expect(h.sync.log, isEmpty);
  });

  testWidgets('a different account stops, naming both, and retries nothing', (
    tester,
  ) async {
    h.authenticator.signsInAs = 'other@example.com';
    await BackupPreferences(h.prefs).setLastCloudCopyMissing(true);
    final group = accountGroup();
    final host = await h.pumpHost(
      tester,
      group: group,
      copy: CopyFollowsSync(group),
    );

    unawaited(signInAgain(host.$1, host.$2, group));
    await tester.pumpAndSettle();

    expect(find.text("That's a different account"), findsOneWidget);
    expect(
      find.text(
        'Submersion uses diver@example.com, but you signed in as '
        'other@example.com.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Nothing was synced, and other@example.com was not connected.'),
      findsOneWidget,
    );
    expect(h.sync.log, isEmpty);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.text("That's a different account"), findsNothing);
    expect(h.authenticator.calls, 1);
    expect(h.sync.log, isEmpty);
  });

  testWidgets('Sign in again in that dialog runs the sign-in again', (
    tester,
  ) async {
    h.authenticator.signsInAs = 'other@example.com';
    final group = accountGroup();
    final host = await h.pumpHost(tester, group: group);

    unawaited(signInAgain(host.$1, host.$2, group));
    await tester.pumpAndSettle();

    h.authenticator.signsInAs = 'diver@example.com';
    await tester.tap(find.text('Sign in again'));
    await tester.pumpAndSettle();

    expect(h.authenticator.calls, 2);
    expect(h.sync.performSyncCalls, 1);
  });

  testWidgets('a Dropbox sign-in to another account stops the same way', (
    tester,
  ) async {
    final group = accountGroup(
      kind: AccountKind.dropbox,
      identifier: 'diver@example.com',
    );
    final host = await h.pumpHost(tester, group: group, dropbox: fakeDropbox());

    unawaited(signInAgain(host.$1, host.$2, group));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'the-code');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(find.text("That's a different account"), findsOneWidget);
    expect(h.sync.log, isEmpty);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
  });

  testWidgets('a sign-in that never returns does not disable the action', (
    tester,
  ) async {
    // The macOS loopback flow has no timeout and no cancel dialog, so closing
    // the browser leaves it waiting for good.
    h.authenticator.gate = Completer<void>();
    final group = accountGroup();
    final host = await h.pumpHost(tester, group: group);

    unawaited(signInAgain(host.$1, host.$2, group));
    await tester.pump();
    await tester.pump(const Duration(minutes: 6));
    unawaited(signInAgain(host.$1, host.$2, group));
    await tester.pump();

    expect(h.authenticator.calls, 2);

    h.authenticator.gate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('an abandoned sign-in that finishes late retries nothing', (
    tester,
  ) async {
    // Both attempts wait on one gate, so both finish together: the second
    // retries, and the one it replaced must not back up or sync as well.
    await BackupPreferences(h.prefs).setLastCloudCopyMissing(true);
    h.authenticator.gate = Completer<void>();
    final group = accountGroup();
    final host = await h.pumpHost(
      tester,
      group: group,
      copy: CopyFollowsSync(group),
    );

    final abandoned = signInAgain(host.$1, host.$2, group);
    await tester.pump();
    await tester.pump(const Duration(minutes: 6));
    final current = signInAgain(host.$1, host.$2, group);
    await tester.pump();

    h.authenticator.gate!.complete();
    await tester.pumpAndSettle();
    await Future.wait([abandoned, current]);

    expect(h.sync.log, ['sync', 'backup']);
  });

  testWidgets('an abandoned sign-in that finishes late asks nothing', (
    tester,
  ) async {
    h.authenticator
      ..gate = Completer<void>()
      ..signsInAs = 'other@example.com';
    final group = accountGroup();
    final host = await h.pumpHost(tester, group: group);

    unawaited(signInAgain(host.$1, host.$2, group));
    await tester.pump();
    await tester.pump(const Duration(minutes: 6));

    h.authenticator.gate!.complete();
    await tester.pumpAndSettle();

    expect(find.text("That's a different account"), findsNothing);
  });

  testWidgets('accounts that cannot be read say so and sign in to nothing', (
    tester,
  ) async {
    final host = await h.pumpHost(tester, accountsFail: true);

    final done = signInAgain(host.$1, host.$2, accountGroup());
    await tester.pumpAndSettle();
    await done;

    expect(find.byType(SnackBar), findsOneWidget);
    expect(h.sync.performSyncCalls, 0);
    expect(h.backup.performCalls, 0);
  });

  testWidgets('a host gone during the account read ends quietly', (
    tester,
  ) async {
    final shown = ValueNotifier(true);
    addTearDown(shown.dispose);
    final group = accountGroup();
    final host = await h.pumpHost(
      tester,
      group: group,
      hostShown: shown,
      copyReadOutlivesAFrame: true,
    );

    final done = signInAgain(host.$1, host.$2, group);
    await tester.pump();
    shown.value = false;
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await done;

    expect(h.authenticator.calls, 0);
  });

  testWidgets('a Dropbox sign-in finishes if its host goes away', (
    tester,
  ) async {
    final shown = ValueNotifier(true);
    addTearDown(shown.dispose);
    final group = accountGroup(
      kind: AccountKind.dropbox,
      identifier: 'other@example.com',
    );
    final host = await h.pumpHost(
      tester,
      group: group,
      dropbox: fakeDropbox(),
      hostShown: shown,
    );

    final done = signInToGroup(host.$1, host.$2, group);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'the-code');
    shown.value = false;
    await tester.pump();
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(await done, isTrue);
  });

  testWidgets('a second tap while one runs starts no second sign-in', (
    tester,
  ) async {
    h.authenticator.gate = Completer<void>();
    final group = accountGroup();
    final host = await h.pumpHost(tester, group: group);

    final first = signInAgain(host.$1, host.$2, group);
    await tester.pump();
    final second = signInAgain(host.$1, host.$2, group);
    await tester.pump();
    h.authenticator.gate!.complete();
    await tester.pumpAndSettle();
    await Future.wait([first, second]);

    expect(h.authenticator.calls, 1);
    expect(h.sync.performSyncCalls, 1);
  });

  testWidgets('the retry still runs once the line that offered it is gone', (
    tester,
  ) async {
    h.authenticator.gate = Completer<void>();
    final group = accountGroup();
    final health = StateProvider<List<FeatureHealth>>(
      (ref) => const [
        FeatureHealth(
          feature: DataFeature.sync,
          level: HealthLevel.failing,
          reason: HealthReason.syncSignedOut,
        ),
      ],
    );
    final drive = GoogleDriveStorageProvider(authenticator: h.authenticator);
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localeProvider.overrideWithValue('en'),
          sharedPreferencesProvider.overrideWithValue(h.prefs),
          cloudStorageProviderProvider.overrideWithValue(drive),
          cloudStorageProviderForProvider(
            CloudProviderType.googledrive,
          ).overrideWithValue(drive),
          accountGroupsProvider.overrideWith((ref) async => [group]),
          backupCopyTargetProvider.overrideWith((ref) async => const NoCopy()),
          googleDriveAvailableProvider.overrideWith((ref) async => true),
          syncStateProvider.overrideWith((ref) => h.sync),
          backupOperationProvider.overrideWith((ref) => h.backup),
          dataHealthProvider.overrideWith((ref) => ref.watch(health)),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return const Scaffold(body: DataHealthStrip());
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign in again'));
    await tester.pump();

    // The sign-in lands: health clears, and the line and its button go.
    container.read(health.notifier).state = const [
      FeatureHealth(
        feature: DataFeature.sync,
        level: HealthLevel.healthy,
        reason: HealthReason.ok,
      ),
    ];
    await tester.pump();
    expect(find.text('Sign in again'), findsNothing);

    h.authenticator.gate!.complete();
    await tester.pumpAndSettle();

    expect(h.sync.performSyncCalls, 1);
  });
}
