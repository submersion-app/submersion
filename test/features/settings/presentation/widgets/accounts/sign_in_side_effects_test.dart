// Issue #3811: what any sign-in clears, from wherever it was started, and
// what it leaves alone.

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/sync/sync_failure_store.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/presentation/providers/backup_copy_providers.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/domain/data_health/sync_health.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_sign_in.dart';

import '../../../../../helpers/test_database.dart';

import '../../../../../support/sign_in_again_harness.dart';

class _StuckFailureStore extends SyncFailureStore {
  _StuckFailureStore(super.prefs);

  @override
  Future<void> clear() => throw StateError('no write');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final h = SignInHarness();

  setUp(h.setUp);
  tearDown(() => tearDownTestDatabase());

  testWidgets('a sign-in failure recorded for the provider is cleared', (
    tester,
  ) async {
    final group = accountGroup();
    final host = await h.pumpHost(tester, group: group);
    final notifier = host.$2.read(syncFailureProvider.notifier);
    await notifier.record(
      SyncFailureRecord(
        providerId: 'googledrive',
        at: DateTime(2026, 10, 1),
        kind: SyncFailureKind.auth,
        message: 'refused',
      ),
    );

    await h.run(tester, host, group);

    expect(host.$2.read(syncFailureProvider), isNull);
  });

  testWidgets('an account only the copy uses leaves a sync failure alone', (
    tester,
  ) async {
    final group = accountGroup(syncs: false);
    final host = await h.pumpHost(
      tester,
      group: group,
      copy: CopyToAccount(group, group.rows.first),
    );
    await host.$2
        .read(syncFailureProvider.notifier)
        .record(
          SyncFailureRecord(
            providerId: 'googledrive',
            at: DateTime(2026, 10, 1),
            kind: SyncFailureKind.auth,
            message: 'refused',
          ),
        );

    await h.run(tester, host, group);

    expect(host.$2.read(syncFailureProvider), isNotNull);
  });

  testWidgets('another account leaves what sync is showing alone', (
    tester,
  ) async {
    h.sync = FakeSyncNotifier(const SyncState(message: 'Encrypted, paused'));
    final group = accountGroup(syncs: false);
    final host = await h.pumpHost(tester, group: group);

    final done = signInToGroup(host.$1, host.$2, group);
    await tester.pumpAndSettle();
    await done;

    expect(h.sync.refreshStateCalls, 0);
  });

  testWidgets('a sign-in during a sync leaves its status alone', (
    tester,
  ) async {
    h.sync = FakeSyncNotifier(const SyncState(status: SyncStatus.syncing));
    final group = accountGroup();
    final host = await h.pumpHost(tester, group: group);

    final done = signInToGroup(host.$1, host.$2, group);
    await tester.pumpAndSettle();
    await done;

    expect(h.sync.refreshStateCalls, 0);
  });

  testWidgets('another account leaves a failed sync on the card', (
    tester,
  ) async {
    h.sync = FakeSyncNotifier(const SyncState(status: SyncStatus.error));
    final group = accountGroup(syncs: false);
    final host = await h.pumpHost(tester, group: group);

    final done = signInToGroup(host.$1, host.$2, group);
    await tester.pumpAndSettle();
    await done;

    expect(h.sync.refreshStateCalls, 0);
  });

  testWidgets('sync\'s own account clears a failed sync from the card', (
    tester,
  ) async {
    h.sync = FakeSyncNotifier(const SyncState(status: SyncStatus.error));
    final group = accountGroup();
    final host = await h.pumpHost(tester, group: group);

    final done = signInToGroup(host.$1, host.$2, group);
    await tester.pumpAndSettle();
    await done;

    expect(h.sync.refreshStateCalls, 1);
  });

  group('a sign-in from anywhere, for the backup copy', () {
    Future<bool> flagAfterSignIn(
      WidgetTester tester,
      AccountGroup group,
      BackupCopyTarget copy,
    ) async {
      await BackupPreferences(h.prefs).setLastCloudCopyNeedsSignIn(true);
      final host = await h.pumpHost(tester, group: group, copy: copy);
      final done = signInToGroup(host.$1, host.$2, group);
      await tester.pumpAndSettle();
      await done;
      return host.$2.read(backupSettingsProvider).lastCloudCopyNeedsSignIn;
    }

    testWidgets('clears the flag when the copy follows this account', (
      tester,
    ) async {
      final group = accountGroup();

      expect(
        await flagAfterSignIn(tester, group, CopyFollowsSync(group)),
        isFalse,
      );
    });

    testWidgets('clears the flag when the copy is pinned to this account', (
      tester,
    ) async {
      final group = accountGroup(syncs: false, holdsCopy: true);

      expect(
        await flagAfterSignIn(
          tester,
          group,
          CopyToAccount(group, group.rows.first),
        ),
        isFalse,
      );
    });

    testWidgets('with no flag set it probes nothing', (tester) async {
      final group = accountGroup();
      final host = await h.pumpHost(
        tester,
        group: group,
        copy: CopyFollowsSync(group),
      );

      final done = signInToGroup(host.$1, host.$2, group);
      await tester.pumpAndSettle();
      await done;

      expect(h.copyReads, 0);
    });

    testWidgets('clears the flag though nothing else watches the copy', (
      tester,
    ) async {
      await BackupPreferences(h.prefs).setLastCloudCopyNeedsSignIn(true);
      final group = accountGroup();
      final host = await h.pumpHost(
        tester,
        group: group,
        copy: CopyFollowsSync(group),
        copyReadOutlivesAFrame: true,
      );

      final done = signInToGroup(host.$1, host.$2, group);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      await done;

      expect(
        host.$2.read(backupSettingsProvider).lastCloudCopyNeedsSignIn,
        isFalse,
      );
    });

    testWidgets('clears the flag when what uses the account is unknown', (
      tester,
    ) async {
      final group = accountGroup(syncs: false, usagesKnown: false);

      expect(
        await flagAfterSignIn(tester, group, CopyFollowsSync(group)),
        isFalse,
      );
    });

    testWidgets('clears the flag when signing in regrouped the account', (
      tester,
    ) async {
      expect(
        await flagAfterSignIn(
          tester,
          accountGroup(key: 'row|googledrive'),
          CopyFollowsSync(accountGroup(key: 'googledrive|server')),
        ),
        isFalse,
      );
    });

    testWidgets('leaves it when the copy goes to another account', (
      tester,
    ) async {
      expect(
        await flagAfterSignIn(
          tester,
          accountGroup(),
          CopyFollowsSync(accountGroup(kind: AccountKind.dropbox)),
        ),
        isTrue,
      );
    });
  });

  group('a sign-in from anywhere', () {
    Future<WidgetRef> signInWithFailureOnRecord(
      WidgetTester tester,
      AccountGroup group, {
      SyncFailureStore? failureStore,
    }) async {
      final host = await h.pumpHost(
        tester,
        group: group,
        failureStore: failureStore,
      );
      await host.$2
          .read(syncFailureProvider.notifier)
          .record(
            SyncFailureRecord(
              providerId: 'googledrive',
              at: DateTime(2026, 10, 1),
              kind: SyncFailureKind.auth,
              message: 'refused',
            ),
          );
      final done = signInToGroup(host.$1, host.$2, group);
      await tester.pumpAndSettle();
      await done;
      return host.$2;
    }

    testWidgets('clears the sign-in failure of the sync account', (
      tester,
    ) async {
      final ref = await signInWithFailureOnRecord(tester, accountGroup());

      expect(ref.read(syncFailureProvider), isNull);
    });

    testWidgets('clears it when what uses the account is unknown', (
      tester,
    ) async {
      final ref = await signInWithFailureOnRecord(
        tester,
        accountGroup(syncs: false, usagesKnown: false),
      );

      expect(ref.read(syncFailureProvider), isNull);
    });

    testWidgets('a failed clear does not fail the sign-in', (tester) async {
      await signInWithFailureOnRecord(
        tester,
        accountGroup(),
        failureStore: _StuckFailureStore(h.prefs),
      );

      expect(h.sync.refreshStateCalls, 1);
    });

    testWidgets('leaves one that belongs to another account', (tester) async {
      final ref = await signInWithFailureOnRecord(
        tester,
        accountGroup(syncs: false),
      );

      expect(ref.read(syncFailureProvider), isNotNull);
    });
  });
}
