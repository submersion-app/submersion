// Issue #3811: Sign in again runs from the error itself, retries what the
// account was failing, and never lets a different account through.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_api_client.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_manager.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_store.dart';
import 'package:submersion/core/services/cloud_storage/dropbox_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive_storage_provider.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/presentation/providers/backup_copy_providers.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/domain/data_health/sync_health.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/data_health_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sign_in_again_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_sign_in.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/sign_in_again.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/sign_in_again_button.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/data_health_strip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/test_database.dart';
import '../../../../../support/fake_keychain_storage.dart';

class _FakeAuthenticator implements GoogleDriveAuthenticator {
  String signsInAs = 'diver@example.com';
  Object? error;
  int calls = 0;
  Completer<void>? gate;

  @override
  http.Client? authClient;

  @override
  Future<void> authenticate({String? expectedAccount}) async {
    calls++;
    await gate?.future;
    final failure = error;
    if (failure != null) throw failure;
    if (!isSameAccount(expectedAccount, signsInAs)) {
      throw CloudAccountMismatchException(signsInAs);
    }
    authClient = MockClient((_) async => http.Response('{}', 200));
  }

  @override
  Future<bool> attemptSilentAuth() async => authClient != null;

  @override
  bool get lastSilentAuthThrew => false;

  @override
  Future<String?> get userEmail async => signsInAs;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> handleAuthFailure() async {}
}

class _FakeSyncNotifier extends StateNotifier<SyncState>
    implements SyncNotifier {
  _FakeSyncNotifier([super.state = const SyncState()]);

  int performSyncCalls = 0;

  /// What ran, in order, so a test can tell sync went before backup.
  final List<String> log = [];

  @override
  Future<void> performSync({bool auto = false}) async {
    performSyncCalls++;
    log.add('sync');
  }

  int refreshStateCalls = 0;

  @override
  Future<void> refreshState() async => refreshStateCalls++;

  @override
  Future<FirstSyncMergeInfo?> firstSyncMergeInfo() async => null;

  @override
  Future<LibraryEpochMarker?> libraryReplaceInfo() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBackupOp extends StateNotifier<BackupOperationState>
    implements BackupOperationNotifier {
  _FakeBackupOp(this.log) : super(const BackupOperationState());

  final List<String> log;
  int performCalls = 0;

  @override
  Future<void> performBackup({String? note}) async {
    performCalls++;
    log.add('backup');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AccountGroup _group({
  AccountKind kind = AccountKind.googledrive,
  String? identifier = 'diver@example.com',
  bool syncs = true,
}) {
  final at = DateTime.utc(2026);
  final row = ConnectedAccount(
    id: kind.name,
    kind: kind,
    label: kind.name,
    accountIdentifier: identifier,
    createdAt: at,
    updatedAt: at,
  );
  return AccountGroup(
    key: kind.name,
    kind: kind,
    label: kind.name,
    identifier: identifier,
    rows: [row],
    status: AccountStatus.needsSignIn,
    usages: [if (syncs) const AccountUsage(AccountUsageKind.databaseSync)],
    usagesKnown: true,
    locations: const {},
    roles: const {},
    usageRoles: const {},
    rowStatuses: const {},
    address: kind.name,
  );
}

DropboxStorageProvider _dropbox() {
  final mock = MockClient((request) async {
    if (request.url.path == '/oauth2/token') {
      return http.Response(
        '{"access_token":"at","refresh_token":"rt","expires_in":14400}',
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response(
      '{"email":"other@example.com","name":{"display_name":"Other"}}',
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  final auth = DropboxAuthManager(
    appKey: 'k',
    store: DropboxAuthStore(storage: InMemoryKeychain()),
    httpClient: mock,
    verifierGenerator: () => 'a' * 43,
  );
  return DropboxStorageProvider(
    authManager: auth,
    apiClient: DropboxApiClient(
      getAccessToken: auth.getAccessToken,
      onAccessTokenRejected: auth.invalidateAccessToken,
      httpClient: mock,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAuthenticator authenticator;
  late _FakeSyncNotifier sync;
  late _FakeBackupOp backup;
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    authenticator = _FakeAuthenticator();
    sync = _FakeSyncNotifier();
    backup = _FakeBackupOp(sync.log);
  });
  tearDown(() => tearDownTestDatabase());

  Future<(BuildContext, WidgetRef)> pumpHost(
    WidgetTester tester, {
    AccountGroup? group,
    BackupCopyTarget copy = const NoCopy(),
    DropboxStorageProvider? dropbox,
    ValueListenable<bool>? hostShown,
  }) async {
    final account = group ?? _group();
    final drive = GoogleDriveStorageProvider(authenticator: authenticator);
    late BuildContext context;
    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localeProvider.overrideWithValue('en'),
          sharedPreferencesProvider.overrideWithValue(prefs),
          cloudStorageProviderProvider.overrideWithValue(drive),
          cloudStorageProviderForProvider(
            CloudProviderType.googledrive,
          ).overrideWithValue(drive),
          if (dropbox != null)
            dropboxStorageProviderInstanceProvider.overrideWithValue(dropbox),
          accountGroupsProvider.overrideWith((ref) async => [account]),
          backupCopyTargetProvider.overrideWith((ref) async => copy),
          syncStateProvider.overrideWith((ref) => sync),
          backupOperationProvider.overrideWith((ref) => backup),
          accountCredentialsStoreProvider.overrideWithValue(
            AccountCredentialsStore(storage: InMemoryKeychain()),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ValueListenableBuilder<bool>(
            valueListenable: hostShown ?? ValueNotifier(true),
            builder: (_, shown, _) => shown
                ? Consumer(
                    builder: (c, r, _) {
                      context = c;
                      ref = r;
                      return const Scaffold();
                    },
                  )
                : const Scaffold(),
          ),
        ),
      ),
    );
    return (context, ref);
  }

  Future<void> run(
    WidgetTester tester,
    (BuildContext, WidgetRef) host,
    AccountGroup group,
  ) async {
    final done = signInAgain(host.$1, host.$2, group);
    await tester.pumpAndSettle();
    await done;
  }

  testWidgets('the same account signs in and syncs', (tester) async {
    final group = _group();
    await run(tester, await pumpHost(tester, group: group), group);

    expect(authenticator.calls, 1);
    expect(sync.performSyncCalls, 1);
    expect(backup.performCalls, 0);
  });

  testWidgets('a sign-in failure recorded for the provider is cleared', (
    tester,
  ) async {
    final group = _group();
    final host = await pumpHost(tester, group: group);
    final notifier = host.$2.read(syncFailureProvider.notifier);
    await notifier.record(
      SyncFailureRecord(
        providerId: 'googledrive',
        at: DateTime(2026, 10, 1),
        kind: SyncFailureKind.auth,
        message: 'refused',
      ),
    );

    await run(tester, host, group);

    expect(host.$2.read(syncFailureProvider), isNull);
  });

  testWidgets('an account only the copy uses leaves a sync failure alone', (
    tester,
  ) async {
    final group = _group(syncs: false);
    final host = await pumpHost(
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

    await run(tester, host, group);

    expect(host.$2.read(syncFailureProvider), isNotNull);
  });

  testWidgets('one account for sync and the copy retries both, sync first', (
    tester,
  ) async {
    await BackupPreferences(prefs).setLastCloudCopyMissing(true);
    final group = _group();

    await run(
      tester,
      await pumpHost(tester, group: group, copy: CopyFollowsSync(group)),
      group,
    );

    expect(sync.log, ['sync', 'backup']);
  });

  testWidgets('a good copy is not backed up again', (tester) async {
    final group = _group();

    await run(
      tester,
      await pumpHost(tester, group: group, copy: CopyFollowsSync(group)),
      group,
    );

    expect(sync.log, ['sync']);
  });

  testWidgets('an account only the copy uses does not sync', (tester) async {
    await BackupPreferences(prefs).setLastCloudCopyMissing(true);
    final group = _group(syncs: false);

    await run(
      tester,
      await pumpHost(
        tester,
        group: group,
        copy: CopyToAccount(group, group.rows.first),
      ),
      group,
    );

    expect(sync.log, ['backup']);
  });

  testWidgets('a cancelled sign-in changes nothing', (tester) async {
    authenticator.error = const CloudStorageException(
      'Google Sign-In was cancelled',
    );
    final group = _group();

    await run(tester, await pumpHost(tester, group: group), group);

    expect(sync.log, isEmpty);
  });

  testWidgets('a different account stops, naming both, and retries nothing', (
    tester,
  ) async {
    authenticator.signsInAs = 'other@example.com';
    await BackupPreferences(prefs).setLastCloudCopyMissing(true);
    final group = _group();
    final host = await pumpHost(
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
    expect(sync.log, isEmpty);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.text("That's a different account"), findsNothing);
    expect(authenticator.calls, 1);
    expect(sync.log, isEmpty);
  });

  testWidgets('Sign in again in that dialog runs the sign-in again', (
    tester,
  ) async {
    authenticator.signsInAs = 'other@example.com';
    final group = _group();
    final host = await pumpHost(tester, group: group);

    unawaited(signInAgain(host.$1, host.$2, group));
    await tester.pumpAndSettle();

    authenticator.signsInAs = 'diver@example.com';
    await tester.tap(find.text('Sign in again'));
    await tester.pumpAndSettle();

    expect(authenticator.calls, 2);
    expect(sync.performSyncCalls, 1);
  });

  testWidgets('a Dropbox sign-in to another account stops the same way', (
    tester,
  ) async {
    final group = _group(
      kind: AccountKind.dropbox,
      identifier: 'diver@example.com',
    );
    final host = await pumpHost(tester, group: group, dropbox: _dropbox());

    unawaited(signInAgain(host.$1, host.$2, group));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'the-code');
    await tester.tap(find.text('Connect'));
    await tester.pumpAndSettle();

    expect(find.text("That's a different account"), findsOneWidget);
    expect(sync.log, isEmpty);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
  });

  testWidgets('a sign-in that never returns does not disable the action', (
    tester,
  ) async {
    // The macOS loopback flow has no timeout and no cancel dialog, so closing
    // the browser leaves it waiting for good.
    authenticator.gate = Completer<void>();
    final group = _group();
    final host = await pumpHost(tester, group: group);

    unawaited(signInAgain(host.$1, host.$2, group));
    await tester.pump();
    await tester.pump(const Duration(minutes: 6));
    unawaited(signInAgain(host.$1, host.$2, group));
    await tester.pump();

    expect(authenticator.calls, 2);

    authenticator.gate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('an abandoned sign-in that finishes late retries nothing', (
    tester,
  ) async {
    // Both attempts wait on one gate, so both finish together: the second
    // retries, and the one it replaced must not back up or sync as well.
    await BackupPreferences(prefs).setLastCloudCopyMissing(true);
    authenticator.gate = Completer<void>();
    final group = _group();
    final host = await pumpHost(
      tester,
      group: group,
      copy: CopyFollowsSync(group),
    );

    final abandoned = signInAgain(host.$1, host.$2, group);
    await tester.pump();
    await tester.pump(const Duration(minutes: 6));
    final current = signInAgain(host.$1, host.$2, group);
    await tester.pump();

    authenticator.gate!.complete();
    await tester.pumpAndSettle();
    await Future.wait([abandoned, current]);

    expect(sync.log, ['sync', 'backup']);
  });

  testWidgets('an abandoned sign-in that finishes late asks nothing', (
    tester,
  ) async {
    authenticator
      ..gate = Completer<void>()
      ..signsInAs = 'other@example.com';
    final group = _group();
    final host = await pumpHost(tester, group: group);

    unawaited(signInAgain(host.$1, host.$2, group));
    await tester.pump();
    await tester.pump(const Duration(minutes: 6));

    authenticator.gate!.complete();
    await tester.pumpAndSettle();

    expect(find.text("That's a different account"), findsNothing);
  });

  testWidgets('any sign-in tells sync it is signed in again', (tester) async {
    final group = _group(syncs: false);
    final host = await pumpHost(tester, group: group);

    final done = signInToGroup(host.$1, host.$2, group);
    await tester.pumpAndSettle();
    await done;

    expect(sync.refreshStateCalls, 1);
  });

  testWidgets('a sign-in during a sync leaves its status alone', (
    tester,
  ) async {
    sync = _FakeSyncNotifier(const SyncState(status: SyncStatus.syncing));
    final group = _group();
    final host = await pumpHost(tester, group: group);

    final done = signInToGroup(host.$1, host.$2, group);
    await tester.pumpAndSettle();
    await done;

    expect(sync.refreshStateCalls, 0);
  });

  testWidgets('a Dropbox sign-in finishes if its host goes away', (
    tester,
  ) async {
    final shown = ValueNotifier(true);
    addTearDown(shown.dispose);
    final group = _group(
      kind: AccountKind.dropbox,
      identifier: 'other@example.com',
    );
    final host = await pumpHost(
      tester,
      group: group,
      dropbox: _dropbox(),
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

  group('a sign-in from anywhere', () {
    Future<WidgetRef> signInWithFailureOnRecord(
      WidgetTester tester,
      AccountGroup group,
    ) async {
      final host = await pumpHost(tester, group: group);
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
      final ref = await signInWithFailureOnRecord(tester, _group());

      expect(ref.read(syncFailureProvider), isNull);
    });

    testWidgets('leaves one that belongs to another account', (tester) async {
      final ref = await signInWithFailureOnRecord(tester, _group(syncs: false));

      expect(ref.read(syncFailureProvider), isNotNull);
    });
  });

  testWidgets('a second tap while one runs starts no second sign-in', (
    tester,
  ) async {
    authenticator.gate = Completer<void>();
    final group = _group();
    final host = await pumpHost(tester, group: group);

    final first = signInAgain(host.$1, host.$2, group);
    await tester.pump();
    final second = signInAgain(host.$1, host.$2, group);
    await tester.pump();
    authenticator.gate!.complete();
    await tester.pumpAndSettle();
    await Future.wait([first, second]);

    expect(authenticator.calls, 1);
    expect(sync.performSyncCalls, 1);
  });

  testWidgets('the retry still runs once the line that offered it is gone', (
    tester,
  ) async {
    authenticator.gate = Completer<void>();
    final group = _group();
    final health = StateProvider<List<FeatureHealth>>(
      (ref) => const [
        FeatureHealth(
          feature: DataFeature.sync,
          level: HealthLevel.failing,
          reason: HealthReason.syncSignedOut,
        ),
      ],
    );
    final drive = GoogleDriveStorageProvider(authenticator: authenticator);
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localeProvider.overrideWithValue('en'),
          sharedPreferencesProvider.overrideWithValue(prefs),
          cloudStorageProviderProvider.overrideWithValue(drive),
          cloudStorageProviderForProvider(
            CloudProviderType.googledrive,
          ).overrideWithValue(drive),
          accountGroupsProvider.overrideWith((ref) async => [group]),
          backupCopyTargetProvider.overrideWith((ref) async => const NoCopy()),
          googleDriveAvailableProvider.overrideWith((ref) async => true),
          syncStateProvider.overrideWith((ref) => sync),
          backupOperationProvider.overrideWith((ref) => backup),
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

    authenticator.gate!.complete();
    await tester.pumpAndSettle();

    expect(sync.performSyncCalls, 1);
  });

  group('offersSignInAgain', () {
    FeatureHealth health(DataFeature feature, HealthReason reason) =>
        FeatureHealth(
          feature: feature,
          level: HealthLevel.attention,
          reason: reason,
        );

    test('the two sign-in reasons do', () {
      expect(
        offersSignInAgain(health(DataFeature.sync, HealthReason.syncSignedOut)),
        isTrue,
      );
      expect(
        offersSignInAgain(
          health(DataFeature.backup, HealthReason.backupCloudSignIn),
        ),
        isTrue,
      );
    });

    test('a plain failure does not', () {
      expect(
        offersSignInAgain(health(DataFeature.sync, HealthReason.syncFailed)),
        isFalse,
      );
    });
  });

  group('signInAgainGroupProvider', () {
    Future<AccountGroup?> resolve(
      AccountGroup group, {
      DataFeature feature = DataFeature.sync,
      bool googleAvailable = true,
      bool dropboxConfigured = true,
      BackupCopyTarget copy = const NoCopy(),
    }) async {
      final container = ProviderContainer(
        overrides: [
          accountGroupsProvider.overrideWith((ref) async => [group]),
          backupCopyTargetProvider.overrideWith((ref) async => copy),
          googleDriveAvailableProvider.overrideWith(
            (ref) async => googleAvailable,
          ),
          dropboxConfiguredProvider.overrideWithValue(dropboxConfigured),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(
        signInAgainGroupProvider(feature).future,
        (_, _) {},
      );
      addTearDown(sub.close);
      return sub.read();
    }

    test('sync offers the account sync uses', () async {
      final group = _group();
      expect((await resolve(group))?.key, group.key);
    });

    test('backup offers the copy account', () async {
      final group = _group(syncs: false);
      expect(
        (await resolve(
          group,
          feature: DataFeature.backup,
          copy: CopyToAccount(group, group.rows.first),
        ))?.key,
        group.key,
      );
    });

    test('an account sync does not use offers nothing', () async {
      expect(await resolve(_group(syncs: false)), isNull);
    });

    test('iCloud has no sign-in to offer', () async {
      expect(await resolve(_group(kind: AccountKind.icloud)), isNull);
    });

    test('a build without Google or Dropbox sign-in offers nothing', () async {
      expect(await resolve(_group(), googleAvailable: false), isNull);
      expect(
        await resolve(
          _group(kind: AccountKind.dropbox),
          dropboxConfigured: false,
        ),
        isNull,
      );
    });

    test('an own server offers its form', () async {
      expect(await resolve(_group(kind: AccountKind.s3)), isNotNull);
    });
  });

  group('SignInAgainButton', () {
    Future<void> pumpButton(
      WidgetTester tester, {
      AccountGroup? group,
      SyncState state = const SyncState(),
      List<AccountGroup>? pressed,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            signInAgainGroupProvider(
              DataFeature.sync,
            ).overrideWith((ref) async => group),
            syncStateProvider.overrideWith((ref) => _FakeSyncNotifier(state)),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SignInAgainButton(
                feature: DataFeature.sync,
                onPressed: (g) => pressed?.add(g),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offers the action and hands over the account', (tester) async {
      final pressed = <AccountGroup>[];
      final group = _group();
      await pumpButton(tester, group: group, pressed: pressed);

      await tester.tap(find.text('Sign in again'));

      expect(pressed.single.key, group.key);
    });

    testWidgets('shows nothing without an account', (tester) async {
      await pumpButton(tester);

      expect(find.text('Sign in again'), findsNothing);
    });

    testWidgets('shows nothing while sync runs', (tester) async {
      await pumpButton(
        tester,
        group: _group(),
        state: const SyncState(status: SyncStatus.syncing),
      );

      expect(find.text('Sign in again'), findsNothing);
    });
  });
}
