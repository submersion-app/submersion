import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_client.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/webdav_storage_provider.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/sync_cleanup_outcome.dart';
import 'package:submersion/core/services/sync/sync_service.dart'
    show ConflictResolution;
import 'package:submersion/features/settings/presentation/pages/webdav_config_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/providers/webdav_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/fake_webdav_server.dart';
import '../../../support/fake_keychain_storage.dart';

/// Minimal [SyncNotifier] stub that avoids touching the database.
/// Accepts a [Ref] so [signOut] can mirror the real notifier's side-effect of
/// clearing [selectedCloudProviderTypeProvider].
class _FakeSyncNotifier extends StateNotifier<SyncState>
    implements SyncNotifier {
  final Ref _ref;
  _FakeSyncNotifier(this._ref) : super(const SyncState());

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
  Future<void> refreshState() async {}

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
  Future<void> signOut() async {
    _ref.read(selectedCloudProviderTypeProvider.notifier).state = null;
    state = const SyncState();
  }

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
  late FakeWebDavServer server;
  late WebDavStorageProvider provider;
  late AccountCredentialsStore accountCredentials;

  setUp(() {
    server = FakeWebDavServer();
    accountCredentials = AccountCredentialsStore(storage: InMemoryKeychain());
    provider = WebDavStorageProvider(
      store: WebDavCredentialsStore(storage: InMemoryKeychain()),
      clientFactory: (c) => WebDavClient(
        c,
        httpClient: server.client,
        backoff: (_) => Duration.zero,
      ),
    );
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    CloudProviderType? selected,
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          accountCredentialsStoreProvider.overrideWithValue(accountCredentials),
          webdavCredentialsStoreProvider.overrideWithValue(
            WebDavCredentialsStore(storage: InMemoryKeychain()),
          ),
          webdavStorageProviderInstanceProvider.overrideWithValue(provider),
          syncStateProvider.overrideWith((ref) => _FakeSyncNotifier(ref)),
          selectedCloudProviderTypeProvider.overrideWith((ref) => selected),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: WebDavConfigPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillValidForm(
    WidgetTester tester, {
    String password = 'secret',
  }) async {
    await tester.enterText(
      find.byKey(const Key('webdav-server-url')),
      'https://dav.test/dav',
    );
    await tester.enterText(find.byKey(const Key('webdav-username')), 'alice');
    await tester.enterText(find.byKey(const Key('webdav-password')), password);
    await tester.pump();
  }

  testWidgets('asks for the WebDAV address with no server type to pick', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.byKey(const Key('webdav-preset')), findsNothing);
    expect(find.byKey(const Key('webdav-server-url')), findsOneWidget);
    expect(find.text('WebDAV address'), findsOneWidget);
    expect(
      find.text(
        "The full WebDAV address from your server's settings, including its path",
      ),
      findsOneWidget,
    );
    expect(
      find.text('Use an app password if the account has two-factor sign-in'),
      findsOneWidget,
    );
  });

  testWidgets('http shows the warning', (tester) async {
    await pumpPage(tester);
    await tester.enterText(
      find.byKey(const Key('webdav-server-url')),
      'http://nas.local/dav',
    );
    await tester.pump();
    expect(find.byKey(const Key('webdav-http-warning')), findsOneWidget);
  });

  testWidgets('an address with a query is refused before any request', (
    tester,
  ) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.enterText(
      find.byKey(const Key('webdav-server-url')),
      'https://dav.test/dav?tenant=x',
    );
    await tester.tap(find.byKey(const Key('webdav-test')));
    await tester.pumpAndSettle();
    expect(
      find.text('Remove the part of the address after ? or #'),
      findsOneWidget,
    );
    expect(server.captured, isEmpty);
  });

  testWidgets('a missing, malformed or credentialed address is refused', (
    tester,
  ) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    const messages = {
      '': 'Required',
      'dav.test/dav': 'Enter an address starting with https:// or http://',
      'https://alice:secret@dav.test/dav':
          'Put the username and password in their own fields, not in the address',
    };
    for (final MapEntry(key: address, value: message) in messages.entries) {
      await tester.enterText(
        find.byKey(const Key('webdav-server-url')),
        address,
      );
      await tester.tap(find.byKey(const Key('webdav-test')));
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget, reason: address);
    }
    expect(server.captured, isEmpty);
  });

  testWidgets('Test connection probes the server and reports success', (
    tester,
  ) async {
    await pumpPage(tester);
    await fillValidForm(tester); // server https://dav.test/dav, alice, secret
    await tester.tap(find.byKey(const Key('webdav-test')));
    await tester.pumpAndSettle();
    expect(find.text('Connection successful'), findsOneWidget);
    expect(server.collections, contains('/dav/Submersion'));
  });

  testWidgets('a wrong password shows the localized 401 text', (tester) async {
    await pumpPage(tester);
    await fillValidForm(tester, password: 'nope');
    await tester.tap(find.byKey(const Key('webdav-test')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('The server rejected the username or password'),
      findsOneWidget,
    );
  });

  testWidgets('Save stores the config and selects WebDAV', (tester) async {
    await pumpPage(tester);
    await fillValidForm(tester);
    await tester.tap(find.byKey(const Key('webdav-save')));
    await tester.pumpAndSettle();
    expect(await provider.loadConfig(), isNotNull);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(WebDavConfigPage)),
    );
    expect(
      container.read(selectedCloudProviderTypeProvider),
      CloudProviderType.webdav,
    );
  });

  testWidgets('a stored pin shows and can be forgotten', (tester) async {
    await provider.saveConfig(
      WebDavConfig(
        serverUrl: 'https://dav.test/dav',
        username: 'alice',
        password: 'secret',
        pinnedCertSha256: 'ab' * 32,
      ),
    );
    await pumpPage(tester);
    expect(find.byKey(const Key('webdav-pin-row')), findsOneWidget);
    await tester.tap(find.byKey(const Key('webdav-forget-pin')));
    await tester.pump();
    expect(find.byKey(const Key('webdav-pin-row')), findsNothing);
  });

  testWidgets('Remove clears the stored config after confirmation', (
    tester,
  ) async {
    await provider.saveConfig(
      WebDavConfig(
        serverUrl: 'https://dav.test/dav',
        username: 'alice',
        password: 'secret',
      ),
    );
    await pumpPage(tester);
    await tester.ensureVisible(find.byKey(const Key('webdav-remove')));
    await tester.tap(find.byKey(const Key('webdav-remove')));
    await tester.pumpAndSettle();
    expect(find.text('Remove WebDAV configuration?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('webdav-remove-confirm')));
    await tester.pumpAndSettle();
    expect(await provider.loadConfig(), isNull);
  });

  testWidgets('Remove also deletes the sync account copy of the password', (
    tester,
  ) async {
    final saved = WebDavConfig(
      serverUrl: 'https://dav.test/dav',
      username: 'alice',
      password: 'secret',
    );
    await provider.saveConfig(saved);
    final accountId = accountIdFor(
      kind: AccountKind.webdav,
      naturalKey: webdavNaturalKey(saved),
    );
    await accountCredentials.write(accountId, '{}');
    await pumpPage(tester);
    await tester.ensureVisible(find.byKey(const Key('webdav-remove')));
    await tester.tap(find.byKey(const Key('webdav-remove')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('webdav-remove-confirm')));
    await tester.pumpAndSettle();
    expect(await accountCredentials.read(accountId), isNull);
  });
}
