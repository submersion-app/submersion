import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
// The app-facing google_sign_in package is driven indirectly here: the
// authenticator talks to GoogleSignIn.instance, which delegates to whatever
// GoogleSignInPlatform.instance is set to. Only the platform interface needs
// importing (it re-exports the exception and result types used below).
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_sign_in_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/http_timeouts.dart';

/// Drives [GoogleSignInAuthenticator] through a fake [GoogleSignInPlatform]
/// rather than the real plugin, so the mobile/macOS auth path is exercisable
/// off-device. MockPlatformInterfaceMixin bypasses the platform-interface
/// token check that would otherwise reject a non-official implementation.
class _FakePlatform extends GoogleSignInPlatform
    with MockPlatformInterfaceMixin {
  final List<InitParameters> initCalls = [];
  int signOutCalls = 0;

  /// Result for attemptLightweightAuthentication; null means "no cached
  /// session", which is what a never-signed-in user looks like.
  AuthenticationResults? lightweightResult;

  /// Result for an explicit authenticate(); when null, [authenticateError] is
  /// thrown instead.
  AuthenticationResults? authenticateResult;
  Object? authenticateError;

  /// Token returned for scope authorization; null means "not authorized".
  ClientAuthorizationTokenData? authorizationToken =
      const ClientAuthorizationTokenData(accessToken: 'access-token-1');

  static AuthenticationResults resultsFor(String email) =>
      AuthenticationResults(
        user: GoogleSignInUserData(email: email, id: 'id-$email'),
        authenticationTokens: const AuthenticationTokenData(
          idToken: 'id-token',
        ),
      );

  @override
  Future<void> init(InitParameters params) async => initCalls.add(params);

  /// How many times lightweight authentication ran. On Android it goes
  /// through Credential Manager, which needs a foreground activity, so a
  /// token refresh must not depend on it.
  int lightweightCalls = 0;

  @override
  Future<AuthenticationResults?>? attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) async {
    lightweightCalls++;
    return lightweightResult;
  }

  /// Access tokens handed to clearAuthorizationToken, in call order.
  final List<String> clearedTokens = [];

  /// When set, clearAuthorizationToken throws this instead of recording.
  Object? clearTokenError;

  /// When set, clearAuthorizationToken does not finish until this completes,
  /// holding the eviction open the way a slow platform call does.
  Completer<void>? clearGate;

  @override
  Future<void> clearAuthorizationToken(
    ClearAuthorizationTokenParams params,
  ) async {
    await clearGate?.future;
    final error = clearTokenError;
    if (error != null) throw error;
    clearedTokens.add(params.accessToken);
  }

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    final error = authenticateError;
    if (error != null) throw error;
    return authenticateResult!;
  }

  @override
  bool authorizationRequiresUserInteraction() => false;

  /// How many times a scope authorization was requested. One per installed
  /// client, so it counts clients without reaching into the authenticator.
  int authorizationCalls = 0;

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async {
    authorizationCalls++;
    return authorizationToken;
  }

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async => null;

  @override
  Future<void> signOut(SignOutParams params) async => signOutCalls++;

  @override
  Future<void> disconnect(DisconnectParams params) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePlatform platform;
  late GoogleSignInAuthenticator auth;
  late GoogleSignInPlatform originalPlatform;

  setUp(() {
    platform = _FakePlatform();
    originalPlatform = GoogleSignInPlatform.instance;
    GoogleSignInPlatform.instance = platform;
    auth = GoogleSignInAuthenticator();
  });

  tearDown(() => GoogleSignInPlatform.instance = originalPlatform);

  group('attemptSilentAuth', () {
    test('succeeds in a fresh process with no authenticate() call', () async {
      // Cold-launch regression guard, and the reason this authenticator has no
      // in-process opt-in flag: sync calls isAuthenticated() first thing after
      // a restart. A flag defaulting to false here would report every launch
      // as unauthenticated (manual checklist item 2).
      platform.lightweightResult = _FakePlatform.resultsFor(
        'diver@example.com',
      );

      expect(await auth.attemptSilentAuth(), isTrue);
      expect(auth.authClient, isNotNull);
      expect(await auth.userEmail, 'diver@example.com');
    });

    test('installs a client with request deadlines', () async {
      // google_sign_in builds the authorized client itself, over a transport
      // this app never sees, so the deadlines have to go on the outside. A
      // bare client parked a wedged Drive request forever -- on sync and, via
      // mediaHttpClient(), on the media transfer queue (#1279).
      platform.lightweightResult = _FakePlatform.resultsFor(
        'diver@example.com',
      );

      expect(await auth.attemptSilentAuth(), isTrue);
      expect(auth.authClient, isA<TimeoutHttpClient>());
    });

    test('returns false when there is no cached session', () async {
      platform.lightweightResult = null;

      expect(await auth.attemptSilentAuth(), isFalse);
      expect(auth.authClient, isNull);
    });

    test('returns false when the scope is not authorized', () async {
      platform.lightweightResult = _FakePlatform.resultsFor(
        'diver@example.com',
      );
      platform.authorizationToken = null;

      expect(await auth.attemptSilentAuth(), isFalse);
      expect(auth.authClient, isNull);
    });

    test('reuses the installed client without re-querying', () async {
      platform.lightweightResult = _FakePlatform.resultsFor(
        'diver@example.com',
      );
      expect(await auth.attemptSilentAuth(), isTrue);
      final first = auth.authClient;

      platform.lightweightResult = null; // would fail if consulted again
      expect(await auth.attemptSilentAuth(), isTrue);
      expect(auth.authClient, same(first));
    });

    test(
      'two concurrent callers authorize once and install one client',
      () async {
        // The reuse guard above is read BEFORE the SDK round trip, so without
        // single-flighting both callers install and the second _installClient
        // closes the client the first already handed to the provider and to the
        // media store. Nothing rebuilds from a still-non-null authClient, so
        // every later Drive call fails with "Client is already closed" for the
        // rest of the process.
        platform.lightweightResult = _FakePlatform.resultsFor(
          'diver@example.com',
        );

        final results = await Future.wait([
          auth.attemptSilentAuth(),
          auth.attemptSilentAuth(),
        ]);

        expect(results, [true, true]);
        expect(platform.authorizationCalls, 1);
        expect(auth.authClient, isNotNull);
      },
    );

    test('swallows platform errors and reports failure', () async {
      GoogleSignInPlatform.instance = _ThrowingInitPlatform();
      final failing = GoogleSignInAuthenticator();

      expect(await failing.attemptSilentAuth(), isFalse);
    });
  });

  group('authenticate', () {
    test('installs a client and exposes the account email', () async {
      platform.authenticateResult = _FakePlatform.resultsFor(
        'diver@example.com',
      );

      await auth.authenticate();

      expect(auth.authClient, isNotNull);
      expect(await auth.userEmail, 'diver@example.com');
    });

    test('maps user cancellation to a CloudStorageException', () async {
      platform.authenticateError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
      );

      await expectLater(
        auth.authenticate(),
        throwsA(
          isA<CloudStorageException>().having(
            (e) => e.message,
            'message',
            contains('cancelled'),
          ),
        ),
      );
    });

    test('does not call a Play services refusal a user cancellation', () async {
      // google_sign_in reports a Google Play services refusal under the
      // same `canceled` code as a real dismissal. Users on a build whose
      // signing certificate has no registered Android OAuth client hit this
      // on every attempt, and the old wording told them they had cancelled
      // a dialog they never saw. See scripts/check_apk_signing_cert.py.
      platform.authenticateError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: '[16] Account reauth failed.',
      );

      await expectLater(
        auth.authenticate(),
        throwsA(
          isA<CloudStorageException>()
              .having((e) => e.message, 'message', isNot(contains('cancelled')))
              .having(
                (e) => e.displayMessage,
                'displayMessage',
                contains('Account reauth failed'),
              ),
        ),
      );
    });

    test('a refusal shows the status once, with no plugin internals', () async {
      // displayMessage appends the cause, and the Cloud Sync snackbar renders
      // displayMessage. Passing the GoogleSignInException itself as the cause
      // therefore put its toString -- including the word "canceled" -- back on
      // screen, and repeated the status the message already carried.
      platform.authenticateError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: '[16] Account reauth failed.',
      );

      await expectLater(
        auth.authenticate(),
        throwsA(
          isA<CloudStorageException>()
              .having(
                (e) => e.displayMessage,
                'displayMessage',
                isNot(contains('GoogleSignInException')),
              )
              .having(
                (e) => e.displayMessage.toLowerCase(),
                'displayMessage',
                isNot(contains('cancel')),
              )
              .having(
                (e) => '[16]'.allMatches(e.displayMessage).length,
                'occurrences of the status',
                1,
              ),
        ),
      );
    });

    test('a dismissal shows no plugin internals either', () async {
      platform.authenticateError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: 'activity is cancelled by the user.',
      );

      await expectLater(
        auth.authenticate(),
        throwsA(
          isA<CloudStorageException>().having(
            (e) => e.displayMessage,
            'displayMessage',
            isNot(contains('GoogleSignInException')),
          ),
        ),
      );
    });

    test('still treats a dismissed sign-in dialog as a cancellation', () async {
      platform.authenticateError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.canceled,
        description: 'activity is cancelled by the user.',
      );

      await expectLater(
        auth.authenticate(),
        throwsA(
          isA<CloudStorageException>().having(
            (e) => e.message,
            'message',
            contains('cancelled'),
          ),
        ),
      );
    });

    test('maps other sign-in failures with their description', () async {
      platform.authenticateError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'network unreachable',
      );

      await expectLater(
        auth.authenticate(),
        throwsA(
          isA<CloudStorageException>()
              .having(
                (e) => e.displayMessage,
                'displayMessage',
                contains('network unreachable'),
              )
              .having(
                (e) => e.displayMessage,
                'displayMessage',
                isNot(contains('GoogleSignInException')),
              ),
        ),
      );
    });

    test('wraps a non-GoogleSignInException failure', () async {
      platform.authenticateError = StateError('boom');

      await expectLater(
        auth.authenticate(),
        throwsA(isA<CloudStorageException>()),
      );
    });
  });

  group('session teardown', () {
    setUp(() async {
      platform.authenticateResult = _FakePlatform.resultsFor(
        'diver@example.com',
      );
      await auth.authenticate();
    });

    test('signOut clears the client and the account', () async {
      await auth.signOut();

      expect(platform.signOutCalls, 1);
      expect(auth.authClient, isNull);
      expect(await auth.userEmail, isNull);
    });

    test('handleAuthFailure drops the client but keeps the account', () async {
      // Deliberate asymmetry with the desktop authenticator: a transient token
      // refresh must not blank a still-valid account. The stale address is
      // suppressed at the UI layer by googleDriveAccountEmailProvider, which
      // gates on the auth flag.
      await auth.handleAuthFailure();

      expect(auth.authClient, isNull);
      expect(await auth.userEmail, 'diver@example.com');
    });

    test(
      'handleAuthFailure clears the rejected token from the cache',
      () async {
        // The SDK caches access tokens and can hand back one the API has
        // already rejected. Without clearing it, the retry after a 401 got the
        // same dead token and failed the same way on every sync (#3602).
        await auth.handleAuthFailure();

        expect(platform.clearedTokens, ['access-token-1']);
      },
    );

    test('handleAuthFailure survives a failure to clear the token', () async {
      platform.clearTokenError = StateError('clear failed');

      await auth.handleAuthFailure();

      expect(auth.authClient, isNull);
    });

    test(
      'a token refresh reuses the known account without signing in',
      () async {
        // An expired access token is refreshed by asking for the account's
        // authorization again. Lightweight sign-in is not needed for that and
        // must not be used: on Android it needs a foreground activity, so a
        // background sync could never refresh, and the diver had to sign in by
        // hand every time the hourly token expired (#3602).
        await auth.handleAuthFailure();
        platform.lightweightResult = null; // would fail if consulted
        platform.authorizationToken = const ClientAuthorizationTokenData(
          accessToken: 'access-token-2',
        );

        expect(await auth.attemptSilentAuth(), isTrue);
        expect(auth.authClient, isNotNull);
        expect(platform.lightweightCalls, 0);
        expect(await auth.userEmail, 'diver@example.com');

        // The new token is the one cleared on the next rejection.
        await auth.handleAuthFailure();
        expect(platform.clearedTokens, ['access-token-1', 'access-token-2']);
      },
    );

    test('a re-auth waits until the rejected token is evicted', () async {
      // Any caller may ask for auth while the eviction is still running (the
      // Cloud Sync page's unawaited refreshState, the media store's supplier).
      // Authorizing in that window got the dead token back from the SDK
      // cache and installed it, so the retry failed on it again.
      final gate = Completer<void>();
      platform.clearGate = gate;
      final callsBefore = platform.authorizationCalls;

      final failure = auth.handleAuthFailure();
      final reauth = auth.attemptSilentAuth();
      await pumpEventQueue();
      expect(platform.authorizationCalls, callsBefore);

      gate.complete();
      await failure;
      expect(await reauth, isTrue);
      expect(platform.authorizationCalls, callsBefore + 1);
    });

    test('a token refresh fails when the scope was revoked', () async {
      await auth.handleAuthFailure();
      platform.authorizationToken = null;

      expect(await auth.attemptSilentAuth(), isFalse);
      expect(auth.authClient, isNull);
    });

    test('a signed-out authenticator can silently sign in again', () async {
      await auth.signOut();
      platform.lightweightResult = _FakePlatform.resultsFor(
        'diver@example.com',
      );

      expect(await auth.attemptSilentAuth(), isTrue);
    });
  });
}

/// Platform whose init() throws, to exercise attemptSilentAuth's catch.
class _ThrowingInitPlatform extends _FakePlatform {
  @override
  Future<void> init(InitParameters params) async =>
      throw StateError('init failed');
}
