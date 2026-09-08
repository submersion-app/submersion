import 'dart:async';
import 'dart:convert';

import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart' as gauth;
import 'package:http/http.dart' as http;

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_client_config.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_token_store.dart';
import 'package:submersion/core/services/cloud_storage/http_timeouts.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/shared/utils/browser_launch.dart';

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

/// Loopback-OAuth authenticator for Windows, Linux, and the Developer ID
/// macOS build (RFC 8252 section 7.3): binds an ephemeral 127.0.0.1 port,
/// opens the system browser to Google's consent page, and receives the auth
/// code on the local redirect.
///
/// Uses PKCE **and** the Desktop client's secret. PKCE alone does not
/// satisfy Google: its token endpoint answers `invalid_request:
/// client_secret is missing` for a Desktop-app client whether the field is
/// omitted or sent empty, code_verifier present. The secret is supplied at
/// build time via [GoogleDriveClientConfig.desktopClientSecret] rather than
/// committed.
///
/// Credentials persist in [GoogleDriveTokenStore]; cold-launch re-auth is
/// silent via the stored refresh token.
class DesktopOAuthAuthenticator implements GoogleDriveAuthenticator {
  DesktopOAuthAuthenticator({
    GoogleDriveTokenStore? tokenStore,
    ObtainConsentCredentials? obtainConsent,
    BuildRefreshingClient? buildClient,
    http.Client Function()? baseClientFactory,
    Future<bool> Function(String url)? launchBrowser,
    String? clientSecret,
  }) : _clientSecret =
           clientSecret ?? GoogleDriveClientConfig.desktopClientSecret,
       _tokenStore = tokenStore ?? GoogleDriveTokenStore(),
       _obtainConsent =
           obtainConsent ?? gauth.obtainAccessCredentialsViaUserConsent,
       _buildClient = buildClient ?? gauth.autoRefreshingClient,
       _baseClientFactory = baseClientFactory ?? _timedClient,
       _launchBrowser = launchBrowser ?? _openConsentPage;

  static final _log = LoggerService.forClass(DesktopOAuthAuthenticator);

  /// Base transport for the refreshing client, the consent-flow token
  /// exchange, and revocation.
  ///
  /// A bare `http.Client()` has no connect, response or read deadline, so a
  /// wedged socket parked every Drive call made through the refreshing client
  /// on top of it -- on sync and, via `mediaHttpClient()`, on the media
  /// transfer queue (#1279).
  static http.Client _timedClient() => TimeoutHttpClient.overSockets();

  /// Hands the consent URL to the browser, with the Linux fallback chain
  /// url_launcher alone does not provide.
  static Future<bool> _openConsentPage(String url) =>
      openInBrowser(Uri.parse(url));

  /// Opens the consent page, turning "nothing took the URL" into a throw.
  ///
  /// [openInBrowser] reports that by returning false rather than throwing --
  /// exactly the no-scheme-handler case this flow has to survive -- so a
  /// discarded result would leave the loopback wait looking like a hang with
  /// nothing in the log to explain it.
  Future<void> _launchConsentPage(String url) async {
    try {
      if (await _launchBrowser(url)) return;
    } on Exception {
      _logManualConsentUrl(url);
      rethrow;
    }
    _logManualConsentUrl(url);
    throw const CloudStorageException(
      'No browser accepted the Google consent URL. Open the URL logged just '
      'above this error to finish connecting by hand.',
    );
  }

  /// Logs the consent URL as the manual way out of a failed launch.
  ///
  /// Only on failure: the URL carries the PKCE challenge and the state
  /// parameter, so it has no business in the log of a flow that worked, where
  /// it would be a very long line nobody reads and a needless copy of the
  /// request's one-time secrets.
  void _logManualConsentUrl(String url) =>
      _log.warning('Open this URL to finish Google consent: $url');

  /// openid + email are included so the id_token carries the account email
  /// for the settings tile subtitle; drive.appdata is the only Drive scope.
  static const List<String> scopes = [
    drive.DriveApi.driveAppdataScope,
    'openid',
    'email',
  ];

  static const String _revokeEndpoint = 'https://oauth2.googleapis.com/revoke';

  final String _clientSecret;
  final GoogleDriveTokenStore _tokenStore;
  final ObtainConsentCredentials _obtainConsent;
  final BuildRefreshingClient _buildClient;
  final http.Client Function() _baseClientFactory;
  final Future<bool> Function(String url) _launchBrowser;

  gauth.AutoRefreshingAuthClient? _authClient;
  StreamSubscription<gauth.AccessCredentials>? _updateSubscription;
  String? _email;

  // Null rather than '' when unconfigured: googleapis_auth serialises
  // `secret ?? ''` so both reach Google identically, but null keeps the
  // not-configured state legible at this layer.
  gauth.ClientId get _clientId => gauth.ClientId(
    GoogleDriveClientConfig.desktopClientId,
    _clientSecret.isEmpty ? null : _clientSecret,
  );

  @override
  http.Client? get authClient => _authClient;

  @override
  Future<String?> get userEmail async => _email;

  @override
  Future<void> authenticate() async {
    final base = _baseClientFactory();
    try {
      final credentials = await _obtainConsent(_clientId, scopes, base, (url) {
        // The loopback flow then parks on the redirect until the browser
        // comes back with a code, so a launch that failed reads as a hang.
        // _launchConsentPage logs the URL if that happens: on a desktop with
        // no working https scheme handler (see openInBrowser) that log line
        // is the only way to finish consent by hand.
        logFailure(
          _launchConsentPage(url),
          DesktopOAuthAuthenticator,
          'open the Google consent page',
        );
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

  /// Single-flights [attemptSilentAuth]: the `_authClient != null` guard is
  /// read before the token-store await, so two concurrent callers would both
  /// get past it and both install. The second install closes the client the
  /// first already published to the provider and the media store, and nothing
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
