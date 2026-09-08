import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_client_config.dart';
import 'package:submersion/core/services/cloud_storage/http_timeouts.dart';
import 'package:submersion/core/services/logger_service.dart';

/// google_sign_in-backed authenticator for iOS, macOS, and Android.
///
/// Token persistence across launches is handled by google_sign_in's own
/// cache via attemptLightweightAuthentication(); nothing is stored by the
/// app. That cache is the entire reason cold-launch sync works, so silent
/// sign-in must NOT be gated behind an in-process opt-in flag: such a flag is
/// false in every fresh process, which would report sync as unauthenticated
/// after every restart. See [GoogleDriveAuthenticator.attemptSilentAuth] for
/// where the pre-opt-in guarantee actually lives.
class GoogleSignInAuthenticator implements GoogleDriveAuthenticator {
  static final _log = LoggerService.forClass(GoogleSignInAuthenticator);

  static const _scopes = [drive.DriveApi.driveAppdataScope];

  // Use the shared instance; configuration is provided per-call via scope
  // hints.
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _initialized = false;

  /// The authorized client, wrapped in [TimeoutHttpClient]. Held as a plain
  /// [http.Client] because that wrapper is what everything downstream uses:
  /// the provider builds its DriveApi from it and the media store sends raw
  /// REST over it, and neither needs the AuthClient surface.
  http.Client? _authClient;
  GoogleSignInAccount? _currentUser;

  @override
  http.Client? get authClient => _authClient;

  @override
  Future<String?> get userEmail async => _currentUser?.email;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final serverClientId =
        Platform.isAndroid &&
            GoogleDriveClientConfig.androidServerClientId.isNotEmpty
        ? GoogleDriveClientConfig.androidServerClientId
        : null;
    await _googleSignIn.initialize(serverClientId: serverClientId);
    _initialized = true;
  }

  /// Single-flights [attemptSilentAuth]: the `_authClient != null` guard is
  /// read before the SDK round trip, so two concurrent callers would both get
  /// past it and both install. The second install closes the client the first
  /// already published to the provider and the media store, and nothing
  /// rebuilds from a still-non-null authClient -- so every later Drive call
  /// failed with "HTTP request failed. Client is already closed." until the
  /// process restarted.
  ///
  /// Two callers is the ordinary case: the Cloud Sync page fires an unawaited
  /// refreshState() -> isAuthenticated() while a launch sync sits inside its
  /// own isAuthenticated().
  Future<bool>? _silentAuthInFlight;

  @override
  Future<bool> attemptSilentAuth() {
    if (_authClient != null) return Future.value(true);
    return _silentAuthInFlight ??= _runSilentAuth().whenComplete(
      () => _silentAuthInFlight = null,
    );
  }

  Future<bool> _runSilentAuth() async {
    try {
      if (_authClient != null) return true;

      await _ensureInitialized();
      final futureAccount = _googleSignIn.attemptLightweightAuthentication();
      if (futureAccount == null) return false;

      final account = await futureAccount;
      if (account == null) return false;

      final authorization = await account.authorizationClient
          .authorizationForScopes(_scopes);
      if (authorization == null) return false;

      _installClient(account, authorization);
      return true;
    } catch (e) {
      _log.warning('Silent sign-in failed: $e');
      return false;
    }
  }

  @override
  Future<void> authenticate() async {
    try {
      await _ensureInitialized();
      final account = await _googleSignIn.authenticate(scopeHint: _scopes);
      final authorization = await account.authorizationClient.authorizeScopes(
        _scopes,
      );

      _installClient(account, authorization);
      _log.info('Authenticated with Google Drive as ${account.email}');
    } on GoogleSignInException catch (e, stackTrace) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        if (_isPlatformRefusal(e.description)) {
          _log.error(
            'Google Play services refused to authorize the account',
            error: e,
            stackTrace: stackTrace,
          );
          throw CloudStorageException(
            // Deliberately platform-neutral about where to look: this
            // authenticator also serves iOS and macOS, so naming Android's
            // settings would misdirect users there.
            'Google Sign-In was refused by the device. Check that the Google '
            'account on this device is signed in and up to date in the system '
            'settings, then try again.',
            // The plain status, never the exception. displayMessage appends
            // the cause and the Cloud Sync snackbar renders displayMessage,
            // so passing `e` here would print its toString on screen: the
            // word "canceled" back in front of a user who cancelled nothing,
            // plus a second copy of the status. The exception itself is
            // already in the log line above, which is where it belongs.
            e.description,
            stackTrace,
          );
        }
        _log.info('Google Sign-In was cancelled by the user');
        throw CloudStorageException(
          'Google Sign-In was cancelled',
          // No cause: a dismissal has no detail worth showing, and the
          // exception's toString would only leak plugin internals.
          null,
          stackTrace,
        );
      }
      _log.error('Google Sign-In failed', error: e, stackTrace: stackTrace);
      throw CloudStorageException(
        'Google Sign-In failed',
        e.description ?? e.code.name,
        stackTrace,
      );
    } catch (e, stackTrace) {
      _log.error('Google Sign-In failed', error: e, stackTrace: stackTrace);
      throw CloudStorageException('Google Sign-In failed', e, stackTrace);
    }
  }

  /// Whether a `canceled` code actually describes a refusal by Google Play
  /// services rather than a dialog the user dismissed.
  ///
  /// Android routes both through `GetCredentialCancellationException`, so the
  /// SDK reports them under one code. Play services prefixes its own
  /// refusals with the numeric status it failed on, as in
  /// `[16] Account reauth failed.`; a dismissal carries prose with no such
  /// prefix. Matching the bracketed status rather than the wording keeps this
  /// working when Google rewords a message, and it is the only structure the
  /// two cases do not share.
  ///
  /// The distinction matters because the two need opposite responses: a
  /// dismissal is a decision to leave alone, while a refusal is a fault the
  /// user cannot act on without being told what it was. Reporting a refusal
  /// as "cancelled" is what left Google Drive users on an unregistered build
  /// retrying a dialog they had never dismissed.
  static bool _isPlatformRefusal(String? description) =>
      description != null && _platformStatusPrefix.hasMatch(description);

  static final _platformStatusPrefix = RegExp(r'^\s*\[\d+\]');

  void _installClient(
    GoogleSignInAccount account,
    GoogleSignInClientAuthorization authorization,
  ) {
    _authClient?.close();
    // google_sign_in builds the authorized client over a transport this app
    // never gets to configure, so the deadlines go on the outside. Closing
    // the wrapper closes the client underneath it (#1279).
    _authClient = TimeoutHttpClient(authorization.authClient(scopes: _scopes));
    _currentUser = account;
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    // Close the auth client if it exists; close is synchronous.
    _authClient?.close();
    _authClient = null;
    _currentUser = null;
    _log.info('Signed out from Google Drive');
  }

  @override
  Future<void> handleAuthFailure() async {
    // Drop the stale client so the next attemptSilentAuth() rebuilds
    // authorization without UI.
    //
    // Deliberately leaves _currentUser set (unlike DesktopOAuthAuthenticator,
    // which clears _email): silent re-auth here normally restores the same
    // account and _installClient overwrites it, while a failed re-auth leaves
    // isAuthenticated() false so the stale email is never surfaced. Do not
    // "fix" this to clear _currentUser -- it would blank a still-valid account
    // during a transient token refresh.
    _authClient?.close();
    _authClient = null;
  }
}
