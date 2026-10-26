// Issue #3388: each Connected Accounts row says what the account is used for
// on this device, and Sign out / Remove warn about those features first.

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
import 'package:submersion/core/services/accounts/pending_setup_service.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/accounts/account_location.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/settings/presentation/pages/account_detail_page.dart';
import 'package:submersion/features/settings/presentation/pages/connected_accounts_page.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_group_tile.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/providers/pending_setup_items_provider.dart';
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

  testWidgets('a row lists what uses the account on this device', (
    tester,
  ) async {
    final account = await addDropbox(tester);
    await useForSync(tester, account.id);
    await tester.runAsync(() async {
      await MediaStoreAttachState(prefs: prefs).setAttached(
        'store-1',
        providerType: CloudProviderType.dropbox,
        accountId: account.id,
      );
      await SharedLibraryStore().upsertLibrary(
        SharedLibrary(
          id: 'lib-1',
          name: 'Reef Sites',
          connectedAccountId: account.id,
          prefix: '',
        ),
      );
    });

    await pumpPage(tester);

    expect(
      find.text(
        'Used for: Sync between devices, Photos & videos, '
        'Shared site library: Reef Sites',
      ),
      findsOneWidget,
    );
  });

  testWidgets('an unused account says so', (tester) async {
    await addDropbox(tester);

    await pumpPage(tester);

    expect(find.text('Not used on this device'), findsOneWidget);
  });

  // An unknown is not an unused: a failed read still asks before acting,
  // and the action still works once confirmed.
  testWidgets('a failed usage read asks before signing out', (tester) async {
    final account = await addDropbox(tester);
    await pumpPage(
      tester,
      overrides: [
        connectedAccountUsageProvider.overrideWith(
          (ref) => Future.error(StateError('usage read failed')),
        ),
      ],
    );

    await openMenu(tester, 'Sign out on this device');
    await settle(tester);

    expect(
      find.textContaining('Could not check what this account is used for'),
      findsOneWidget,
    );
    expect(dropbox.disconnected, isEmpty);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Sign out on this device'),
      ),
    );
    await settle(tester);
    expect(dropbox.disconnected, [account.id]);
  });

  testWidgets('a failed usage read is named in the remove warning', (
    tester,
  ) async {
    await addDropbox(tester);
    await pumpPage(
      tester,
      overrides: [
        connectedAccountUsageProvider.overrideWith(
          (ref) => Future.error(StateError('usage read failed')),
        ),
      ],
    );

    await openMenu(tester, 'Remove from all devices');
    await settle(tester);

    expect(
      find.textContaining('Could not check what this account is used for'),
      findsOneWidget,
    );
  });

  // The page stays mounted under the Settings routes that change what an
  // account is used for, so it refreshes on their change signals.
  testWidgets('the row follows a sync selection made while it is open', (
    tester,
  ) async {
    final account = await addDropbox(tester);
    await pumpPage(tester);
    expect(find.text('Not used on this device'), findsOneWidget);

    await useForSync(tester, account.id);
    await settle(tester);

    expect(find.text('Used for: Sync between devices'), findsOneWidget);
  });

  testWidgets('the row follows a media store attach made while it is open', (
    tester,
  ) async {
    final account = await addDropbox(tester);
    await pumpPage(tester);
    expect(find.text('Not used on this device'), findsOneWidget);

    await tester.runAsync(
      () => MediaStoreAttachState(prefs: prefs).setAttached(
        'store-1',
        providerType: CloudProviderType.dropbox,
        accountId: account.id,
      ),
    );
    await settle(tester);

    expect(find.text('Used for: Photos & videos'), findsOneWidget);
  });

  testWidgets('signing out an unused account needs no confirmation', (
    tester,
  ) async {
    final account = await addDropbox(tester);
    await pumpPage(tester);

    await openMenu(tester, 'Sign out on this device');
    await settle(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(dropbox.disconnected, [account.id]);
  });

  // Issue #3482 review: a sign-out touches only the keychain, so nothing in
  // the database ticks; the Settings > Data rows under this pushed page read
  // the setup items and would keep calling the account signed in.
  testWidgets('signing out refreshes the setup items', (tester) async {
    await addDropbox(tester);
    var builds = 0;
    await pumpPage(
      tester,
      overrides: [
        pendingSetupItemsProvider.overrideWith((ref) async {
          builds++;
          return const <PendingSetupItem>[];
        }),
      ],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ConnectedAccountsPage)),
      listen: false,
    );
    final sub = container.listen(pendingSetupItemsProvider, (_, _) {});
    addTearDown(sub.close);
    await settle(tester);
    final before = builds;

    await openMenu(tester, 'Sign out on this device');
    await settle(tester);

    expect(builds, greaterThan(before));
  });

  testWidgets('signing out a used account names its features first', (
    tester,
  ) async {
    final account = await addDropbox(tester);
    await useForSync(tester, account.id);
    await pumpPage(tester);

    await openMenu(tester, 'Sign out on this device');

    expect(find.text('Sign out on this device?'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Sync between devices'),
      ),
      findsOneWidget,
    );
    expect(dropbox.disconnected, isEmpty);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await settle(tester);
    expect(dropbox.disconnected, isEmpty);

    await openMenu(tester, 'Sign out on this device');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Sign out on this device'),
      ),
    );
    await settle(tester);
    expect(dropbox.disconnected, [account.id]);
  });

  // Review: signing out of the sync account must take sync off it first, or
  // Sync still shows it active and a legacy key mirrors it back; cloud
  // backups, which ride on sync, stop with it, and the dialog says so.
  testWidgets('signing out the sync account stops sync and backups first', (
    tester,
  ) async {
    final account = await addDropbox(tester);
    await useForSync(tester, account.id);
    await BackupPreferences(prefs).setCloudBackupEnabled(true);
    final sync = _SyncNotifier(dropbox);
    await pumpPage(
      tester,
      overrides: [syncStateProvider.overrideWith((ref) => sync)],
    );

    await openMenu(tester, 'Sign out on this device');
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining(
          'Backups will stop making a copy',
          findRichText: true,
        ),
      ),
      findsWidgets,
    );
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Sign out on this device'),
      ),
    );
    await settle(tester);

    expect(sync.signOutsBeforeDisconnect, [true]);
    expect(dropbox.disconnected, [account.id]);
    expect(BackupPreferences(prefs).getSettings().cloudBackupEnabled, isFalse);
  });

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
  });

  testWidgets('removing the sync account stops sync first', (tester) async {
    final account = await addDropbox(tester);
    await useForSync(tester, account.id);
    final sync = _SyncNotifier(dropbox);
    await pumpPage(
      tester,
      overrides: [syncStateProvider.overrideWith((ref) => sync)],
    );

    await openMenu(tester, 'Remove from all devices');
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Remove from all devices'),
      ),
    );
    await settle(tester);

    expect(sync.signOutsBeforeDisconnect, [true]);
    expect(dropbox.disconnected, [account.id]);
  });

  testWidgets('signing out an account sync does not use leaves sync', (
    tester,
  ) async {
    await addDropbox(tester);
    final sync = _SyncNotifier(dropbox);
    await pumpPage(
      tester,
      overrides: [syncStateProvider.overrideWith((ref) => sync)],
    );

    await openMenu(tester, 'Sign out on this device');
    await settle(tester);

    expect(dropbox.disconnected, hasLength(1));
    expect(sync.signOutsBeforeDisconnect, isEmpty);
  });

  /// An S3 row in [prefix] on one server, placed by its synced location.
  Future<domain.ConnectedAccount> addServerRow(
    WidgetTester tester,
    String prefix,
  ) async {
    late domain.ConnectedAccount row;
    await tester.runAsync(() async {
      row = await accounts.ensure(
        kind: AccountKind.s3,
        naturalKey: 'minio.home|dives|$prefix',
        label: 'dives @ minio.home',
        location: S3AccountLocation(
          displayHost: 'minio.home',
          endpoint: 'https://minio.home',
          bucket: 'dives',
          region: 'us-east-1',
          prefix: prefix,
          pathStyle: true,
        ),
      );
    });
    return row;
  }

  // Review of #3527: every server saved through the form has a row in the
  // default sync folder; signing out of one sync does not use must leave
  // sync (here Dropbox) alone.
  testWidgets('signing out a server in the default sync folder leaves sync', (
    tester,
  ) async {
    final server = await addServerRow(tester, 'submersion-sync/');
    final sync = _SyncNotifier(s3);
    await pumpPage(
      tester,
      overrides: [syncStateProvider.overrideWith((ref) => sync)],
    );

    await openMenu(tester, 'Sign out on this device');
    await settle(tester);

    expect(s3.disconnected, [server.id]);
    expect(sync.signOutsBeforeDisconnect, isEmpty);
  });

  testWidgets('another device\'s folder needing sign-in keeps Sign out here', (
    tester,
  ) async {
    await addServerRow(tester, 'submersion-sync/');
    final photos = await addServerRow(tester, 'submersion-media/');
    s3.keyless.add(photos.id);
    await pumpPage(tester);

    await tester.tap(find.byType(AccountGroupTile).first);
    await settle(tester);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Remove from all devices'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(AccountDetailPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    expect(find.text('Sign out on this device'), findsOneWidget);
  });

  testWidgets('removing a used account names its features and other devices', (
    tester,
  ) async {
    final account = await addDropbox(tester);
    await useForSync(tester, account.id);
    await pumpPage(tester);

    await openMenu(tester, 'Remove from all devices');

    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('Sync between devices')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.text('Other devices may also use this account.'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('removing an unused account still mentions other devices', (
    tester,
  ) async {
    await addDropbox(tester);
    await pumpPage(tester);

    await openMenu(tester, 'Remove from all devices');

    expect(
      find.text('Other devices may also use this account.'),
      findsOneWidget,
    );
    expect(find.textContaining('On this device it is used for'), findsNothing);
  });

  // Issue #3482 phase 2: an account is a sign-in to one server; sync and a
  // library on one bucket are two roster rows but one account.
  testWidgets('two rows on one server show as one account', (tester) async {
    await tester.runAsync(() async {
      for (final prefix in ['submersion-sync/', 'submersion-sites/reef/']) {
        final a = await accounts.create(kind: AccountKind.s3, label: 'x');
        await accounts.setLocation(
          a.id,
          S3AccountLocation(
            displayHost: 'minio.home',
            endpoint: 'https://minio.home',
            bucket: 'dives',
            region: 'us-east-1',
            prefix: prefix,
            pathStyle: true,
          ),
        );
      }
    });
    await pumpPage(tester);
    expect(find.byType(AccountGroupTile), findsOneWidget);
    expect(find.text('dives @ minio.home'), findsOneWidget);
  });

  testWidgets('tapping an account opens its detail', (tester) async {
    await addDropbox(tester);
    await pumpPage(tester);
    await tester.tap(find.byType(AccountGroupTile));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.byType(AccountDetailPage), findsOneWidget);
    expect(find.text('Sign in again'), findsOneWidget);
  });

  testWidgets('Add account opens the add section of the sheet', (tester) async {
    await pumpPage(tester);
    expect(find.text('No accounts connected yet'), findsOneWidget);
    await tester.tap(find.byTooltip('Add account'));
    await tester.pumpAndSettle();
    expect(find.text('Add an account'), findsOneWidget);
    expect(find.text('My own server'), findsOneWidget);
  });

  testWidgets('iCloud is managed by the Apple ID and offers no sign-out', (
    tester,
  ) async {
    await tester.runAsync(
      () => accounts.create(kind: AccountKind.icloud, label: 'iCloud'),
    );
    await pumpPage(tester);
    await tester.tap(find.byType(AccountGroupTile));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('Managed by your Apple ID in device settings'),
      findsOneWidget,
    );
    expect(find.text('Sign out on this device'), findsNothing);
    expect(find.text('Sign in again'), findsNothing);
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
