import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/suunto_cloud/suunto_api_exception.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_cloud_client.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_parser.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_session_store.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_cloud_adapter.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/suunto_cloud_adapter_steps.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// ---------------------------------------------------------------------------
// Fakes -- nothing here may reach the platform keychain or the network.
// ---------------------------------------------------------------------------

class _FakeSessionStore extends SuuntoSessionStore {
  _FakeSessionStore({this.stored});

  SuuntoSessionData? stored;
  SuuntoSessionData? saved;
  int loadCount = 0;

  @override
  Future<SuuntoSessionData?> load() async {
    loadCount++;
    return stored;
  }

  @override
  Future<void> save(SuuntoSessionData data) async {
    saved = data;
    stored = data;
  }

  @override
  Future<void> clear() async => stored = null;
}

class _FakeCloudClient extends SuuntoCloudClient {
  _FakeCloudClient({
    this.sessionValid = true,
    this.loginError,
    this.listError,
    this.workouts = const [],
    this.smlByKey = const {},
    this.failKeys = const {},
  });

  final bool sessionValid;
  final Object? loginError;
  final Object? listError;
  final List<SuuntoWorkoutSummary> workouts;
  final Map<String, Map<String, dynamic>> smlByKey;
  final Set<String> failKeys;

  String? loggedInEmail;
  String? loggedInPassword;
  final List<String> fetchedKeys = [];

  @override
  Future<String> login(String email, String password) async {
    loggedInEmail = email;
    loggedInPassword = password;
    final error = loginError;
    if (error != null) throw error;
    sessionKey = 'session-for-$email';
    return sessionKey!;
  }

  @override
  Future<bool> verifySession() async => sessionValid;

  @override
  Future<List<SuuntoWorkoutSummary>> listDives({int sinceMs = 0}) async {
    final error = listError;
    if (error != null) throw error;
    return workouts;
  }

  @override
  Future<Uint8List> fetchSmlJson(String key) async {
    fetchedKeys.add(key);
    if (failKeys.contains(key)) {
      throw const SuuntoApiException('fetch blew up');
    }
    return Uint8List.fromList(utf8.encode(jsonEncode(smlByKey[key])));
  }
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

SuuntoWorkoutSummary _workout(String key) => SuuntoWorkoutSummary(
  key: key,
  startTime: DateTime.utc(2026, 5, 1, 10),
  activityId: 78,
);

/// A minimal app-export ("DeviceLog") shaped dive the normalizer accepts.
Map<String, dynamic> _diveJson({String device = 'Porvoo'}) => {
  'DeviceLog': {
    'Header': {
      'DateTime': '2026-05-01T10:00:00+02:00',
      'ActivityType': 51,
      'Device': {'Name': device, 'SerialNumber': 'SN-1'},
      'Depth': {'Max': 18.5},
      'DiveTime': 1800,
    },
    'Samples': [
      {
        'TimeISO8601': '2026-05-01T10:00:00+02:00',
        'Depth': 1.0,
        'DiveEvents': {'DiveStatus': true},
      },
      {'TimeISO8601': '2026-05-01T10:00:10+02:00', 'Depth': 8.0},
    ],
  },
};

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Widget _host({
  required Widget child,
  required _FakeSessionStore store,
  required SuuntoCloudClient Function() clientFactory,
}) {
  return ProviderScope(
    overrides: [
      suuntoSessionStoreProvider.overrideWithValue(store),
      suuntoCloudClientFactoryProvider.overrideWithValue(clientFactory),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('SuuntoCloudSignInStep', () {
    testWidgets('signs straight in when a cached session still verifies', (
      tester,
    ) async {
      final store = _FakeSessionStore(
        stored: const SuuntoSessionData(
          email: 'diver@example.com',
          sessionKey: 'cached-key',
        ),
      );
      final client = _FakeCloudClient();
      SuuntoCloudClient? signedInWith;

      await tester.pumpWidget(
        _host(
          store: store,
          clientFactory: () => client,
          child: SuuntoCloudSignInStep(onSignedIn: (c) => signedInWith = c),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Signed in as diver@example.com'), findsOneWidget);
      expect(signedInWith, same(client));
      expect(client.sessionKey, 'cached-key');
      // The cached fast path must not re-prompt for a password.
      expect(find.text('Sign In'), findsNothing);
    });

    testWidgets('falls back to the form when the cached session is stale', (
      tester,
    ) async {
      final store = _FakeSessionStore(
        stored: const SuuntoSessionData(
          email: 'diver@example.com',
          sessionKey: 'expired-key',
        ),
      );

      await tester.pumpWidget(
        _host(
          store: store,
          clientFactory: () => _FakeCloudClient(sessionValid: false),
          child: SuuntoCloudSignInStep(onSignedIn: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in to Suunto'), findsOneWidget);
      // The known email is prefilled so only the password has to be retyped.
      expect(find.text('diver@example.com'), findsOneWidget);
    });

    testWidgets('falls back to the form when verifySession throws', (
      tester,
    ) async {
      final store = _FakeSessionStore(
        stored: const SuuntoSessionData(email: 'a@b.c', sessionKey: 'k'),
      );

      await tester.pumpWidget(
        _host(
          store: store,
          clientFactory: _ThrowingVerifyClient.new,
          child: SuuntoCloudSignInStep(onSignedIn: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in to Suunto'), findsOneWidget);
    });

    testWidgets('shows the form when nothing is cached', (tester) async {
      final store = _FakeSessionStore();

      await tester.pumpWidget(
        _host(
          store: store,
          clientFactory: _FakeCloudClient.new,
          child: SuuntoCloudSignInStep(onSignedIn: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(store.loadCount, 1);
      expect(find.text('Sign in to Suunto'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('validates that email and password are both present', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: _FakeCloudClient.new,
          child: SuuntoCloudSignInStep(onSignedIn: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('caches only the session token on a successful login', (
      tester,
    ) async {
      final store = _FakeSessionStore();
      final client = _FakeCloudClient();
      SuuntoCloudClient? signedInWith;

      await tester.pumpWidget(
        _host(
          store: store,
          clientFactory: () => client,
          child: SuuntoCloudSignInStep(onSignedIn: (c) => signedInWith = c),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        '  diver@example.com  ',
      );
      await tester.enterText(find.byType(TextFormField).last, 'hunter2');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      // The email is trimmed before it reaches the API.
      expect(client.loggedInEmail, 'diver@example.com');
      expect(signedInWith, same(client));
      expect(store.saved?.email, 'diver@example.com');
      expect(store.saved?.sessionKey, 'session-for-diver@example.com');
      // The password itself is never persisted.
      expect(jsonEncode(store.saved!.toJson()), isNot(contains('hunter2')));
      expect(find.text('Signed in as diver@example.com'), findsOneWidget);
    });

    testWidgets('surfaces an API error without leaving the form', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: () => _FakeCloudClient(
            loginError: const SuuntoApiException('login rejected'),
          ),
          child: SuuntoCloudSignInStep(onSignedIn: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'a@b.c');
      await tester.enterText(find.byType(TextFormField).last, 'pw');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('login rejected'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('surfaces a non-API error too', (tester) async {
      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: () =>
              _FakeCloudClient(loginError: StateError('socket died')),
          child: SuuntoCloudSignInStep(onSignedIn: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'a@b.c');
      await tester.enterText(find.byType(TextFormField).last, 'pw');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.textContaining('socket died'), findsOneWidget);
    });

    testWidgets('toggles password visibility', (tester) async {
      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: _FakeCloudClient.new,
          child: SuuntoCloudSignInStep(onSignedIn: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });
  });

  group('SuuntoCloudFetchStep', () {
    testWidgets('fetches, converts and reports every listed dive', (
      tester,
    ) async {
      final client = _FakeCloudClient(
        workouts: [_workout('w1'), _workout('w2')],
        smlByKey: {'w1': _diveJson(), 'w2': _diveJson()},
      );
      List<SuuntoParsedDive>? fetched;

      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: _FakeCloudClient.new,
          child: SuuntoCloudFetchStep(
            client: client,
            onDivesFetched: (dives) => fetched = dives,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(client.fetchedKeys, ['w1', 'w2']);
      expect(fetched, hasLength(2));
      expect(find.text('Found 2 dives'), findsOneWidget);
      // The offset in the fixture must survive as the wall clock.
      expect(fetched!.first.dive.startTime, DateTime.utc(2026, 5, 1, 10));
    });

    testWidgets('skips a single unreadable dive rather than aborting', (
      tester,
    ) async {
      final client = _FakeCloudClient(
        workouts: [_workout('good'), _workout('bad')],
        smlByKey: {'good': _diveJson()},
        failKeys: {'bad'},
      );
      List<SuuntoParsedDive>? fetched;

      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: _FakeCloudClient.new,
          child: SuuntoCloudFetchStep(
            client: client,
            onDivesFetched: (dives) => fetched = dives,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(fetched, hasLength(1));
      expect(find.text('Found 1 dive'), findsOneWidget);
      expect(
        find.text('1 dive could not be converted and was skipped.'),
        findsOneWidget,
      );
    });

    testWidgets('reports an empty account without an error', (tester) async {
      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: _FakeCloudClient.new,
          child: SuuntoCloudFetchStep(
            client: _FakeCloudClient(),
            onDivesFetched: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No dives found'), findsOneWidget);
      expect(find.text('Could not fetch dives'), findsNothing);
    });
  });

  group('SuuntoCloudFetchStep failures', () {
    // The step is declared autoAdvance: true against
    // suuntoCloudDivesFetchedProvider, so leaving that provider false on a
    // failure is the only thing keeping the wizard from sailing past the
    // error into an empty review page.
    Future<ProviderContainer> pumpFailing(
      WidgetTester tester, {
      required SuuntoCloudClient? client,
    }) async {
      final container = ProviderContainer(
        overrides: [
          suuntoSessionStoreProvider.overrideWithValue(_FakeSessionStore()),
          suuntoCloudClientFactoryProvider.overrideWithValue(
            _FakeCloudClient.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SuuntoCloudFetchStep(
                client: client,
                onDivesFetched: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('an API failure shows the error and blocks auto-advance', (
      tester,
    ) async {
      final container = await pumpFailing(
        tester,
        client: _FakeCloudClient(
          listError: const SuuntoApiException('session rejected'),
        ),
      );

      expect(find.text('Could not fetch dives'), findsOneWidget);
      expect(find.text('session rejected'), findsOneWidget);
      expect(container.read(suuntoCloudDivesFetchedProvider), isFalse);
    });

    testWidgets('an unexpected failure also blocks auto-advance', (
      tester,
    ) async {
      final container = await pumpFailing(
        tester,
        client: _FakeCloudClient(listError: StateError('offline')),
      );

      expect(find.text('Could not fetch dives'), findsOneWidget);
      expect(container.read(suuntoCloudDivesFetchedProvider), isFalse);
    });

    testWidgets('a missing client blocks auto-advance', (tester) async {
      final container = await pumpFailing(tester, client: null);

      expect(find.text('Could not fetch dives'), findsOneWidget);
      expect(container.read(suuntoCloudDivesFetchedProvider), isFalse);
    });

    testWidgets('Try Again re-runs the fetch and can then advance', (
      tester,
    ) async {
      final client = _RecoveringClient(
        workouts: [_workout('w1')],
        smlByKey: {'w1': _diveJson()},
      );
      final container = ProviderContainer(
        overrides: [
          suuntoSessionStoreProvider.overrideWithValue(_FakeSessionStore()),
          suuntoCloudClientFactoryProvider.overrideWithValue(
            _FakeCloudClient.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SuuntoCloudFetchStep(
                client: client,
                onDivesFetched: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not fetch dives'), findsOneWidget);
      expect(container.read(suuntoCloudDivesFetchedProvider), isFalse);

      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(find.text('Found 1 dive'), findsOneWidget);
      expect(container.read(suuntoCloudDivesFetchedProvider), isTrue);
    });
  });
}

class _ThrowingVerifyClient extends _FakeCloudClient {
  @override
  Future<bool> verifySession() async => throw const SuuntoApiException('boom');
}

/// Fails the first listing, succeeds on every later one -- the shape a
/// transient network error has when the diver taps Try Again.
class _RecoveringClient extends _FakeCloudClient {
  _RecoveringClient({required super.workouts, required super.smlByKey});

  int attempts = 0;

  @override
  Future<List<SuuntoWorkoutSummary>> listDives({int sinceMs = 0}) async {
    attempts++;
    if (attempts == 1) throw const SuuntoApiException('temporary failure');
    return workouts;
  }
}
