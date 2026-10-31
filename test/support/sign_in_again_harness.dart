// What the Sign in again tests share (issue #3811): fakes for the sign-in,
// sync and backup, and a host that runs them through real providers.

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
import 'package:submersion/core/services/sync/sync_failure_store.dart';
import 'package:submersion/features/backup/presentation/providers/backup_copy_providers.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/sign_in_again.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../helpers/test_database.dart';
import 'fake_keychain_storage.dart';

class FakeAuthenticator implements GoogleDriveAuthenticator {
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

class FakeSyncNotifier extends StateNotifier<SyncState>
    implements SyncNotifier {
  FakeSyncNotifier([super.state = const SyncState()]);

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

class FakeBackupOp extends StateNotifier<BackupOperationState>
    implements BackupOperationNotifier {
  FakeBackupOp(this.log) : super(const BackupOperationState());

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

AccountGroup accountGroup({
  AccountKind kind = AccountKind.googledrive,
  String? identifier = 'diver@example.com',
  bool syncs = true,
  bool holdsCopy = false,
  String? key,
  bool usagesKnown = true,
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
    key: key ?? kind.name,
    kind: kind,
    label: kind.name,
    identifier: identifier,
    rows: [row],
    status: AccountStatus.needsSignIn,
    usages: [
      if (syncs) const AccountUsage(AccountUsageKind.databaseSync),
      if (holdsCopy) const AccountUsage(AccountUsageKind.backupCopy),
    ],
    usagesKnown: usagesKnown,
    locations: const {},
    roles: const {},
    usageRoles: const {},
    rowStatuses: const {},
    address: kind.name,
  );
}

DropboxStorageProvider fakeDropbox() {
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

/// The state one test shares with [pumpHost]. Replace [sync] before pumping
/// to start from a particular status.
class SignInHarness {
  late FakeAuthenticator authenticator;
  late FakeSyncNotifier sync;
  late FakeBackupOp backup;
  late SharedPreferences prefs;
  var copyReads = 0;

  Future<void> setUp() async {
    copyReads = 0;
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    authenticator = FakeAuthenticator();
    sync = FakeSyncNotifier();
    backup = FakeBackupOp(sync.log);
  }

  Future<(BuildContext, WidgetRef)> pumpHost(
    WidgetTester tester, {
    AccountGroup? group,
    BackupCopyTarget copy = const NoCopy(),
    bool copyReadOutlivesAFrame = false,
    bool accountsFail = false,
    SyncFailureStore? failureStore,
    DropboxStorageProvider? dropbox,
    ValueListenable<bool>? hostShown,
  }) async {
    final account = group ?? accountGroup();
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
          accountGroupsProvider.overrideWith((ref) async {
            if (accountsFail) throw StateError('no roster');
            return [account];
          }),
          backupCopyTargetProvider.overrideWith((ref) async {
            copyReads++;
            if (copyReadOutlivesAFrame) {
              // As the real target does while accounts are probed: it goes on
              // using its ref, which throws if nothing held it meanwhile.
              await Future<void>.delayed(const Duration(milliseconds: 100));
              ref.read(localeProvider);
            }
            return copy;
          }),
          syncStateProvider.overrideWith((ref) => sync),
          backupOperationProvider.overrideWith((ref) => backup),
          if (failureStore != null)
            syncFailureStoreProvider.overrideWithValue(failureStore),
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
}
