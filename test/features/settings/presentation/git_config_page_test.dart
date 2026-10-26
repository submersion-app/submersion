import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_location.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/git/git_config.dart';
import 'package:submersion/core/services/cloud_storage/git/git_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';
import 'package:submersion/core/services/cloud_storage/git_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_tls.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/sync_cleanup_outcome.dart';
import 'package:submersion/core/services/sync/sync_service.dart'
    show ConflictResolution;
import 'package:submersion/features/settings/presentation/pages/git_config_page.dart';
import 'package:submersion/features/settings/presentation/providers/git_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_sign_in.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/git_error_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../../support/fake_keychain_storage.dart';

/// A Git provider whose network side is scripted.
class _FakeGit extends GitStorageProvider {
  _FakeGit() : super(store: GitCredentialsStore(storage: InMemoryKeychain()));

  GitConnectionReport report = const GitConnectionReport(
    branchExists: false,
    willBecomeDefault: false,
    isPublic: false,
  );
  Object? failWith;

  /// Thrown by the next testConnection only.
  Object? failOnce;
  int tests = 0;
  final tested = <GitConfig>[];

  @override
  Future<GitConnectionReport> testConnection(GitConfig config) async {
    tests++;
    tested.add(config);
    final once = failOnce;
    if (once != null) {
      failOnce = null;
      throw once;
    }
    final error = failWith;
    if (error != null) throw error;
    return report;
  }
}

/// Records the Git accounts the page saves, without a database.
class _FakeAccounts extends ConnectedAccountsRepository {
  final ensured = <ConnectedAccount>[];

  /// Thrown by the next save, as a keychain or database failure would be.
  Object? failWith;

  @override
  Future<ConnectedAccount> ensure({
    required AccountKind kind,
    required String naturalKey,
    required String label,
    AccountLocation? location,
  }) async {
    final fail = failWith;
    if (fail != null) throw fail;
    final now = DateTime.utc(2026, 10, 19);
    final row = ConnectedAccount(
      id: accountIdFor(kind: kind, naturalKey: naturalKey),
      kind: kind,
      label: label,
      createdAt: now,
      updatedAt: now,
    );
    ensured.add(row);
    return row;
  }
}

/// Minimal [SyncNotifier] that never touches the database.
class _FakeSyncNotifier extends StateNotifier<SyncState>
    implements SyncNotifier {
  _FakeSyncNotifier(this._ref) : super(const SyncState());

  final Ref _ref;

  @override
  Future<void> refreshState() async {}

  @override
  Future<void> signOut() async {
    _ref.read(selectedCloudProviderTypeProvider.notifier).state = null;
  }

  @override
  Future<void> performSync({bool auto = false}) async {}

  @override
  Future<ReplacePreflight> replacePreflight() async =>
      const ReplacePreflight(localDiveCount: 0, peerFileCount: 0);

  @override
  Future<void> replaceCloudLibraryFromThisDevice() async {}

  @override
  Future<void> disableForDatabaseReset() async {}

  @override
  Future<FirstSyncMergeInfo?> firstSyncMergeInfo() async => null;

  @override
  Future<LibraryEpochMarker?> libraryReplaceInfo() async => null;

  @override
  Future<void> adoptReplacedLibrary() async {}

  @override
  Future<void> resetSyncState() async {}

  @override
  Future<void> repairSync() async {}

  @override
  Future<SyncCleanupOutcome> removeThisDeviceCloudFiles({
    SyncCleanupProgress? onProgress,
  }) async => const SyncCleanupOutcome();

  @override
  Future<SyncCleanupOutcome> wipeAllCloudSyncData({
    SyncCleanupProgress? onProgress,
  }) async => const SyncCleanupOutcome();

  @override
  Future<void> rebuildBackendFromThisDevice({
    SyncCleanupProgress? onProgress,
    void Function()? onPublishStarted,
  }) async {}

  @override
  Future<void> resolveConflict(
    String entityType,
    String recordId,
    ConflictResolution resolution,
  ) async {}

  @override
  Future<void> acknowledgeMoved() async {}

  @override
  Future<void> checkLibraryMoved() async {}

  @override
  Future<void> cleanupOldBackendData() async {}

  @override
  Future<void> dismissOldBackendCleanup() async {}

  @override
  Future<void> recordBackendDeparture({
    required CloudStorageProvider oldProvider,
    required String toProviderId,
    String? toProviderName,
  }) async {}
}

void main() {
  late _FakeGit git;
  late _FakeAccounts accounts;
  late AccountCredentialsStore credentials;

  /// What the page popped with, once it has.
  ConnectedAccount? popped;

  /// What signInToGroup returned, when the page was opened through it.
  bool? signedIn;

  setUp(() {
    git = _FakeGit();
    accounts = _FakeAccounts();
    credentials = AccountCredentialsStore(storage: InMemoryKeychain());
    popped = null;
    signedIn = null;
  });

  /// A Git account of [config] as the roster lists it, not signed in here.
  AccountGroup groupOf(GitConfig config) {
    final row = ConnectedAccount(
      id: accountIdFor(
        kind: AccountKind.git,
        naturalKey: gitNaturalKey(config),
      ),
      kind: AccountKind.git,
      label: config.displayLabel,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    return AccountGroup(
      key: 'git|${row.id}',
      kind: AccountKind.git,
      label: row.label,
      rows: [row],
      status: AccountStatus.needsSignIn,
      usages: const [],
      locations: const {},
      roles: const {},
      usagesKnown: true,
      address: row.label,
      usageRoles: const {},
      rowStatuses: {row.id: AccountStatus.needsSignIn},
    );
  }

  /// The saved config of [row], from its own credential key.
  Future<GitConfig?> savedFor(ConnectedAccount row) async =>
      decodeGitConfig(await credentials.read(row.id));

  Future<void> pumpPage(
    WidgetTester tester, {
    bool encrypted = false,
    AccountGroup? existing,
    bool viaSignIn = false,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({
      'sync_encryption_enabled': encrypted,
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          accountCredentialsStoreProvider.overrideWithValue(credentials),
          connectedAccountsRepositoryProvider.overrideWithValue(accounts),
          gitCredentialsStoreProvider.overrideWithValue(
            GitCredentialsStore(storage: InMemoryKeychain()),
          ),
          gitStorageProviderInstanceProvider.overrideWithValue(git),
          syncStateProvider.overrideWith((ref) => _FakeSyncNotifier(ref)),
          selectedCloudProviderTypeProvider.overrideWith((ref) => null),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () async {
                if (viaSignIn) {
                  signedIn = await signInToGroup(context, ref, existing!);
                } else {
                  popped = await showGitAccountPage(
                    context,
                    existing: existing,
                  );
                }
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> fillValidForm(
    WidgetTester tester, {
    String url = 'https://github.com/you/dive-log',
    String token = 'ghp_secret',
  }) async {
    await tester.enterText(find.byKey(const Key('git-repo-url')), url);
    await tester.enterText(find.byKey(const Key('git-username')), 'you');
    await tester.enterText(find.byKey(const Key('git-token')), token);
    await tester.pump();
  }

  testWidgets('shows the four fields with the branch defaulted', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.text('Repository address'), findsOneWidget);
    expect(find.text('The HTTPS address you would clone from'), findsOneWidget);
    expect(find.text('Access token'), findsOneWidget);
    expect(find.text(kDefaultGitBranch), findsOneWidget);
    expect(
      find.textContaining('Your other branches are never touched'),
      findsOneWidget,
    );
  });

  testWidgets('the token help follows the host in the address', (tester) async {
    await pumpPage(tester);
    await tester.enterText(
      find.byKey(const Key('git-repo-url')),
      'https://github.com/you/r',
    );
    await tester.pump();
    expect(find.textContaining('fine-grained token'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('git-repo-url')),
      'https://gitlab.example.org/group/r',
    );
    await tester.pump();
    expect(find.textContaining('write_repository'), findsOneWidget);
    expect(find.textContaining('fine-grained token'), findsNothing);
  });

  testWidgets('an empty token is refused before any request', (tester) async {
    await pumpPage(tester);
    await fillValidForm(tester, token: '');
    await tester.tap(find.byKey(const Key('git-save')));
    await tester.pumpAndSettle();
    expect(find.text('Enter the access token'), findsOneWidget);
    expect(git.tests, 0);
    expect(accounts.ensured, isEmpty);
  });

  testWidgets('an invalid branch name is refused before any request', (
    tester,
  ) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.enterText(find.byKey(const Key('git-branch')), 'sync dev');
    await tester.tap(find.byKey(const Key('git-test')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid branch name'), findsOneWidget);
    expect(git.tests, 0);
  });

  testWidgets('a failure outside Git and the keychain is not blamed on '
      'secure storage', (tester) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    git.failWith = StateError('boom');
    await tester.tap(find.byKey(const Key('git-test')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Something went wrong'), findsOneWidget);
    expect(find.textContaining('secure storage'), findsNothing);
  });

  testWidgets('a keychain failure on save says so', (tester) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    accounts.failWith = StateError('keychain locked');
    await tester.tap(find.byKey(const Key('git-save')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Could not access secure storage'),
      findsOneWidget,
    );
  });

  testWidgets('every failure shows its own localized text', (tester) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    final l10n = AppLocalizationsEn();
    for (final code in GitErrorCode.values) {
      final error = GitException(
        'x',
        code: code,
        host: 'git.example.net',
        sizeBytes: 120 * 1024 * 1024,
      );
      git.failWith = error;
      await tester.tap(find.byKey(const Key('git-test')));
      await tester.pumpAndSettle();
      expect(
        find.text(gitErrorText(l10n, error, branch: kDefaultGitBranch)),
        findsOneWidget,
        reason: code.name,
      );
      ScaffoldMessenger.of(
        tester.element(find.byType(GitConfigPage)),
      ).clearSnackBars();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('an empty repository warns that the branch becomes the default', (
    tester,
  ) async {
    git.report = const GitConnectionReport(
      branchExists: false,
      willBecomeDefault: true,
      isPublic: false,
    );
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.tap(find.byKey(const Key('git-test')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('will become its default branch'),
      findsOneWidget,
    );
  });

  testWidgets(
    'a public repository with encryption off is not saved on cancel',
    (tester) async {
      git.report = const GitConnectionReport(
        branchExists: false,
        willBecomeDefault: false,
        isPublic: true,
      );
      await pumpPage(tester);
      await fillValidForm(tester);
      await tester.tap(find.byKey(const Key('git-save')));
      await tester.pumpAndSettle();
      expect(find.text('This repository is public'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(accounts.ensured, isEmpty);
    },
  );

  testWidgets('choosing to turn on encryption saves the public repository', (
    tester,
  ) async {
    git.report = const GitConnectionReport(
      branchExists: true,
      willBecomeDefault: false,
      isPublic: true,
    );
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.tap(find.byKey(const Key('git-save')));
    await tester.pumpAndSettle();
    // The dialog only saves; encryption is turned on from Cloud sync.
    await tester.tap(find.byKey(const Key('git-public-save')));
    await tester.pumpAndSettle();
    // Recorded as an account, with its own keys, and handed back.
    expect(accounts.ensured, hasLength(1));
    expect(popped?.id, accounts.ensured.single.id);
    expect(
      (await savedFor(popped!))!.cloneUrl.toString(),
      'https://github.com/you/dive-log.git',
    );
  });

  testWidgets('a public repository saves straight away when encryption is on', (
    tester,
  ) async {
    git.report = const GitConnectionReport(
      branchExists: true,
      willBecomeDefault: false,
      isPublic: true,
    );
    await pumpPage(tester, encrypted: true);
    await fillValidForm(tester);
    await tester.tap(find.byKey(const Key('git-save')));
    await tester.pumpAndSettle();
    expect(find.text('This repository is public'), findsNothing);
    expect(accounts.ensured, hasLength(1));
  });

  testWidgets('signing an account in again fills the form from its keys', (
    tester,
  ) async {
    final config = GitConfig(
      repoUrl: 'https://gitlab.com/group/r',
      username: 'you',
      token: 'glpat_x',
      branch: 'dive-sync',
    );
    final row = ConnectedAccount(
      id: accountIdFor(
        kind: AccountKind.git,
        naturalKey: gitNaturalKey(config),
      ),
      kind: AccountKind.git,
      label: config.displayLabel,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    await credentials.write(row.id, jsonEncode(config.toJson()));
    await pumpPage(
      tester,
      existing: AccountGroup(
        key: 'git|${row.id}',
        kind: AccountKind.git,
        label: row.label,
        rows: [row],
        status: AccountStatus.signedIn,
        usages: const [],
        locations: const {},
        roles: const {},
        usagesKnown: true,
        address: row.label,
        usageRoles: const {},
        rowStatuses: {row.id: AccountStatus.signedIn},
      ),
    );
    expect(
      find.text('Sign in to group/r @ gitlab.com (dive-sync)'),
      findsOneWidget,
    );
    expect(find.text('https://gitlab.com/group/r.git'), findsOneWidget);
    expect(find.text('dive-sync'), findsOneWidget);
    expect(find.textContaining('write_repository'), findsOneWidget);
    expect(find.byKey(const Key('git-remove')), findsNothing);
  });

  testWidgets('signing in on a new device starts from the account address', (
    tester,
  ) async {
    await pumpPage(
      tester,
      existing: groupOf(
        GitConfig(
          repoUrl: 'https://gitlab.com/group/r',
          username: 'you',
          token: 'kept on another device',
          branch: 'dive-sync',
        ),
      ),
    );
    expect(find.text('https://gitlab.com/group/r'), findsOneWidget);
    expect(find.text('dive-sync'), findsOneWidget);
    expect(find.text('kept on another device'), findsNothing);
  });

  testWidgets('a sign-in saved under another branch is a new account', (
    tester,
  ) async {
    final config = GitConfig(
      repoUrl: 'https://github.com/you/dive-log',
      username: 'you',
      token: 'ghp_secret',
    );
    await pumpPage(tester, existing: groupOf(config), viaSignIn: true);
    await tester.enterText(
      find.byKey(const Key('git-repo-url')),
      'https://github.com/you/dive-log',
    );
    await tester.enterText(find.byKey(const Key('git-username')), 'you');
    await tester.enterText(find.byKey(const Key('git-token')), 'ghp_secret');
    await tester.enterText(find.byKey(const Key('git-branch')), 'club');
    await tester.tap(find.byKey(const Key('git-save')));
    await tester.pumpAndSettle();
    // Saved, but not as the account being signed in: that one still has no
    // keys here, so the caller must not use it.
    expect(accounts.ensured.single.id, isNot(groupOf(config).rows.single.id));
    expect(signedIn, isFalse);
  });

  testWidgets('an existing Submersion branch is reported as found', (
    tester,
  ) async {
    git.report = const GitConnectionReport(
      branchExists: true,
      willBecomeDefault: false,
      isPublic: false,
    );
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.tap(find.byKey(const Key('git-test')));
    await tester.pumpAndSettle();
    expect(
      find.text('Connected to the Submersion branch submersion-sync.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'a trusted self-signed certificate is pinned and the test retried',
    (tester) async {
      git.failOnce = GitUntrustedCertificateException(
        WebDavCertificateDetails(
          host: 'git.example.net',
          port: 443,
          sha256: 'ab' * 32,
          subject: 'CN=git.example.net',
          issuer: 'CN=git.example.net',
          startValidity: DateTime.utc(2026),
          endValidity: DateTime.utc(2027),
        ),
      );
      await pumpPage(tester);
      await fillValidForm(tester, url: 'https://git.example.net/you/r');
      await tester.tap(find.byKey(const Key('git-test')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trust this certificate'));
      await tester.pumpAndSettle();
      expect(git.tests, 2);
      expect(git.tested.first.pinnedCertSha256, isNull);
      expect(git.tested.last.pinnedCertSha256, 'ab' * 32);
      expect(find.textContaining('Connected.'), findsOneWidget);
    },
  );
}
