import 'dart:async';
import 'dart:convert';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as gauth;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher_string.dart';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_client_config.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_token_store.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Runs the user-consent step of the loopback flow and returns credentials.
typedef ObtainConsentCredentials =
    Future<gauth.AccessCredentials> Function(
      gauth.ClientId clientId,
      List<String> scopes,
      http.Client client,
      void Function(String url) prompt,
    );

/// Builds an auto-refreshing client from stored credentials.
typedef BuildRefreshingClient =
    gauth.AutoRefreshingAuthClient Function(
      gauth.ClientId clientId,
      gauth.AccessCredentials credentials,
      http.Client baseClient,
    );

/// Loopback-OAuth authenticator for Windows and Linux (RFC 8252 section
/// 7.3): binds an ephemeral 127.0.0.1 port, opens the system browser to
/// Google's consent page, and receives the auth code on the local
/// redirect. Uses PKCE with no client secret -- Google lists client_secret
/// as optional for Desktop-app clients, so the code_verifier alone
/// authenticates the token exchange. Credentials persist in
/// [GoogleDriveTokenStore]; cold-launch re-auth is silent via the stored
/// refresh token.
class DesktopOAuthAuthenticator implements GoogleDriveAuthenticator {
  DesktopOAuthAuthenticator({
    GoogleDriveTokenStore? tokenStore,
    ObtainConsentCredentials? obtainConsent,
    BuildRefreshingClient? buildClient,
    http.Client Function()? baseClientFactory,
    Future<void> Function(String url)? launchBrowser,
  }) : _tokenStore = tokenStore ?? GoogleDriveTokenStore(),
       _obtainConsent =
           obtainConsent ?? gauth.obtainAccessCredentialsViaUserConsent,
       _buildClient = buildClient ?? gauth.autoRefreshingClient,
       _baseClientFactory = baseClientFactory ?? http.Client.new,
       _launchBrowser = launchBrowser ?? launchUrlString;

  static final _log = LoggerService.forClass(DesktopOAuthAuthenticator);

  /// openid + email are included so the id_token carries the account email
  /// for the settings tile subtitle; drive.appdata is the only Drive scope.
  static const List<String> scopes = [
    drive.DriveApi.driveAppdataScope,
    'openid',
    'email',
  ];

  static const String _revokeEndpoint = 'https://oauth2.googleapis.com/revoke';

  final GoogleDriveTokenStore _tokenStore;
  final ObtainConsentCredentials _obtainConsent;
  final BuildRefreshingClient _buildClient;
  final http.Client Function() _baseClientFactory;
  final Future<void> Function(String url) _launchBrowser;

  gauth.AutoRefreshingAuthClient? _authClient;
  StreamSubscription<gauth.AccessCredentials>? _updateSubscription;
  String? _email;

  // No client secret: PKCE authenticates the token exchange (Google lists
  // client_secret as optional for Desktop-app clients).
  gauth.ClientId get _clientId =>
      gauth.ClientId(GoogleDriveClientConfig.desktopClientId);

  @override
  http.Client? get authClient => _authClient;

  @override
  Future<String?> get userEmail async => _email;

  @override
  Future<void> authenticate() async {
    final base = _baseClientFactory();
    try {
      final credentials = await _obtainConsent(_clientId, scopes, base, (url) {
        unawaited(_launchBrowser(url));
      });
      await _tokenStore.save(credentials);
      _installClient(credentials);
      _log.info('Authenticated with Google Drive via browser consent');
    } on CloudStorageException {
      rethrow;
    } catch (e, stackTrace) {
      _log.error('Google Sign-In failed', error: e, stackTrace: stackTrace);
      throw CloudStorageException('Google Sign-In failed: $e', e, stackTrace);
    } finally {
      base.close();
    }
  }

  @override
  Future<bool> attemptSilentAuth() async {
    try {
      if (_authClient != null) return true;

      final credentials = await _tokenStore.load();
      if (credentials == null || credentials.refreshToken == null) {
        return false;
      }
      _installClient(credentials);
      return true;
    } catch (e) {
      _log.warning('Silent sign-in failed: $e');
      return false;
    }
  }

  void _installClient(gauth.AccessCredentials credentials) {
    _teardownClient();
    final client = _buildClient(_clientId, credentials, _baseClientFactory());
    _updateSubscription = client.credentialUpdates.listen(
      (updated) => unawaited(_tokenStore.save(updated)),
    );
    _authClient = client;
    _email = _emailFromIdToken(credentials.idToken) ?? _email;
  }

  void _teardownClient() {
    unawaited(_updateSubscription?.cancel());
    _updateSubscription = null;
    _authClient?.close();
    _authClient = null;
  }

  @override
  Future<void> signOut() async {
    final credentials = await _tokenStore.load();
    final token =
        credentials?.refreshToken ?? _authClient?.credentials.accessToken.data;
    if (token != null) {
      // Best effort: revocation failure (e.g. offline) must not block
      // local sign-out.
      final base = _baseClientFactory();
      try {
        await base.post(
          Uri.parse(_revokeEndpoint),
          headers: {'content-type': 'application/x-www-form-urlencoded'},
          // Encode the token: Google refresh tokens contain '/' and other
          // characters that must be percent-encoded in a form body.
          body: 'token=${Uri.encodeQueryComponent(token)}',
        );
      } catch (e) {
        _log.warning('Token revocation failed (ignored): $e');
      } finally {
        base.close();
      }
    }
    _teardownClient();
    _email = null;
    await _tokenStore.clear();
    _log.info('Signed out from Google Drive');
  }

  @override
  Future<void> handleAuthFailure() async {
    // A 401 that survives the auto-refreshing client means the grant was
    // revoked; clear everything so the next attempt re-runs the browser
    // flow instead of looping on a dead refresh token.
    _teardownClient();
    _email = null;
    await _tokenStore.clear();
  }

  /// Extracts the email claim from a JWT id_token, or null.
  static String? _emailFromIdToken(String? idToken) {
    if (idToken == null) return null;
    final parts = idToken.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;
      return decoded['email'] as String?;
    } on FormatException {
      return null;
    }
  }
}
