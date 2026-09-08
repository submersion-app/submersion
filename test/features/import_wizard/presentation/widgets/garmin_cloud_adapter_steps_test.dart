import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/services/garmin_connect/garmin_api_exception.dart';
import 'package:submersion/core/services/garmin_connect/garmin_auth_tokens.dart';
import 'package:submersion/core/services/garmin_connect/garmin_connect_client.dart';
import 'package:submersion/core/services/garmin_connect/garmin_dive_mapper.dart';
import 'package:submersion/core/services/garmin_connect/garmin_session_store.dart';
import 'package:submersion/features/import_wizard/data/adapters/garmin_cloud_adapter.dart';
import 'package:submersion/features/import_wizard/domain/cloud_import_paging.dart';
import 'package:submersion/features/import_wizard/presentation/providers/cloud_import_page_size_provider.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/garmin_cloud_adapter_steps.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

// ---------------------------------------------------------------------------
// Fakes -- nothing here may reach the platform keychain or the network.
// ---------------------------------------------------------------------------

class _FakeSessionStore extends GarminSessionStore {
  _FakeSessionStore({this.stored});

  GarminSessionData? stored;
  GarminSessionData? saved;
  int loadCount = 0;

  @override
  Future<GarminSessionData?> load() async {
    loadCount++;
    return stored;
  }

  @override
  Future<void> save(GarminSessionData data) async {
    saved = data;
    stored = data;
  }

  @override
  Future<void> clear() async => stored = null;
}

class _FakeGarminClient extends GarminConnectClient {
  _FakeGarminClient({
    this.mfaRequired = false,
    this.mfaMethod = 'email',
    this.loginError,
    this.mfaError,
    this.restoreError,
    this.listError,
    this.dives = const [],
    this.fitBytesByActivityId = const {},
    this.failActivityIds = const {},
  });

  final bool mfaRequired;
  final String mfaMethod;
  final Object? loginError;
  final Object? mfaError;
  final Object? restoreError;
  final Object? listError;
  final List<GarminActivitySummary> dives;
  final Map<int, Uint8List> fitBytesByActivityId;
  final Set<int> failActivityIds;

  GarminOAuth1Token? _token;
  String? loggedInEmail;
  String? loggedInPassword;
  String? submittedCode;
  final List<int> fetchedActivityIds = [];

  /// When set, [login]/[submitMfaCode] await this before resolving, so a
  /// test can observe the in-flight "signing in"/"verifying" state.
  Completer<void>? gate;

  @override
  GarminOAuth1Token? get oauth1Token => _token;

  @override
  bool get hasSession => _token != null;

  @override
  Future<void> restoreSession(GarminOAuth1Token token) async {
    final error = restoreError;
    if (error != null) throw error;
    _token = token;
  }

  @override
  Future<GarminLoginResult> login(String email, String password) async {
    loggedInEmail = email;
    loggedInPassword = password;
    if (gate != null) await gate!.future;
    final error = loginError;
    if (error != null) throw error;
    if (mfaRequired) {
      return GarminLoginResult.needsMfa(mfaMethod);
    }
    _token = const GarminOAuth1Token(token: 'tok', tokenSecret: 'sec');
    return const GarminLoginResult.success();
  }

  @override
  Future<void> submitMfaCode(String code, {String mfaMethod = 'email'}) async {
    submittedCode = code;
    if (gate != null) await gate!.future;
    final error = mfaError;
    if (error != null) throw error;
    _token = const GarminOAuth1Token(token: 'tok', tokenSecret: 'sec');
  }

  /// The pages [fetchDivePage] serves, in order. Empty pages are dropped:
  /// the real client walks past dive-less listing pages internally, so a
  /// page it hands back is either non-empty or the end of the history.
  List<List<GarminActivitySummary>> get pages =>
      [dives].where((page) => page.isNotEmpty).toList();

  /// Every `start` [fetchDivePage] has been asked for, so a test can assert
  /// a retry re-requests the page that failed rather than skipping it.
  final List<int> requestedPageStarts = [];

  /// Every `pageSize` [fetchDivePage] has been asked for, so a test can
  /// assert the fetch step honours the cloud-import page-size setting.
  final List<int> requestedPageSizes = [];

  /// `start` is used as a plain page index here. The fake owns both sides of
  /// the cursor, so counting pages reads more clearly than mimicking
  /// Garmin's item offsets.
  @override
  Future<GarminDivePage> fetchDivePage({
    int start = 0,
    int pageSize = 100,
  }) async {
    requestedPageStarts.add(start);
    requestedPageSizes.add(pageSize);
    final error = listError;
    if (error != null) throw error;
    return _pageAt(start);
  }

  GarminDivePage _pageAt(int start) {
    final all = pages;
    if (start >= all.length) {
      return GarminDivePage(dives: const [], nextStart: start, hasMore: false);
    }
    // Always reports "there may be more", the way a full listing page does.
    // The end of the history is only learned from the empty page past the
    // last one, which is what the real client does too.
    return GarminDivePage(
      dives: all[start],
      nextStart: start + 1,
      hasMore: true,
    );
  }

  @override
  Future<Uint8List> downloadActivityFit(int activityId) async {
    fetchedActivityIds.add(activityId);
    if (failActivityIds.contains(activityId)) {
      throw const GarminApiException('fetch blew up');
    }
    return fitBytesByActivityId[activityId] ?? Uint8List(0);
  }
}

/// Yields its dives across two separate pages instead of one, the shape a
/// large account's paginated activity list has.
class _MultiPageClient extends _FakeGarminClient {
  _MultiPageClient({
    required List<GarminActivitySummary> page1,
    required this.page2,
    required super.fitBytesByActivityId,
  }) : super(dives: page1);

  final List<GarminActivitySummary> page2;

  /// When set, held open right before serving [page2] -- lets a test
  /// observe the "Load More"/"Fetch All" in-flight state instead of it
  /// resolving before the test can pump a frame to see it.
  Completer<void>? secondPageGate;

  @override
  List<List<GarminActivitySummary>> get pages =>
      [dives, page2].where((page) => page.isNotEmpty).toList();

  @override
  Future<GarminDivePage> fetchDivePage({
    int start = 0,
    int pageSize = 100,
  }) async {
    if (start > 0 && secondPageGate != null) await secondPageGate!.future;
    return super.fetchDivePage(start: start, pageSize: pageSize);
  }
}

/// Succeeds on the first page, then throws when asked for a second one --
/// the shape a transient network error has when the diver taps Load More.
class _FailingSecondPageClient extends _FakeGarminClient {
  _FailingSecondPageClient({
    required List<GarminActivitySummary> page1,
    required super.fitBytesByActivityId,
    Object? error,
  }) : error = error ?? const GarminApiException('page 2 blew up'),
       super(dives: page1);

  final Object error;

  @override
  Future<GarminDivePage> fetchDivePage({
    int start = 0,
    int pageSize = 100,
  }) async {
    requestedPageStarts.add(start);
    requestedPageSizes.add(pageSize);
    if (start > 0) throw error;
    return _pageAt(start);
  }
}

/// Fails the *second* page exactly once, then serves it -- the shape a
/// transient network error has when the diver taps Load More and then tries
/// again. The real client's page cursor has to survive the throw for the
/// retry to reach the same page rather than falling off the end of the
/// history.
class _RecoveringSecondPageClient extends _FakeGarminClient {
  _RecoveringSecondPageClient({
    required List<GarminActivitySummary> page1,
    required this.page2,
    required super.fitBytesByActivityId,
  }) : super(dives: page1);

  final List<GarminActivitySummary> page2;

  bool _hasFailed = false;

  @override
  List<List<GarminActivitySummary>> get pages =>
      [dives, page2].where((page) => page.isNotEmpty).toList();

  @override
  Future<GarminDivePage> fetchDivePage({
    int start = 0,
    int pageSize = 100,
  }) async {
    requestedPageStarts.add(start);
    requestedPageSizes.add(pageSize);
    if (start > 0 && !_hasFailed) {
      _hasFailed = true;
      throw const GarminApiException('page 2 blew up');
    }
    return _pageAt(start);
  }
}

/// Lets a test hold each `downloadActivityFit` call open until it explicitly
/// completes it, so concurrency can be observed instead of inferred.
class _ControllableClient extends _FakeGarminClient {
  _ControllableClient({required super.dives});

  final Map<int, Completer<Uint8List>> _pending = {};

  @override
  Future<Uint8List> downloadActivityFit(int activityId) {
    fetchedActivityIds.add(activityId);
    final completer = Completer<Uint8List>();
    _pending[activityId] = completer;
    return completer.future;
  }

  void complete(int activityId, Uint8List bytes) {
    _pending[activityId]!.complete(bytes);
  }
}

/// Fails the first listing, succeeds on every later one -- the shape a
/// transient network error has when the diver taps Try Again.
class _RecoveringClient extends _FakeGarminClient {
  _RecoveringClient({
    required super.dives,
    required super.fitBytesByActivityId,
  });

  int attempts = 0;

  @override
  Future<GarminDivePage> fetchDivePage({
    int start = 0,
    int pageSize = 100,
  }) async {
    attempts++;
    requestedPageStarts.add(start);
    requestedPageSizes.add(pageSize);
    if (attempts == 1) throw const GarminApiException('temporary failure');
    return _pageAt(start);
  }
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const _fitFixturePath = 'test/dives/005_oc-trimix-two-deco-gases.fit';

GarminActivitySummary _activity(int id) => GarminActivitySummary(
  activityId: id,
  startTime: DateTime.utc(2026, 5, 1, 10),
  activityType: 'single_gas_diving',
);

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Widget _host({
  required Widget child,
  required _FakeSessionStore store,
  required GarminConnectClient Function() clientFactory,
}) {
  return ProviderScope(
    overrides: [
      garminSessionStoreProvider.overrideWithValue(store),
      garminConnectClientFactoryProvider.overrideWithValue(clientFactory),
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
  late Uint8List fitBytes;

  setUpAll(() {
    fitBytes = File(_fitFixturePath).readAsBytesSync();
  });

  group('GarminCloudSignInStep', () {
    testWidgets('signs straight in when a cached session still restores', (
      tester,
    ) async {
      final store = _FakeSessionStore(
        stored: const GarminSessionData(
          email: 'diver@example.com',
          token: GarminOAuth1Token(token: 'cached', tokenSecret: 'secret'),
        ),
      );
      final client = _FakeGarminClient();
      GarminConnectClient? signedInWith;

      await tester.pumpWidget(
        _host(
          store: store,
          clientFactory: () => client,
          child: GarminCloudSignInStep(onSignedIn: (c) => signedInWith = c),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Signed in as diver@example.com'), findsOneWidget);
      expect(signedInWith, same(client));
      expect(client.oauth1Token?.token, 'cached');
      // The cached fast path must not re-prompt for a password.
      expect(find.text('Sign In'), findsNothing);
    });

    testWidgets('falls back to the form when restoring a stale token fails', (
      tester,
    ) async {
      final store = _FakeSessionStore(
        stored: const GarminSessionData(
          email: 'diver@example.com',
          token: GarminOAuth1Token(token: 'expired', tokenSecret: 'secret'),
        ),
      );

      await tester.pumpWidget(
        _host(
          store: store,
          clientFactory: () =>
              _FakeGarminClient(restoreError: const GarminApiException('no')),
          child: GarminCloudSignInStep(onSignedIn: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in to Garmin Connect'), findsOneWidget);
      // The known email is prefilled so only the password has to be retyped.
      expect(find.text('diver@example.com'), findsOneWidget);
    });

    testWidgets('shows the form when nothing is cached', (tester) async {
      final store = _FakeSessionStore();

      await tester.pumpWidget(
        _host(
          store: store,
          clientFactory: _FakeGarminClient.new,
          child: GarminCloudSignInStep(onSignedIn: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(store.loadCount, 1);
      expect(find.text('Sign in to Garmin Connect'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('validates that email and password are both present', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: _FakeGarminClient.new,
          child: GarminCloudSignInStep(onSignedIn: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('caches only the token on a successful login', (tester) async {
      final store = _FakeSessionStore();
      final client = _FakeGarminClient();
      GarminConnectClient? signedInWith;

      await tester.pumpWidget(
        _host(
          store: store,
          clientFactory: () => client,
          child: GarminCloudSignInStep(onSignedIn: (c) => signedInWith = c),
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
      expect(store.saved?.token.token, 'tok');
      // The password itself is never persisted.
      expect(store.saved!.toJson().values, isNot(contains('hunter2')));
      expect(find.text('Signed in as diver@example.com'), findsOneWidget);
    });

    testWidgets('shows an MFA form and completes sign-in after a good code', (
      tester,
    ) async {
      final store = _FakeSessionStore();
      final client = _FakeGarminClient(mfaRequired: true, mfaMethod: 'sms');
      GarminConnectClient? signedInWith;

      await tester.pumpWidget(
        _host(
          store: store,
          clientFactory: () => client,
          child: GarminCloudSignInStep(onSignedIn: (c) => signedInWith = c),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'a@b.c');
      await tester.enterText(find.byType(TextFormField).last, 'pw');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Verification Required'), findsOneWidget);
      expect(
        find.text('Enter the verification code sent to your sms.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(client.submittedCode, '123456');
      expect(signedInWith, same(client));
      expect(store.saved?.token.token, 'tok');
      expect(find.text('Signed in as a@b.c'), findsOneWidget);
    });

    testWidgets('submits the MFA code on keyboard done, not just the button', (
      tester,
    ) async {
      final client = _FakeGarminClient(mfaRequired: true);

      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: () => client,
          child: GarminCloudSignInStep(onSignedIn: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'a@b.c');
      await tester.enterText(find.byType(TextFormField).last, 'pw');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '123456');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(client.submittedCode, '123456');
      expect(find.text('Signed in as a@b.c'), findsOneWidget);
    });

    testWidgets('requires a verification code before submitting', (
      tester,
    ) async {
      final client = _FakeGarminClient(mfaRequired: true);

      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: () => client,
          child: GarminCloudSignInStep(onSignedIn: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'a@b.c');
      await tester.enterText(find.byType(TextFormField).last, 'pw');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(client.submittedCode, isNull);
      expect(find.text('Verification code is required'), findsOneWidget);
    });

    testWidgets('surfaces an invalid MFA code without losing the form', (
      tester,
    ) async {
      final client = _FakeGarminClient(
        mfaRequired: true,
        mfaError: const GarminApiException('code rejected'),
      );

      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: () => client,
          child: GarminCloudSignInStep(onSignedIn: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'a@b.c');
      await tester.enterText(find.byType(TextFormField).last, 'pw');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '000000');
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(find.text('code rejected'), findsOneWidget);
      expect(find.text('Verify'), findsOneWidget);
    });

    testWidgets('surfaces a non-API error during MFA submission too', (
      tester,
    ) async {
      final client = _FakeGarminClient(
        mfaRequired: true,
        mfaError: StateError('socket died'),
      );

      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: () => client,
          child: GarminCloudSignInStep(onSignedIn: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'a@b.c');
      await tester.enterText(find.byType(TextFormField).last, 'pw');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '000000');
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(find.textContaining('socket died'), findsOneWidget);
      expect(find.text('Verify'), findsOneWidget);
    });

    testWidgets('surfaces an API error without leaving the form', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: () => _FakeGarminClient(
            loginError: const GarminApiException('login rejected'),
          ),
          child: GarminCloudSignInStep(onSignedIn: (_) {}),
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
              _FakeGarminClient(loginError: StateError('socket died')),
          child: GarminCloudSignInStep(onSignedIn: (_) {}),
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
      final client = _FakeGarminClient();

      await tester.pumpWidget(
        _host(
          store: store,
          clientFactory: () => client,
          child: GarminCloudSignInStep(onSignedIn: (_) {}),
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
      final client = _FakeGarminClient()..gate = Completer<void>();

      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: () => client,
          child: GarminCloudSignInStep(onSignedIn: (_) {}),
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

    testWidgets('shows a verifying spinner while the MFA code is in flight', (
      tester,
    ) async {
      final client = _FakeGarminClient(mfaRequired: true);

      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: () => client,
          child: GarminCloudSignInStep(onSignedIn: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'a@b.c');
      await tester.enterText(find.byType(TextFormField).last, 'pw');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      client.gate = Completer<void>();
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Verify'));
      await tester.pump();

      expect(find.text('Verifying…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      client.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Signed in as a@b.c'), findsOneWidget);
    });

    testWidgets('toggles password visibility', (tester) async {
      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: _FakeGarminClient.new,
          child: GarminCloudSignInStep(onSignedIn: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });
  });

  group('GarminCloudFetchStep', () {
    testWidgets('fetches, converts and reports every listed dive', (
      tester,
    ) async {
      final client = _FakeGarminClient(
        dives: [_activity(1), _activity(2)],
        fitBytesByActivityId: {1: fitBytes, 2: fitBytes},
      );
      List<GarminParsedDive>? fetched;

      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: _FakeGarminClient.new,
          child: GarminCloudFetchStep(
            client: client,
            onDivesFetched: (dives) => fetched = dives,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(client.fetchedActivityIds, [1, 2]);
      expect(fetched, hasLength(2));
      expect(find.text('Found 2 dives'), findsOneWidget);
      expect(client.requestedPageSizes, [CloudImportPaging.defaultPageSize]);
    });

    testWidgets('asks the client for the configured page size', (tester) async {
      final client = _FakeGarminClient(
        dives: [_activity(1)],
        fitBytesByActivityId: {1: fitBytes},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cloudImportPageSizeProvider.overrideWith(
              (ref) => CloudImportPageSizeNotifier(initial: 7),
            ),
          ],
          child: _host(
            store: _FakeSessionStore(),
            clientFactory: _FakeGarminClient.new,
            child: GarminCloudFetchStep(client: client, onDivesFetched: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(client.requestedPageSizes, [7]);
    });

    testWidgets(
      'stops after the first page and lets Load More fetch the rest',
      (tester) async {
        final client = _MultiPageClient(
          page1: [_activity(1)],
          page2: [_activity(2)],
          fitBytesByActivityId: {1: fitBytes, 2: fitBytes},
        );
        List<GarminParsedDive>? fetched;
        final container = ProviderContainer(
          overrides: [
            garminSessionStoreProvider.overrideWithValue(_FakeSessionStore()),
            garminConnectClientFactoryProvider.overrideWithValue(
              _FakeGarminClient.new,
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
                body: GarminCloudFetchStep(
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
        expect(client.fetchedActivityIds, [1]);
        expect(fetched, hasLength(1));
        expect(find.text('Found 1 dive'), findsOneWidget);
        expect(container.read(garminCloudDivesFetchedProvider), isTrue);
        expect(find.text('Load More'), findsOneWidget);

        await tester.tap(find.text('Load More'));
        await tester.pumpAndSettle();

        expect(client.fetchedActivityIds, [1, 2]);
        expect(fetched, hasLength(2));
        expect(find.text('Found 2 dives'), findsOneWidget);
        // Exhaustion isn't known until an attempt to load a further page
        // comes back empty, so the button is still offered here...
        expect(find.text('Load More'), findsOneWidget);

        await tester.tap(find.text('Load More'));
        await tester.pumpAndSettle();

        // ...and only disappears once that attempt confirms there's nothing
        // left, without having added or lost any dives.
        expect(client.fetchedActivityIds, [1, 2]);
        expect(fetched, hasLength(2));
        expect(find.text('Load More'), findsNothing);
      },
    );

    testWidgets(
      'a Load More failure keeps the dives already fetched instead of '
      'discarding them',
      (tester) async {
        final client = _FailingSecondPageClient(
          page1: [_activity(1)],
          fitBytesByActivityId: {1: fitBytes},
        );
        List<GarminParsedDive>? fetched;

        await tester.pumpWidget(
          _host(
            store: _FakeSessionStore(),
            clientFactory: _FakeGarminClient.new,
            child: GarminCloudFetchStep(
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
        page1: [_activity(1)],
        fitBytesByActivityId: {1: fitBytes},
        error: StateError('socket died'),
      );
      List<GarminParsedDive>? fetched;

      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: _FakeGarminClient.new,
          child: GarminCloudFetchStep(
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
          page1: [_activity(1)],
          page2: [_activity(2)],
          fitBytesByActivityId: {1: fitBytes, 2: fitBytes},
        );
        List<GarminParsedDive>? fetched;

        await tester.pumpWidget(
          _host(
            store: _FakeSessionStore(),
            clientFactory: _FakeGarminClient.new,
            child: GarminCloudFetchStep(
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
        expect(client.requestedPageStarts, [0, 1, 1]);
        expect(fetched, hasLength(2));
        expect(find.text('Found 2 dives'), findsOneWidget);
        expect(find.text('page 2 blew up'), findsNothing);
      },
    );

    testWidgets('Fetch All still runs after an earlier page failed', (
      tester,
    ) async {
      final client = _RecoveringSecondPageClient(
        page1: [_activity(1)],
        page2: [_activity(2)],
        fitBytesByActivityId: {1: fitBytes, 2: fitBytes},
      );

      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: _FakeGarminClient.new,
          child: GarminCloudFetchStep(client: client, onDivesFetched: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Load More'));
      await tester.pumpAndSettle();
      expect(find.text('page 2 blew up'), findsOneWidget);

      // Fetch All stops looping on a paging error, so a stale one left over
      // from the tap above would make this button a silent no-op.
      await tester.tap(find.text('Fetch All'));
      await tester.pumpAndSettle();

      expect(find.text('Found 2 dives'), findsOneWidget);
      expect(find.text('page 2 blew up'), findsNothing);
    });

    testWidgets(
      'shows a spinner and progress text while Load More is in flight',
      (tester) async {
        final client = _MultiPageClient(
          page1: [_activity(1)],
          page2: [_activity(2)],
          fitBytesByActivityId: {1: fitBytes, 2: fitBytes},
        )..secondPageGate = Completer<void>();

        await tester.pumpWidget(
          _host(
            store: _FakeSessionStore(),
            clientFactory: _FakeGarminClient.new,
            child: GarminCloudFetchStep(client: client, onDivesFetched: (_) {}),
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

    testWidgets(
      'reports failures and offers Load More even when every dive in the '
      'first page failed',
      (tester) async {
        final client = _FakeGarminClient(
          dives: [_activity(1)],
          failActivityIds: {1},
        );

        await tester.pumpWidget(
          _host(
            store: _FakeSessionStore(),
            clientFactory: _FakeGarminClient.new,
            child: GarminCloudFetchStep(client: client, onDivesFetched: (_) {}),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('No dives found'), findsOneWidget);
        expect(
          find.text('1 dive could not be converted and was skipped.'),
          findsOneWidget,
        );
        // The single fake page always looks like it might have a successor
        // until proven otherwise (see the multi-page test above), so the
        // diver can still try to load more even though this page was a
        // total loss.
        expect(find.text('Load More'), findsOneWidget);
      },
    );

    testWidgets('skips a single unreadable dive rather than aborting', (
      tester,
    ) async {
      final client = _FakeGarminClient(
        dives: [_activity(1), _activity(2)],
        fitBytesByActivityId: {1: fitBytes},
      );
      List<GarminParsedDive>? fetched;

      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: _FakeGarminClient.new,
          child: GarminCloudFetchStep(
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

    testWidgets('skips a dive whose download fails outright', (tester) async {
      final client = _FakeGarminClient(
        dives: [_activity(1), _activity(2)],
        fitBytesByActivityId: {1: fitBytes},
        failActivityIds: {2},
      );
      List<GarminParsedDive>? fetched;

      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: _FakeGarminClient.new,
          child: GarminCloudFetchStep(
            client: client,
            onDivesFetched: (dives) => fetched = dives,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(fetched, hasLength(1));
      expect(find.text('Found 1 dive'), findsOneWidget);
    });

    testWidgets('downloads every dive in a page concurrently', (tester) async {
      final client = _ControllableClient(dives: [_activity(1), _activity(2)]);

      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: _FakeGarminClient.new,
          child: GarminCloudFetchStep(client: client, onDivesFetched: (_) {}),
        ),
      );
      await tester.pump();

      // Both downloads are in flight before either has been allowed to
      // finish -- a sequential implementation would only have started the
      // second one after completing the first.
      expect(client.fetchedActivityIds, unorderedEquals([1, 2]));

      client.complete(2, fitBytes);
      await tester.pump();
      client.complete(1, fitBytes);
      await tester.pumpAndSettle();

      expect(find.text('Found 2 dives'), findsOneWidget);
    });

    testWidgets(
      'deselecting a dive removes it from the reported list, reselecting '
      'brings it back',
      (tester) async {
        final client = _FakeGarminClient(
          dives: [_activity(1), _activity(2)],
          fitBytesByActivityId: {1: fitBytes, 2: fitBytes},
        );
        List<GarminParsedDive>? fetched;

        await tester.pumpWidget(
          _host(
            store: _FakeSessionStore(),
            clientFactory: _FakeGarminClient.new,
            child: GarminCloudFetchStep(
              client: client,
              onDivesFetched: (dives) => fetched = dives,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Both dives are selected by default.
        expect(fetched, hasLength(2));
        expect(find.text('2 of 2 selected'), findsOneWidget);

        await tester.tap(find.byType(CheckboxListTile).first);
        await tester.pumpAndSettle();

        expect(fetched, hasLength(1));
        expect(find.text('1 of 2 selected'), findsOneWidget);

        await tester.tap(find.text('Select All'));
        await tester.pumpAndSettle();

        expect(fetched, hasLength(2));
        expect(find.text('2 of 2 selected'), findsOneWidget);

        await tester.tap(find.text('Deselect All'));
        await tester.pumpAndSettle();

        expect(fetched, isEmpty);
        expect(find.text('0 of 2 selected'), findsOneWidget);
      },
    );

    testWidgets('Fetch All loads every remaining page in one tap', (
      tester,
    ) async {
      final client = _MultiPageClient(
        page1: [_activity(1)],
        page2: [_activity(2)],
        fitBytesByActivityId: {1: fitBytes, 2: fitBytes},
      );
      List<GarminParsedDive>? fetched;

      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: _FakeGarminClient.new,
          child: GarminCloudFetchStep(
            client: client,
            onDivesFetched: (dives) => fetched = dives,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fetch All'), findsOneWidget);

      await tester.tap(find.text('Fetch All'));
      await tester.pumpAndSettle();

      expect(client.fetchedActivityIds, [1, 2]);
      expect(fetched, hasLength(2));
      expect(find.text('Found 2 dives'), findsOneWidget);
      expect(find.text('Fetch All'), findsNothing);
    });

    testWidgets('reports an empty account without an error', (tester) async {
      await tester.pumpWidget(
        _host(
          store: _FakeSessionStore(),
          clientFactory: _FakeGarminClient.new,
          child: GarminCloudFetchStep(
            client: _FakeGarminClient(),
            onDivesFetched: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No dives found'), findsOneWidget);
      expect(find.text('Could not fetch dives'), findsNothing);
    });
  });

  group('GarminCloudFetchStep failures', () {
    // garminCloudDivesFetchedProvider is this step's canAdvance, so a
    // first-page failure must leave it false -- otherwise the wizard's Next
    // button would let the diver proceed into an empty review page with no
    // indication anything went wrong.
    Future<ProviderContainer> pumpFailing(
      WidgetTester tester, {
      required GarminConnectClient? client,
    }) async {
      final container = ProviderContainer(
        overrides: [
          garminSessionStoreProvider.overrideWithValue(_FakeSessionStore()),
          garminConnectClientFactoryProvider.overrideWithValue(
            _FakeGarminClient.new,
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
              body: GarminCloudFetchStep(
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
        client: _FakeGarminClient(
          listError: const GarminApiException('session rejected'),
        ),
      );

      expect(find.text('Could not fetch dives'), findsOneWidget);
      expect(find.text('session rejected'), findsOneWidget);
      expect(container.read(garminCloudDivesFetchedProvider), isFalse);
    });

    testWidgets('an unexpected failure also blocks auto-advance', (
      tester,
    ) async {
      final container = await pumpFailing(
        tester,
        client: _FakeGarminClient(listError: StateError('offline')),
      );

      expect(find.text('Could not fetch dives'), findsOneWidget);
      expect(container.read(garminCloudDivesFetchedProvider), isFalse);
    });

    testWidgets('a missing client blocks auto-advance', (tester) async {
      final container = await pumpFailing(tester, client: null);

      expect(find.text('Could not fetch dives'), findsOneWidget);
      expect(container.read(garminCloudDivesFetchedProvider), isFalse);
    });

    testWidgets('Try Again re-runs the fetch and can then advance', (
      tester,
    ) async {
      final client = _RecoveringClient(
        dives: [_activity(1)],
        fitBytesByActivityId: {1: fitBytes},
      );
      final container = ProviderContainer(
        overrides: [
          garminSessionStoreProvider.overrideWithValue(_FakeSessionStore()),
          garminConnectClientFactoryProvider.overrideWithValue(
            _FakeGarminClient.new,
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
              body: GarminCloudFetchStep(
                client: client,
                onDivesFetched: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not fetch dives'), findsOneWidget);
      expect(container.read(garminCloudDivesFetchedProvider), isFalse);

      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(find.text('Found 1 dive'), findsOneWidget);
      expect(container.read(garminCloudDivesFetchedProvider), isTrue);
    });
  });
}
