import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_registry.dart';
import 'package:submersion/core/services/accounts/adapters/google_photos_account_adapter.dart';
import 'package:submersion/core/services/google_photos/google_photos_auth_store.dart';
import 'package:submersion/features/settings/presentation/pages/google_photos_settings_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';
import '../../../../support/fake_keychain_storage.dart';

void main() {
  late InMemoryKeychain keychain;

  setUp(() async {
    await setUpTestDatabase();
    keychain = InMemoryKeychain();
  });

  tearDown(tearDownTestDatabase);

  Widget app() => ProviderScope(
    overrides: [
      accountCredentialsStoreProvider.overrideWithValue(
        AccountCredentialsStore(storage: keychain),
      ),
      accountProviderRegistryProvider.overrideWithValue(
        AccountProviderRegistry([
          GooglePhotosAccountAdapter(
            authStoreFactory: (key) =>
                GooglePhotosAuthStore(storage: keychain, storageKey: key),
          ),
        ]),
      ),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: GooglePhotosSettingsPage(),
    ),
  );

  testWidgets('disconnected + unconfigured build: connect is disabled and '
      'the not-available note shows', (tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Connect Google Photos'), findsOneWidget);
    expect(
      find.text('Google Photos is not available in this build.'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Connect Google Photos'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('a connected account shows its label, a disconnect button, '
      'and no connect button', (tester) async {
    final account = await ConnectedAccountsRepository().create(
      kind: AccountKind.googlePhotos,
      label: 'diver@example.com',
    );
    await keychain.write(
      key: AccountCredentialsStore.keyFor(account.id),
      value: '{"refreshToken":"rt","email":"diver@example.com"}',
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('Connected as diver@example.com'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Disconnect'), findsOneWidget);
    expect(find.text('Connect Google Photos'), findsNothing);
  });

  testWidgets('tapping Disconnect opens a confirm dialog; Cancel keeps the '
      'connection', (tester) async {
    final account = await ConnectedAccountsRepository().create(
      kind: AccountKind.googlePhotos,
      label: 'diver@example.com',
    );
    await keychain.write(
      key: AccountCredentialsStore.keyFor(account.id),
      value: '{"refreshToken":"rt"}',
    );

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Disconnect'));
    await tester.pumpAndSettle();
    expect(find.text('Disconnect Google Photos?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Disconnect Google Photos?'), findsNothing);
    expect(find.text('Connected as diver@example.com'), findsOneWidget);
    // The teardown (adapter.disconnect makes a real revoke call the confirm
    // path would trigger) covers only the confirmed branch, which the
    // adapter's own test exercises; Cancel must not touch the connection.
  });
}
