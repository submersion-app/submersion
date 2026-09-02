import 'dart:async';
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

  /// When set, [login] awaits this before resolving, so a test can observe
  /// the in-flight "signing in" state.
  Completer<void>? gate;

  @override
  Future<String> login(String email, String password) async {
    loggedInEmail = email;
    loggedInPassword = password;
    if (gate != null) await gate!.future;
    final error = loginError;
    if (error != null) throw error;
    sessionKey = 'session-for-$email';
    return sessionKey!;
  }

  @override
  Future<bool> verifySession() async => sessionValid;

  /// The pages [fetchDivePage] serves, in order. Empty pages are dropped:
  /// the real client walks past dive-less listing pages internally, so a
  /// page it hands back is either non-empty or the end of the history.
  List<List<SuuntoWorkoutSummary>> get pages =>
      [workouts].where((page) => page.isNotEmpty).toList();

  /// Every `offset` [fetchDivePage] has been asked for, so a test can assert
  /// a retry re-requests the page that failed rather than skipping it.
  final List<int> requestedPageOffsets = [];

  /// `offset` is used as a plain page index here. The fake owns both sides
  /// of the cursor, so counting pages reads more clearly than mimicking the
  /// server's item offsets.
  @override
  Future<SuuntoDivePage> fetchDivePage({
    int sinceMs = 0,
    int offset = 0,
    int pageSize = 100,
  }) async {
    requestedPageOffsets.add(offset);
    final error = listError;
    if (error != null) throw error;
    return _pageAt(offset);
  }

  SuuntoDivePage _pageAt(int offset) {
    final all = pages;
    if (offset >= all.length) {
      return SuuntoDivePage(
        dives: const [],
        nextOffset: offset,
        hasMore: false,
      );
    }
    // Always reports "there may be more", the way a full listing page does.
    // The end of the history is only learned from the empty page past the
    // last one, which is what the real client does too.
    return SuuntoDivePage(
      dives: all[offset],
      nextOffset: offset + 1,
      hasMore: true,
    );
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

/// Yields its dives across two separate pages instead of one, the shape a
/// large account's paginated workout list has.
class _MultiPageClient extends _FakeCloudClient {
  _MultiPageClient({
    required List<SuuntoWorkoutSummary> page1,
    required this.page2,
    required super.smlByKey,
  }) : super(workouts: page1);

  final List<SuuntoWorkoutSummary> page2;

  /// When set, held open right before serving [page2] -- lets a test
  /// observe the "Load More" in-flight state instead of it resolving
  /// before the test can pump a frame to see it.
  Completer<void>? secondPageGate;

  @override
  List<List<SuuntoWorkoutSummary>> get pages =>
      [workouts, page2].where((page) => page.isNotEmpty).toList();

  @override
  Future<SuuntoDivePage> fetchDivePage({
    int sinceMs = 0,
    int offset = 0,
    int pageSize = 100,
  }) async {
    if (offset > 0 && secondPageGate != null) await secondPageGate!.future;
    return super.fetchDivePage(
      sinceMs: sinceMs,
      offset: offset,
      pageSize: pageSize,
    );
  }
}

/// Succeeds on the first page, then throws when asked for a second one --
/// the shape a transient network error has when the diver taps Load More.
class _FailingSecondPageClient extends _FakeCloudClient {
  _FailingSecondPageClient({
    required List<SuuntoWorkoutSummary> page1,
    required super.smlByKey,
    Object? error,
  }) : error = error ?? const SuuntoApiException('page 2 blew up'),
       super(workouts: page1);

  final Object error;

  @override
  Future<SuuntoDivePage> fetchDivePage({
    int sinceMs = 0,
    int offset = 0,
    int pageSize = 100,
  }) async {
    requestedPageOffsets.add(offset);
    if (offset > 0) throw error;
    return _pageAt(offset);
  }
}

/// Fails the *second* page exactly once, then serves it -- the shape a
/// transient network error has when the diver taps Load More and then tries
/// again. The real client's page cursor has to survive the throw for the
/// retry to reach the same page rather than falling off the end of the
/// history.
class _RecoveringSecondPageClient extends _FakeCloudClient {
  _RecoveringSecondPageClient({
    required List<SuuntoWorkoutSummary> page1,
    required this.page2,
    required super.smlByKey,
  }) : super(workouts: page1);

  final List<SuuntoWorkoutSummary> page2;

  bool _hasFailed = false;

  @override
  List<List<SuuntoWorkoutSummary>> get pages =>
      [workouts, page2].where((page) => page.isNotEmpty).toList();

  @override
  Future<SuuntoDivePage> fetchDivePage({
    int sinceMs = 0,
    int offset = 0,
    int pageSize = 100,
  }) async {
    requestedPageOffsets.add(offset);
    if (offset > 0 && !_hasFailed) {
      _hasFailed = true;
      throw const SuuntoApiException('page 2 blew up');
    }
    return _pageAt(offset);
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

    testWidgets('submits the sign-in form on keyboard done from the password '
        'field', (tester) async {
      final store = _FakeSessionStore();
      final client = _FakeCloudClient();

      await tester.pumpWidget(
        _host(
          store: store,
          clientFactory: () => client,
          child: SuuntoCloudSignInStep(onSignedIn: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'a@b.c');
      await tester.enterText(find.byType(TextFormField).last, 'pw');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(client.loggedInEmail, 'a@b.c');
      expect(find.text('Signed in as a@b.c'), findsOneWidget);
    });

    testWidgets('shows a signing-in spinner while login is in flight', (
      tester,
    ) async {
      final client = _FakeCloudClient()..gate = Completer<void>();

      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: () => client,
          child: SuuntoCloudSignInStep(onSignedIn: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'a@b.c');
      await tester.enterText(find.byType(TextFormField).last, 'pw');
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(find.text('Signing in…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      client.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Signed in as a@b.c'), findsOneWidget);
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

    testWidgets(
      'stops after the first page and lets Load More fetch the rest',
      (tester) async {
        final client = _MultiPageClient(
          page1: [_workout('w1')],
          page2: [_workout('w2')],
          smlByKey: {'w1': _diveJson(), 'w2': _diveJson()},
        );
        List<SuuntoParsedDive>? fetched;
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
                  onDivesFetched: (dives) => fetched = dives,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Only the newest page has been fetched; the diver can already
        // advance without waiting for the rest.
        expect(client.fetchedKeys, ['w1']);
        expect(fetched, hasLength(1));
        expect(find.text('Found 1 dive'), findsOneWidget);
        expect(container.read(suuntoCloudDivesFetchedProvider), isTrue);
        expect(find.text('Load More'), findsOneWidget);

        await tester.tap(find.text('Load More'));
        await tester.pumpAndSettle();

        expect(client.fetchedKeys, ['w1', 'w2']);
        expect(fetched, hasLength(2));
        expect(find.text('Found 2 dives'), findsOneWidget);
        // Exhaustion isn't known until an attempt to load a further page
        // comes back empty, so the button is still offered here...
        expect(find.text('Load More'), findsOneWidget);

        await tester.tap(find.text('Load More'));
        await tester.pumpAndSettle();

        // ...and only disappears once that attempt confirms there's nothing
        // left, without having added or lost any dives.
        expect(client.fetchedKeys, ['w1', 'w2']);
        expect(fetched, hasLength(2));
        expect(find.text('Load More'), findsNothing);
      },
    );

    testWidgets(
      'a Load More failure keeps the dives already fetched instead of '
      'discarding them',
      (tester) async {
        final client = _FailingSecondPageClient(
          page1: [_workout('w1')],
          smlByKey: {'w1': _diveJson()},
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

        expect(find.text('Found 1 dive'), findsOneWidget);

        await tester.tap(find.text('Load More'));
        await tester.pumpAndSettle();

        // The failed page didn't wipe out the dive already fetched, and the
        // Load More button stays put so the diver can try again.
        expect(fetched, hasLength(1));
        expect(find.text('Found 1 dive'), findsOneWidget);
        expect(find.text('page 2 blew up'), findsOneWidget);
        expect(find.text('Load More'), findsOneWidget);
      },
    );

    testWidgets('a non-API Load More failure is surfaced the same way', (
      tester,
    ) async {
      final client = _FailingSecondPageClient(
        page1: [_workout('w1')],
        smlByKey: {'w1': _diveJson()},
        error: StateError('socket died'),
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

      await tester.tap(find.text('Load More'));
      await tester.pumpAndSettle();

      expect(fetched, hasLength(1));
      expect(find.textContaining('socket died'), findsOneWidget);
      expect(find.text('Load More'), findsOneWidget);
    });

    testWidgets(
      'Load More retries the page that failed rather than walking past it',
      (tester) async {
        final client = _RecoveringSecondPageClient(
          page1: [_workout('w1')],
          page2: [_workout('w2')],
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

        await tester.tap(find.text('Load More'));
        await tester.pumpAndSettle();
        expect(find.text('page 2 blew up'), findsOneWidget);

        await tester.tap(find.text('Load More'));
        await tester.pumpAndSettle();

        // The cursor stayed parked on the page that threw, so the retry
        // asked for that same page instead of reporting the history as
        // exhausted and hiding the button.
        expect(client.requestedPageOffsets, [0, 1, 1]);
        expect(fetched, hasLength(2));
        expect(find.text('Found 2 dives'), findsOneWidget);
        expect(find.text('page 2 blew up'), findsNothing);
      },
    );

    testWidgets(
      'shows a spinner and progress text while Load More is in flight',
      (tester) async {
        final client = _MultiPageClient(
          page1: [_workout('w1')],
          page2: [_workout('w2')],
          smlByKey: {'w1': _diveJson(), 'w2': _diveJson()},
        )..secondPageGate = Completer<void>();

        await tester.pumpWidget(
          _host(
            store: _FakeSessionStore(),
            clientFactory: _FakeCloudClient.new,
            child: SuuntoCloudFetchStep(client: client, onDivesFetched: (_) {}),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Load More'));
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        client.secondPageGate!.complete();
        await tester.pumpAndSettle();

        expect(find.text('Found 2 dives'), findsOneWidget);
      },
    );
  });

  group('SuuntoCloudFetchStep failures', () {
    // suuntoCloudDivesFetchedProvider is this step's canAdvance, so a
    // first-page failure must leave it false -- otherwise the wizard's Next
    // button would let the diver proceed into an empty review page with no
    // indication anything went wrong.
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
  Future<SuuntoDivePage> fetchDivePage({
    int sinceMs = 0,
    int offset = 0,
    int pageSize = 100,
  }) async {
    attempts++;
    requestedPageOffsets.add(offset);
    if (attempts == 1) throw const SuuntoApiException('temporary failure');
    return _pageAt(offset);
  }
}
