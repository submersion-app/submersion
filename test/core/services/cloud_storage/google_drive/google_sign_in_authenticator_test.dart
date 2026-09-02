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

  @override
  Future<AuthenticationResults?>? attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) async => lightweightResult;

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

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async => authorizationToken;

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

  setUp(() {
    platform = _FakePlatform();
    GoogleSignInPlatform.instance = platform;
    auth = GoogleSignInAuthenticator();
  });

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

    test('maps other sign-in failures with their description', () async {
      platform.authenticateError = const GoogleSignInException(
        code: GoogleSignInExceptionCode.unknownError,
        description: 'network unreachable',
      );

      await expectLater(
        auth.authenticate(),
        throwsA(
          isA<CloudStorageException>().having(
            (e) => e.message,
            'message',
            contains('network unreachable'),
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
