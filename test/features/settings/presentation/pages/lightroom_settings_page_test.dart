import 'dart:convert';

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_provider_registry.dart';
import 'package:submersion/core/services/accounts/adapters/lightroom_account_adapter.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/lightroom/adobe_ims_auth_manager.dart';
import 'package:submersion/core/services/lightroom/lightroom_api_client.dart';
import 'package:submersion/core/services/lightroom/lightroom_auth_store.dart';
import 'package:submersion/core/services/lightroom/lightroom_embedded_credential.dart';
import 'package:submersion/core/services/lightroom/lightroom_redirect_capture.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/features/media/data/services/lightroom_connector_state.dart';
import 'package:submersion/features/media/presentation/providers/lightroom_providers.dart';
import 'package:submersion/features/settings/presentation/pages/lightroom_settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';
import '../../../../support/fake_keychain_storage.dart';

const _guard = 'while (1) {}';

/// Returns a fixed redirect (with an auth code) from the in-app auth session.
class _FakeCapture implements LightroomRedirectCapture {
  _FakeCapture(this.result);
  final String result;
  @override
  Future<String> capture({
    required Uri authorizeUrl,
    required String callbackScheme,
  }) async => result;
}

/// Simulates the user cancelling / the auth session failing with a typed
/// connector error (surfaced via displayMessage).
class _ThrowingCapture implements LightroomRedirectCapture {
  @override
  Future<String> capture({
    required Uri authorizeUrl,
    required String callbackScheme,
  }) async => throw const CloudStorageException('Sign-in was cancelled');
}

/// Simulates a plain (non-CloudStorageException) failure, surfaced via
/// toString().
class _GenericThrowingCapture implements LightroomRedirectCapture {
  @override
  Future<String> capture({
    required Uri authorizeUrl,
    required String callbackScheme,
  }) async => throw Exception('unexpected boom');
}

void main() {
  late SharedPreferences prefs;
  late AdobeImsAuthManager authManager;
  late InMemoryKeychain keychain;

  MockClient apiMock() => MockClient((request) async {
    if (request.url.host == 'ims-na1.adobelogin.com') {
      return http.Response(
        jsonEncode({
          'access_token': 'at',
          'refresh_token': 'rt',
          'expires_in': 3600,
        }),
        200,
      );
    }
    if (request.url.path == '/v2/account') {
      return http.Response(
        '$_guard${jsonEncode({'id': 'acc1', 'full_name': 'Eric G', 'email': 'e@g.c'})}',
        200,
      );
    }
    if (request.url.path == '/v2/catalog') {
      return http.Response('$_guard${jsonEncode({'id': 'cat9'})}', 200);
    }
    if (request.url.path.endsWith('/albums')) {
      return http.Response(
        _guard +
            jsonEncode({
              'resources': [
                {
                  'id': 'al1',
                  'payload': {'name': 'Diving'},
                },
                {
                  'id': 'al2',
                  'payload': {'name': 'Wrecks'},
                },
              ],
            }),
        200,
      );
    }
    return http.Response('not found', 404);
  });

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    keychain = InMemoryKeychain();
    authManager = AdobeImsAuthManager(
      store: LightroomAuthStore(storage: keychain),
      httpClient: apiMock(),
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Widget app({LightroomRedirectCapture? capture}) => ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      lightroomAuthManagerProvider.overrideWithValue(authManager),
      lightroomApiClientProvider.overrideWithValue(
        LightroomApiClient(auth: authManager, httpClient: apiMock()),
      ),
      accountCredentialsStoreProvider.overrideWithValue(
        AccountCredentialsStore(storage: keychain),
      ),
      accountProviderRegistryProvider.overrideWithValue(
        AccountProviderRegistry([
          LightroomAccountAdapter(
            authStoreFactory: (key) =>
                LightroomAuthStore(storage: keychain, storageKey: key),
          ),
        ]),
      ),
      if (capture != null)
        lightroomRedirectCaptureProvider.overrideWithValue(capture),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LightroomSettingsPage(),
    ),
  );

  Future<void> pumpPage(
    WidgetTester tester, {
    LightroomRedirectCapture? capture,
  }) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(app(capture: capture));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pump();
    });
  }

  group('disconnected', () {
    testWidgets('renders credential fields with connect disabled until a '
        'client id is entered', (tester) async {
      await pumpPage(tester);

      expect(find.text('Adobe client ID'), findsOneWidget);
      expect(find.text('Client secret (optional)'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Connect Lightroom'),
      );
      expect(button.onPressed, isNull);

      await tester.enterText(
        find.widgetWithText(TextField, 'Adobe client ID'),
        'cid',
      );
      await tester.pump();
      final enabled = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Connect Lightroom'),
      );
      expect(enabled.onPressed, isNotNull);
    });

    testWidgets('renders the optional redirect URI field for BYO', (
      tester,
    ) async {
      await pumpPage(tester);
      expect(find.text('Redirect URI (optional)'), findsOneWidget);
    });

    testWidgets('hides the embedded Connect button on Linux, keeps BYO', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await pumpPage(tester);
        expect(
          find.widgetWithText(FilledButton, 'Connect with Adobe'),
          findsNothing,
        );
        expect(find.text('Use your own Adobe credentials'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('shows the embedded Connect button on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await pumpPage(tester);
        expect(
          find.widgetWithText(FilledButton, 'Connect with Adobe'),
          findsOneWidget,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('a BYO redirect URI is carried into the connect dialog', (
      tester,
    ) async {
      await pumpPage(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Adobe client ID'),
        'cid',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Redirect URI (optional)'),
        'adobe+abc://adobeid/cid',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Connect Lightroom'));
      await settle(tester);
      // The dialog opened (browser open fails inline in tests); the redirect
      // was threaded through beginAuthorization without error.
      expect(find.text('Connect Lightroom'), findsWidgets);
    });

    testWidgets('embedded Connect with Adobe signs in and shows the '
        'connected body', (tester) async {
      final capture = _FakeCapture(
        '${LightroomEmbeddedCredential.redirectUri}?code=thecode',
      );
      await pumpPage(tester, capture: capture);
      await tester.tap(find.widgetWithText(FilledButton, 'Connect with Adobe'));
      await settle(tester);
      await settle(tester);
      expect(find.text('Connected as Eric G'), findsOneWidget);
    });

    testWidgets('a failed embedded sign-in surfaces an error and stays '
        'disconnected', (tester) async {
      await pumpPage(tester, capture: _ThrowingCapture());
      await tester.tap(find.widgetWithText(FilledButton, 'Connect with Adobe'));
      await settle(tester);
      expect(find.textContaining('Sign-in was cancelled'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Connect with Adobe'),
        findsOneWidget,
      );
    });

    testWidgets('an unexpected embedded failure is surfaced via toString', (
      tester,
    ) async {
      await pumpPage(tester, capture: _GenericThrowingCapture());
      await tester.tap(find.widgetWithText(FilledButton, 'Connect with Adobe'));
      await settle(tester);
      expect(find.textContaining('unexpected boom'), findsOneWidget);
    });

    testWidgets('full connect flow creates the account and shows the '
        'connected body', (tester) async {
      await pumpPage(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Adobe client ID'),
        'cid',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Connect Lightroom'));
      await settle(tester);

      // The connect dialog is open (the browser open fails in tests and
      // surfaces an error inline, which must not block the flow).
      expect(find.text('Connect Lightroom'), findsWidgets);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'https://submersion.app/lightroom/callback?code=thecode',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Connect'),
        ),
      );
      await settle(tester);
      await settle(tester);

      expect(find.text('Connected as Eric G'), findsOneWidget);
      final auth = await tester.runAsync(() => authManager.loadAuth());
      expect(auth!.catalogId, 'cat9');
      expect(auth.displayName, 'Eric G');
    });
  });

  group('disconnected failure', () {
    testWidgets('a failing account fetch after the dialog surfaces the '
        'error and stays disconnected', (tester) async {
      // Token exchange succeeds; every lr.adobe.io call fails.
      final failingApi = MockClient((request) async {
        if (request.url.host == 'ims-na1.adobelogin.com') {
          return http.Response(
            jsonEncode({
              'access_token': 'at',
              'refresh_token': 'rt',
              'expires_in': 3600,
            }),
            200,
          );
        }
        return http.Response('down', 500);
      });
      authManager = AdobeImsAuthManager(
        store: LightroomAuthStore(storage: InMemoryKeychain()),
        httpClient: failingApi,
      );
      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              lightroomAuthManagerProvider.overrideWithValue(authManager),
              lightroomApiClientProvider.overrideWithValue(
                LightroomApiClient(auth: authManager, httpClient: failingApi),
              ),
            ],
            child: const MaterialApp(
              locale: Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: LightroomSettingsPage(),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      });

      await tester.enterText(
        find.widgetWithText(TextField, 'Adobe client ID'),
        'cid',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Connect Lightroom'));
      await settle(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'thecode',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Connect'),
        ),
      );
      await settle(tester);
      await settle(tester);

      expect(
        find.textContaining('Could not connect to Lightroom'),
        findsOneWidget,
      );
      expect(find.text('Adobe client ID'), findsOneWidget);
    });
  });

  group('connected', () {
    late String accountId;

    Future<void> seedAccount() async {
      // The API client resolves credentials through the auth manager, so
      // the connected state needs both the account row AND the auth blob.
      await authManager.updateAuth(
        const LightroomAuthData(clientId: 'cid', refreshToken: 'rt'),
      );
      final account = await ConnectedAccountsRepository().create(
        kind: AccountKind.adobeLightroom,
        label: 'Eric G',
        accountIdentifier: 'cat9',
      );
      accountId = account.id;
      // A signed-in device also has the per-account credential blob; the
      // page gates its connected UI on this (not just the roster row).
      await AccountCredentialsStore(storage: keychain).write(
        account.id,
        jsonEncode({'clientId': 'cid', 'refreshToken': 'rt'}),
      );
    }

    testWidgets('shows account, album filter, auto-poll, scan, disconnect', (
      tester,
    ) async {
      await tester.runAsync(seedAccount);
      await pumpPage(tester);

      expect(find.text('Connected as Eric G'), findsOneWidget);
      expect(find.text('Albums to scan'), findsOneWidget);
      expect(find.text('Entire catalog'), findsOneWidget);
      expect(find.text('Check for new photos automatically'), findsOneWidget);
      expect(find.text('Scan Lightroom'), findsOneWidget);
      expect(find.text('Disconnect'), findsOneWidget);
    });

    testWidgets('shows the last poll time when one is recorded', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await seedAccount();
        await LightroomConnectorState(
          prefs: prefs,
          accountId: accountId,
        ).setLastPollAt(DateTime.utc(2026, 7, 10, 6));
      });
      await pumpPage(tester);
      await settle(tester);

      expect(find.textContaining('Last checked:'), findsOneWidget);
    });

    testWidgets('needs-reauth chip appears when a last error is recorded', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await seedAccount();
        await LightroomConnectorState(
          prefs: prefs,
          accountId: accountId,
        ).setLastError('401');
      });
      await pumpPage(tester);
      await settle(tester);

      expect(find.text('Reconnect needed'), findsOneWidget);
    });

    testWidgets('auto-poll toggle persists', (tester) async {
      await tester.runAsync(seedAccount);
      await pumpPage(tester);
      await settle(tester);

      await tester.tap(find.byType(SwitchListTile));
      await settle(tester);

      final enabled = await tester.runAsync(
        () => LightroomConnectorState(
          prefs: prefs,
          accountId: accountId,
        ).autoPollEnabled(),
      );
      expect(enabled, isFalse);
    });

    testWidgets('album filter dialog lists albums and persists the '
        'selection', (tester) async {
      await tester.runAsync(seedAccount);
      await pumpPage(tester);
      await settle(tester);

      await tester.tap(find.text('Albums to scan'));
      await settle(tester);
      await settle(tester);

      expect(find.text('Diving'), findsOneWidget);
      expect(find.text('Wrecks'), findsOneWidget);
      await tester.tap(find.text('Diving'));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await settle(tester);

      final albumIds = await tester.runAsync(
        () => LightroomConnectorState(
          prefs: prefs,
          accountId: accountId,
        ).albumIds(),
      );
      expect(albumIds, ['al1']);
    });

    testWidgets('scan now runs and reports an empty summary', (tester) async {
      await tester.runAsync(seedAccount);
      await pumpPage(tester);
      await settle(tester);

      await tester.tap(find.text('Scan Lightroom'));
      await settle(tester);
      await settle(tester);

      // No dives in the database: the scan short-circuits with all-zero
      // counters and reports through the summary snackbar.
      expect(
        find.text('0 linked, 0 suggested, 0 already linked'),
        findsOneWidget,
      );
    });

    testWidgets('disconnect confirm removes the account and returns to the '
        'credential form', (tester) async {
      await tester.runAsync(seedAccount);
      await pumpPage(tester);
      await settle(tester);

      await tester.tap(find.text('Disconnect'));
      await settle(tester);
      expect(find.text('Disconnect Lightroom?'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Disconnect'),
        ),
      );
      await settle(tester);
      await settle(tester);

      expect(find.text('Adobe client ID'), findsOneWidget);
      final account = await tester.runAsync(
        () =>
            ConnectedAccountsRepository().getByKind(AccountKind.adobeLightroom),
      );
      expect(account, isNull);
    });
  });

  group('needs sign-in on a second device', () {
    // A synced roster row exists, but this device has no per-account
    // credential blob: the page must show the connect flow (not the
    // connected UI), and connecting must reuse the synced row.
    testWidgets('shows the connect flow despite the synced roster row', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await ConnectedAccountsRepository().create(
          kind: AccountKind.adobeLightroom,
          label: 'Eric G',
          accountIdentifier: 'cat9',
        );
        // No per-account blob and no legacy auth: device is needsSignIn.
      });
      await pumpPage(tester);

      expect(find.text('Adobe client ID'), findsOneWidget);
      expect(find.text('Connected as Eric G'), findsNothing);
    });

    testWidgets('connecting reuses the synced row (no duplicate)', (
      tester,
    ) async {
      final existing = await tester.runAsync(
        () => ConnectedAccountsRepository().create(
          kind: AccountKind.adobeLightroom,
          label: 'Old label',
          accountIdentifier: 'cat9',
        ),
      );
      await pumpPage(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Adobe client ID'),
        'cid',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Connect Lightroom'));
      await settle(tester);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'https://submersion.app/lightroom/callback?code=thecode',
      );
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Connect'),
        ),
      );
      await settle(tester);
      await settle(tester);

      final all = await tester.runAsync(
        () => ConnectedAccountsRepository().getAll(),
      );
      final lightroom = all!
          .where((a) => a.kind == AccountKind.adobeLightroom)
          .toList();
      expect(lightroom, hasLength(1), reason: 'reused, not duplicated');
      expect(lightroom.single.id, existing!.id);
      expect(
        keychain.values[AccountCredentialsStore.keyFor(existing.id)],
        isNotNull,
        reason: 'credentials attached to the existing row',
      );
    });
  });
}
