import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/divelogs/divelogs_credentials.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/import_wizard/data/adapters/divelogs_adapter.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/divelogs_fetch_step.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/test_database.dart';
import '../../../../support/fake_keychain_storage.dart';

void main() {
  final diver = Diver(
    id: 'diver-1',
    name: 'Eric',
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );

  late InMemoryKeychain keychain;
  late AccountCredentialsStore credentialsStore;
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    keychain = InMemoryKeychain();
    credentialsStore = AccountCredentialsStore(storage: keychain);
  });

  tearDown(() => tearDownTestDatabase());

  Widget host(http.Client mockClient) => ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      accountCredentialsStoreProvider.overrideWithValue(credentialsStore),
      divelogsHttpClientProvider.overrideWithValue(mockClient),
      allDiversProvider.overrideWith((ref) async => [diver]),
      currentDiverProvider.overrideWith((ref) async => diver),
    ],
    child: const MaterialApp(
      themeAnimationDuration: Duration.zero,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: DivelogsFetchStep()),
    ),
  );

  MockClient loginThenDives({int loginStatus = 200}) => MockClient((req) async {
    if (req.url.path == '/api/login') {
      return http.Response(
        loginStatus == 200 ? jsonEncode({'bearer_token': 'jwt'}) : '',
        loginStatus,
      );
    }
    if (req.url.path == '/api/dives') {
      return http.Response(jsonEncode([]), 200);
    }
    fail('unexpected request ${req.url}');
  });

  testWidgets('shows sign-in form when no account exists', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(host(loginThenDives()));
      await tester.pumpAndSettle();
    });

    expect(find.text('Sign in to divelogs.de'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });

  testWidgets('failed login shows error and creates no account', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(host(loginThenDives(loginStatus: 401)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'eric');
      await tester.enterText(find.byType(TextField).at(1), 'bad');
      await tester.ensureVisible(find.text('Connect'));
      await tester.tap(find.text('Connect'));
      // Real async work (HTTP mock + DB) resolves inside runAsync.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
    });

    expect(
      find.textContaining('rejected the username or password'),
      findsOneWidget,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DivelogsFetchStep)),
    );
    final repo = container.read(connectedAccountsRepositoryProvider);
    expect(await repo.getByKind(AccountKind.divelogs), isNull);
  });

  testWidgets(
    'successful login creates diver-bound account and stores credentials',
    (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(host(loginThenDives()));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, 'eric');
        await tester.enterText(find.byType(TextField).at(1), 'secret');
        await tester.ensureVisible(find.text('Connect'));
        await tester.tap(find.text('Connect'));
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(DivelogsFetchStep)),
        );
        final repo = container.read(connectedAccountsRepositoryProvider);
        final account = await repo.getByKind(AccountKind.divelogs);
        expect(account, isNotNull);
        expect(account!.diverId, 'diver-1');
        expect(account.accountIdentifier, 'eric');

        final blob = DivelogsCredentials.fromJsonString(
          await credentialsStore.read(account.id),
        );
        expect(blob?.username, 'eric');
        expect(blob?.bearerToken, 'jwt');
      });
    },
  );
}
