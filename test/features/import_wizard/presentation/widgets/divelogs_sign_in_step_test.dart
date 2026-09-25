import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:submersion/core/services/divelogs/divelogs_api_client.dart';
import 'package:submersion/core/services/divelogs/divelogs_session_store.dart';
import 'package:submersion/features/import_wizard/data/adapters/divelogs_import_adapter.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/divelogs_import_steps.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../support/fake_keychain_storage.dart';

void main() {
  late ProviderContainer container;
  late DivelogsSessionStore store;
  late List<http.Request> requests;
  late int loginStatus;
  late int userStatus;
  late List<DivelogsApiClient?> signedIn;

  setUp(() {
    store = DivelogsSessionStore(storage: InMemoryKeychain());
    requests = [];
    loginStatus = 200;
    userStatus = 200;
    signedIn = [];
    container = ProviderContainer(
      overrides: [
        divelogsSessionStoreProvider.overrideWithValue(store),
        divelogsHttpClientProvider.overrideWithValue(
          MockClient((req) async {
            requests.add(req);
            if (req.url.path == '/api/login') {
              return http.Response(
                jsonEncode({'bearer_token': 'fresh'}),
                loginStatus,
              );
            }
            if (req.url.path == '/api/user') {
              return http.Response('{}', userStatus);
            }
            return http.Response('', 404);
          }),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  /// Lets the step's real async work (keychain, mocked HTTP) finish. The
  /// progress spinner animates forever, so pumpAndSettle alone would never
  /// return while a request is still in flight.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 50; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }
    await tester.pumpAndSettle();
  }

  Future<void> pumpStep(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DivelogsSignInStep(onSignedIn: signedIn.add)),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> signInWith(WidgetTester tester, String user, String pass) async {
    await tester.enterText(find.byType(TextFormField).at(0), user);
    await tester.enterText(find.byType(TextFormField).at(1), pass);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await settle(tester);
  }

  Future<DivelogsSession?> storedSession(WidgetTester tester) =>
      tester.runAsync<DivelogsSession?>(store.load);

  testWidgets('signs in with a username and password', (tester) async {
    await pumpStep(tester);
    expect(find.text('Sign in to divelogs.de'), findsOneWidget);

    await signInWith(tester, 'rainer', 'secret');

    final login = requests.singleWhere((r) => r.url.path == '/api/login');
    expect(login.method, 'POST');
    expect(signedIn.single, isNotNull);
    expect(container.read(divelogsSignedInProvider), isTrue);
    expect(find.text('Signed in as rainer'), findsOneWidget);
    final session = await storedSession(tester);
    expect(session!.username, 'rainer');
    expect(session.token, 'fresh');
  });

  testWidgets('says so when the credentials are rejected', (tester) async {
    loginStatus = 401;
    await pumpStep(tester);

    await signInWith(tester, 'rainer', 'wrong');

    expect(
      find.text('divelogs.de rejected the username or password.'),
      findsOneWidget,
    );
    expect(container.read(divelogsSignedInProvider), isFalse);
    expect(signedIn, isEmpty);
  });

  testWidgets('signs straight in when a cached session still works', (
    tester,
  ) async {
    await tester.runAsync(
      () => store.save(
        const DivelogsSession(username: 'rainer', token: 'cached'),
      ),
    );

    await pumpStep(tester);

    expect(find.text('Signed in as rainer'), findsOneWidget);
    expect(requests.map((r) => r.url.path), ['/api/user']);
    expect(requests.single.headers['Authorization'], 'Bearer cached');
    expect(signedIn.single, isNotNull);
    expect(container.read(divelogsSignedInProvider), isTrue);
  });

  testWidgets('an expired cached session asks again with the name filled', (
    tester,
  ) async {
    userStatus = 401;
    await tester.runAsync(
      () =>
          store.save(const DivelogsSession(username: 'rainer', token: 'stale')),
    );

    await pumpStep(tester);

    expect(find.text('Sign in to divelogs.de'), findsOneWidget);
    final username = tester.widget<TextFormField>(
      find.byType(TextFormField).at(0),
    );
    expect(username.controller!.text, 'rainer');
    expect(find.textContaining('Could not reach'), findsNothing);
    expect(await storedSession(tester), isNull);
    expect(container.read(divelogsSignedInProvider), isFalse);
  });

  testWidgets('sign out forgets the session', (tester) async {
    await tester.runAsync(
      () => store.save(
        const DivelogsSession(username: 'rainer', token: 'cached'),
      ),
    );
    await pumpStep(tester);

    await tester.tap(find.text('Sign out'));
    await settle(tester);

    expect(find.text('Sign in to divelogs.de'), findsOneWidget);
    expect(await storedSession(tester), isNull);
    expect(signedIn.last, isNull);
    expect(container.read(divelogsSignedInProvider), isFalse);
  });
}
