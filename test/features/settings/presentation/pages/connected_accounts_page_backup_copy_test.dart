// Issue #3388: Sign out and Remove warn before the backup copy goes with an
// account, and issue #3782: an account backups are also copied to stops
// getting copies. Split from connected_accounts_page_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateNotifier;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_provider_registry.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/domain/entities/backup_copy_account.dart';
import 'package:submersion/features/settings/presentation/pages/account_detail_page.dart';
import 'package:submersion/features/settings/presentation/pages/connected_accounts_page.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_group_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';
import '../../../../support/fake_keychain_storage.dart';

class _RecordingAdapter extends AccountProviderAdapter {
  _RecordingAdapter(this.kind);

  @override
  final AccountKind kind;
  final disconnected = <String>[];

  /// Rows that hold no keys on this device.
  final keyless = <String>{};

  @override
  Future<AccountStatus> status(domain.ConnectedAccount account) async =>
      keyless.contains(account.id)
      ? AccountStatus.needsSignIn
      : AccountStatus.signedIn;

  @override
  Future<void> disconnect(domain.ConnectedAccount account) async {
    disconnected.add(account.id);
  }
}

/// Records sync sign-outs, with whether the account was still signed in.
class _SyncNotifier extends StateNotifier<SyncState> implements SyncNotifier {
  _SyncNotifier(this.adapter) : super(const SyncState());
  final _RecordingAdapter adapter;
  final signOutsBeforeDisconnect = <bool>[];

  @override
  Future<void> signOut() async =>
      signOutsBeforeDisconnect.add(adapter.disconnected.isEmpty);

  @override
  Future<void> refreshState() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late ConnectedAccountsRepository accounts;
  late _RecordingAdapter dropbox;
  late _RecordingAdapter s3;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    accounts = ConnectedAccountsRepository();
    dropbox = _RecordingAdapter(AccountKind.dropbox);
    s3 = _RecordingAdapter(AccountKind.s3);
  });

  tearDown(() => tearDownTestDatabase());

  Future<void> pumpPage(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // The detail view's server form reads this device's keys.
          accountCredentialsStoreProvider.overrideWithValue(
            AccountCredentialsStore(storage: InMemoryKeychain()),
          ),
          accountProviderRegistryProvider.overrideWithValue(
            AccountProviderRegistry([dropbox, s3]),
          ),
          ...overrides,
        ],
        child: MaterialApp.router(
          // Pinned: the assertions match English strings.
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            initialLocation: '/settings/connected-accounts',
            routes: [
              GoRoute(
                path: '/settings/connected-accounts',
                builder: (_, _) => const ConnectedAccountsPage(),
                routes: [
                  GoRoute(
                    path: ':accountId',
                    builder: (_, state) => AccountDetailPage(
                      accountId: state.pathParameters['accountId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<domain.ConnectedAccount> addDropbox(WidgetTester tester) async {
    late domain.ConnectedAccount account;
    await tester.runAsync(() async {
      account = await accounts.create(
        kind: AccountKind.dropbox,
        label: 'Dropbox',
      );
    });
    return account;
  }

  Future<void> useForSync(WidgetTester tester, String accountId) =>
      tester.runAsync(() async {
        final sync = SyncRepository();
        await sync.getOrCreateMetadata();
        await sync.setSyncAccount(
          accountId: accountId,
          providerType: CloudProviderType.dropbox,
        );
      });

  /// Opens the (first) account's detail view and taps [item] there; the
  /// account actions moved off the list row into the detail view (#3482).
  Future<void> openMenu(WidgetTester tester, String item) async {
    if (find.byType(AccountDetailPage).evaluate().isEmpty) {
      await tester.tap(find.byType(AccountGroupTile).first);
      await settle(tester);
      await tester.pumpAndSettle();
    }
    if (find.text(item).hitTestable().evaluate().isEmpty) {
      // A finder that may match nothing yet: the detail list builds rows as
      // they scroll in, and an own server's form pushes the actions below.
      await tester.scrollUntilVisible(
        find.text(item),
        200,
        scrollable: find
            .descendant(
              of: find.byType(AccountDetailPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  group('the backup copy', () {
    Future<void> pinCopyTo(String id, AccountKind kind) async {
      final backup = BackupPreferences(prefs);
      await backup.setCloudBackupEnabled(true);
      await backup.setCopyDestination(accountId: id, kind: kind);
    }

    testWidgets('signing out the sync account leaves a copy pinned elsewhere', (
      tester,
    ) async {
      final account = await addDropbox(tester);
      await useForSync(tester, account.id);
      await pinCopyTo('another-row', AccountKind.s3);
      final sync = _SyncNotifier(dropbox);
      await pumpPage(
        tester,
        overrides: [syncStateProvider.overrideWith((ref) => sync)],
      );

      await openMenu(tester, 'Sign out on this device');
      expect(find.textContaining('stop making a copy'), findsNothing);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Sign out on this device'),
        ),
      );
      await settle(tester);

      final settings = BackupPreferences(prefs).getSettings();
      expect(sync.signOutsBeforeDisconnect, [true]);
      expect(settings.cloudBackupEnabled, isTrue);
      expect(settings.copyAccountId, 'another-row');
    });

    testWidgets('signing out the copy account warns, then turns the copy off', (
      tester,
    ) async {
      final account = await addDropbox(tester);
      await pinCopyTo(account.id, AccountKind.dropbox);
      await pumpPage(tester);

      await openMenu(tester, 'Sign out on this device');
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Backups will stop making a copy'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Sign out on this device'),
        ),
      );
      await settle(tester);

      final settings = BackupPreferences(prefs).getSettings();
      expect(dropbox.disconnected, [account.id]);
      expect(settings.cloudBackupEnabled, isFalse);
      expect(settings.copyAccountId, isNull);
    });

    testWidgets('removing the copy account warns, then turns the copy off', (
      tester,
    ) async {
      final account = await addDropbox(tester);
      await pinCopyTo(account.id, AccountKind.dropbox);
      await pumpPage(tester);

      await openMenu(tester, 'Remove from all devices');
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Backups will stop making a copy'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Remove from all devices'),
        ),
      );
      await settle(tester);

      expect(
        BackupPreferences(prefs).getSettings().cloudBackupEnabled,
        isFalse,
      );
    });

    testWidgets('cancelling the confirmation keeps the copy', (tester) async {
      final account = await addDropbox(tester);
      await pinCopyTo(account.id, AccountKind.dropbox);
      await pumpPage(tester);

      await openMenu(tester, 'Sign out on this device');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Cancel'),
        ),
      );
      await settle(tester);

      final settings = BackupPreferences(prefs).getSettings();
      expect(dropbox.disconnected, isEmpty);
      expect(settings.cloudBackupEnabled, isTrue);
      expect(settings.copyAccountId, account.id);
    });

    // Issue #3782: an account backups are also copied to stops getting
    // copies, and the main copy carries on.
    group('an extra copy account', () {
      Future<void> addExtra(String id) async {
        final backup = BackupPreferences(prefs);
        await backup.setCloudBackupEnabled(true);
        await backup.setCopyDestination(
          accountId: 'another-row',
          kind: AccountKind.s3,
        );
        await backup.setExtraCopyAccounts([
          BackupCopyAccount(accountId: id, kind: AccountKind.dropbox),
          const BackupCopyAccount(accountId: 'git-row', kind: AccountKind.git),
        ]);
      }

      testWidgets('signing out drops it from the extra copies', (tester) async {
        final account = await addDropbox(tester);
        await addExtra(account.id);
        await pumpPage(tester);

        await openMenu(tester, 'Sign out on this device');
        expect(find.textContaining('stop making a copy'), findsNothing);
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Sign out on this device'),
          ),
        );
        await settle(tester);

        final settings = BackupPreferences(prefs).getSettings();
        expect(settings.cloudBackupEnabled, isTrue);
        expect(settings.copyAccountId, 'another-row');
        expect(settings.extraCopyAccounts.map((a) => a.accountId), ['git-row']);
      });

      testWidgets('removing drops it from the extra copies', (tester) async {
        final account = await addDropbox(tester);
        await addExtra(account.id);
        await pumpPage(tester);

        await openMenu(tester, 'Remove from all devices');
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Remove from all devices'),
          ),
        );
        await settle(tester);

        final settings = BackupPreferences(prefs).getSettings();
        expect(settings.cloudBackupEnabled, isTrue);
        expect(settings.extraCopyAccounts.map((a) => a.accountId), ['git-row']);
      });
    });
  });
}

/// The page's providers read the database and keychain probes off the fake
/// clock; let them finish, then rebuild.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}
