import 'dart:io';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/googleapis_auth.dart' as gapis_auth;
import 'package:http/http.dart' as http;

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_client_config.dart';
import 'package:submersion/core/services/logger_service.dart';

/// google_sign_in-backed authenticator for iOS, macOS, and Android.
///
/// Token persistence across launches is handled by google_sign_in's own
/// cache via attemptLightweightAuthentication(); nothing is stored by the
/// app. Silent sign-in is deferred until the user has opted in once
/// (_allowSilentAuth) because it touches the platform keychain.
class GoogleSignInAuthenticator implements GoogleDriveAuthenticator {
  static final _log = LoggerService.forClass(GoogleSignInAuthenticator);

  static const _scopes = [drive.DriveApi.driveAppdataScope];

  // Use the shared instance; configuration is provided per-call via scope
  // hints.
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _initialized = false;
  bool _allowSilentAuth = false;
  gapis_auth.AuthClient? _authClient;
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

  @override
  Future<bool> attemptSilentAuth() async {
    try {
      if (_authClient != null) return true;

      // Defer any silent sign-in (which triggers Keychain access) until the
      // user has explicitly opted in by signing in once.
      if (!_allowSilentAuth) return false;

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
      _allowSilentAuth = true;
      _log.info('Authenticated with Google Drive as ${account.email}');
    } on GoogleSignInException catch (e, stackTrace) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        _log.info('Google Sign-In was cancelled by the user');
        throw CloudStorageException(
          'Google Sign-In was cancelled',
          e,
          stackTrace,
        );
      }
      _log.error('Google Sign-In failed', error: e, stackTrace: stackTrace);
      throw CloudStorageException(
        'Google Sign-In failed: ${e.description ?? e.code.name}',
        e,
        stackTrace,
      );
    } catch (e, stackTrace) {
      _log.error('Google Sign-In failed', error: e, stackTrace: stackTrace);
      throw CloudStorageException('Google Sign-In failed: $e', e, stackTrace);
    }
  }

  void _installClient(
    GoogleSignInAccount account,
    GoogleSignInClientAuthorization authorization,
  ) {
    _authClient?.close();
    _authClient = authorization.authClient(scopes: _scopes);
    _currentUser = account;
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    // Close the auth client if it exists; close is synchronous.
    _authClient?.close();
    _authClient = null;
    _currentUser = null;
    _allowSilentAuth = false;
    _log.info('Signed out from Google Drive');
  }

  @override
  Future<void> handleAuthFailure() async {
    // Drop the stale client; keep _allowSilentAuth so the next
    // attemptSilentAuth() can rebuild authorization without UI.
    _authClient?.close();
    _authClient = null;
  }
}
