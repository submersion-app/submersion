import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_registry.dart';
import 'package:submersion/core/services/accounts/adapters/google_photos_account_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/google_photos/google_photos_auth_manager.dart';
import 'package:submersion/core/services/google_photos/google_photos_auth_store.dart';
import 'package:submersion/core/services/google_photos/google_photos_connect.dart';
import 'package:submersion/features/media/presentation/providers/google_photos_providers.dart';
import 'package:submersion/features/settings/presentation/pages/google_photos_settings_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';
import '../../../../support/fake_keychain_storage.dart';

/// A connect step that returns a canned result (or throws) without a
/// browser or a build-time OAuth client. On success it persists the grant
/// to the connect-time store key, exactly as the real flow's
/// `completeAuthorization` does, so `_finishConnect`'s rekey has something
/// to copy.
class _FakeConnect implements GooglePhotosConnect {
  _FakeConnect({
    required this.keychain,
    this.configured = true,
    this.result,
    this.error,
  });

  final InMemoryKeychain keychain;
  final bool configured;
  final GooglePhotosAuthData? result;
  final Object? error;

  @override
  bool get isConfigured => configured;

  @override
  Future<GooglePhotosAuthData> run() async {
    if (error != null) throw error!;
    final auth = result ?? const GooglePhotosAuthData(refreshToken: 'rt');
    await GooglePhotosAuthStore(storage: keychain).save(auth);
    return auth;
  }
}

void main() {
  late InMemoryKeychain keychain;

  setUp(() async {
    await setUpTestDatabase();
    keychain = InMemoryKeychain();
  });

  tearDown(tearDownTestDatabase);

  Widget app({GooglePhotosConnect? connect}) => ProviderScope(
    overrides: [
      accountCredentialsStoreProvider.overrideWithValue(
        AccountCredentialsStore(storage: keychain),
      ),
      // The page clears the connect-time scratch key on disconnect; back it
      // with the in-memory keychain and keep its revoke call off the wire.
      googlePhotosAuthManagerProvider.overrideWithValue(
        GooglePhotosAuthManager(
          store: GooglePhotosAuthStore(storage: keychain),
          httpClient: MockClient((_) async => http.Response('', 200)),
        ),
      ),
      accountProviderRegistryProvider.overrideWithValue(
        AccountProviderRegistry([
          GooglePhotosAccountAdapter(
            authStoreFactory: (key) =>
                GooglePhotosAuthStore(storage: keychain, storageKey: key),
            // The disconnect path revokes over HTTP; keep it off the wire.
            httpClientFactory: () =>
                MockClient((_) async => http.Response('', 200)),
          ),
        ]),
      ),
      if (connect != null)
        googlePhotosConnectProvider.overrideWithValue(connect),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: GooglePhotosSettingsPage(),
    ),
  );

  Future<ConnectedAccount> seedConnected() async {
    final account = await ConnectedAccountsRepository().create(
      kind: AccountKind.googlePhotos,
      label: 'diver@example.com',
    );
    await keychain.write(
      key: AccountCredentialsStore.keyFor(account.id),
      value: '{"refreshToken":"rt","email":"diver@example.com"}',
    );
    return account;
  }

  testWidgets('unconfigured build: connect is disabled and the not-available '
      'note shows', (tester) async {
    await tester.pumpWidget(
      app(connect: _FakeConnect(keychain: keychain, configured: false)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Google Photos is not available in this build.'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Connect Google Photos'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('a successful connect creates the roster row and shows the '
      'connected state', (tester) async {
    await tester.pumpWidget(
      app(
        connect: _FakeConnect(
          keychain: keychain,
          result: const GooglePhotosAuthData(
            refreshToken: 'rt',
            email: 'diver@example.com',
            displayName: 'diver@example.com',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(FilledButton, 'Connect Google Photos'),
    );
    await tester.pumpAndSettle();

    expect(
      await ConnectedAccountsRepository().getByKind(AccountKind.googlePhotos),
      isNotNull,
    );
    expect(find.text('Connected as diver@example.com'), findsOneWidget);
  });

  testWidgets('a failed connect surfaces the error in a snackbar', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        connect: _FakeConnect(
          keychain: keychain,
          error: const GooglePhotosAuthException('sign-in was cancelled'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(FilledButton, 'Connect Google Photos'),
    );
    await tester.pump(); // start the future
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('sign-in was cancelled'), findsOneWidget);
    expect(
      await ConnectedAccountsRepository().getByKind(AccountKind.googlePhotos),
      isNull,
    );
  });

  testWidgets('a synced roster row without local credentials shows '
      '"Reconnect needed"', (tester) async {
    await ConnectedAccountsRepository().create(
      kind: AccountKind.googlePhotos,
      label: 'diver@example.com',
    );

    await tester.pumpWidget(app(connect: _FakeConnect(keychain: keychain)));
    await tester.pumpAndSettle();

    expect(find.text('Reconnect needed'), findsOneWidget);
    expect(find.text('Connect Google Photos'), findsOneWidget);
  });

  testWidgets('a connected account shows its label and a disconnect button', (
    tester,
  ) async {
    await seedConnected();

    await tester.pumpWidget(app(connect: _FakeConnect(keychain: keychain)));
    await tester.pumpAndSettle();

    expect(find.text('Connected as diver@example.com'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Disconnect'), findsOneWidget);
    expect(find.text('Connect Google Photos'), findsNothing);
  });

  testWidgets('confirming the disconnect dialog drops the connection', (
    tester,
  ) async {
    await seedConnected();

    await tester.pumpWidget(app(connect: _FakeConnect(keychain: keychain)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Disconnect'));
    await tester.pumpAndSettle();
    expect(find.text('Disconnect Google Photos?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Disconnect'));
    await tester.pumpAndSettle();

    expect(
      await ConnectedAccountsRepository().getByKind(AccountKind.googlePhotos),
      isNull,
    );
    expect(find.text('Connect Google Photos'), findsOneWidget);
  });

  testWidgets('cancelling the disconnect dialog keeps the connection', (
    tester,
  ) async {
    await seedConnected();

    await tester.pumpWidget(app(connect: _FakeConnect(keychain: keychain)));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Disconnect'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Connected as diver@example.com'), findsOneWidget);
  });
}
