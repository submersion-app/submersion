import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/lightroom/lightroom_auth_store.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/oauth/oauth_pkce.dart';

/// Thrown when a Native App connection's access token has expired and there
/// is no refresh token to renew it. The user must sign in again.
///
/// Extends [CloudStorageException] so it flows through the same user-facing
/// error handling as other connector failures (surfaced via `displayMessage`,
/// no `Exception:`/class-name prefix in snackbars). It is thrown in normal
/// runtime paths such as media scans.
class LightroomReauthRequiredException extends CloudStorageException {
  const LightroomReauthRequiredException()
    : super('Lightroom sign-in has expired; sign in again.');
}

/// OAuth 2 PKCE lifecycle against Adobe IMS for the Lightroom connector:
/// authorize-URL construction, the paste-the-redirected-URL code exchange,
/// in-memory access-token caching with single-flight refresh, disconnect.
///
/// Unlike Dropbox, IMS requires a redirect_uri. The app uses a fixed
/// documented URI; the browser lands there after consent and the user
/// pastes the full address (or just the code) back into the dialog.
/// IMS also rotates refresh tokens on refresh, so a rotated token is
/// persisted immediately.
class AdobeImsAuthManager {
  AdobeImsAuthManager({
    LightroomAuthStore? store,
    http.Client? httpClient,
    DateTime Function()? now,
    String Function()? verifierGenerator,
  }) : _store = store ?? LightroomAuthStore(),
       _http = httpClient ?? http.Client(),
       _now = now ?? DateTime.now,
       _generateVerifier = verifierGenerator ?? generateCodeVerifier;

  static final _log = LoggerService.forClass(AdobeImsAuthManager);

  static final Uri _authorizeUri = Uri.parse(
    'https://ims-na1.adobelogin.com/ims/authorize/v2',
  );
  static final Uri _tokenUri = Uri.parse(
    'https://ims-na1.adobelogin.com/ims/token/v3',
  );

  /// Must match the redirect URI registered on the user's Adobe Developer
  /// Console integration (BYO client id).
  static const String redirectUri = 'https://submersion.app/lightroom/callback';

  static const String scopes =
      'openid,AdobeID,lr_partner_apis,lr_partner_rendition_apis,offline_access';

  /// Refresh slightly before IMS's expiry so an access token is never
  /// presented within its final minute.
  static const Duration _expiryMargin = Duration(seconds: 60);

  final LightroomAuthStore _store;
  final http.Client _http;
  final DateTime Function() _now;
  final String Function() _generateVerifier;

  String? _pendingVerifier;
  String? _pendingClientId;
  String? _pendingClientSecret;
  String? _pendingRedirectUri;
  String? _accessToken;
  DateTime? _accessTokenExpiry;
  Future<String>? _refreshInFlight;

  /// The authorization code from pasted connect-dialog input: either the
  /// raw code or the full redirected URL carrying a `code` parameter.
  /// Null when the input is empty or a URL without a code (e.g. an error
  /// redirect).
  static String? extractAuthorizationCode(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains('://')) {
      final uri = Uri.tryParse(trimmed);
      final code = uri?.queryParameters['code'];
      return (code == null || code.isEmpty) ? null : code;
    }
    return trimmed;
  }

  /// Generates a fresh PKCE verifier and returns the IMS authorize URL to
  /// open in the system browser.
  Uri beginAuthorization({
    required String clientId,
    String? clientSecret,
    String? redirectUri,
  }) {
    if (clientId.trim().isEmpty) {
      throw const CloudStorageException(
        'Enter your Adobe client ID before connecting.',
      );
    }
    final verifier = _generateVerifier();
    _pendingVerifier = verifier;
    _pendingClientId = clientId.trim();
    _pendingClientSecret = (clientSecret == null || clientSecret.trim().isEmpty)
        ? null
        : clientSecret.trim();
    _pendingRedirectUri = (redirectUri == null || redirectUri.trim().isEmpty)
        ? AdobeImsAuthManager.redirectUri
        : redirectUri.trim();
    return _authorizeUri.replace(
      queryParameters: {
        'client_id': _pendingClientId!,
        'scope': scopes,
        'response_type': 'code',
        'redirect_uri': _pendingRedirectUri!,
        'code_challenge': codeChallengeS256(verifier),
        'code_challenge_method': 'S256',
      },
    );
  }

  /// Exchanges the pasted redirected URL (or raw code) for tokens and
  /// persists the connection. Requires a preceding [beginAuthorization]
  /// in this session (the PKCE verifier is memory-only by design).
  Future<LightroomAuthData> completeAuthorization(
    String codeOrRedirectUrl,
  ) async {
    final verifier = _pendingVerifier;
    final clientId = _pendingClientId;
    if (verifier == null || clientId == null) {
      throw const CloudStorageException(
        'No Adobe authorization is in progress. Reopen the connect dialog '
        'and try again.',
      );
    }
    final code = extractAuthorizationCode(codeOrRedirectUrl);
    if (code == null) {
      throw const CloudStorageException(
        'No authorization code found. Paste the full address of the page '
        'the browser landed on after signing in.',
      );
    }
    final tokens = await _requestToken({
      'grant_type': 'authorization_code',
      'client_id': clientId,
      'client_secret': ?_pendingClientSecret,
      'code': code,
      'code_verifier': verifier,
      'redirect_uri': _pendingRedirectUri ?? AdobeImsAuthManager.redirectUri,
    });
    final refreshTokenValue = tokens['refresh_token'];
    final auth = LightroomAuthData(
      clientId: clientId,
      redirectUri: _pendingRedirectUri,
      clientSecret: _pendingClientSecret,
      refreshToken: refreshTokenValue is String && refreshTokenValue.isNotEmpty
          ? refreshTokenValue
          : null,
    );
    await _store.save(auth);
    _pendingVerifier = null;
    _pendingClientId = null;
    _pendingClientSecret = null;
    _pendingRedirectUri = null;
    _cacheAccessToken(tokens);
    _log.info('Lightroom connected');
    return auth;
  }

  /// A currently valid access token, refreshing through the stored refresh
  /// token when needed. Concurrent callers share one refresh request.
  Future<String> getAccessToken() {
    final token = _accessToken;
    final expiry = _accessTokenExpiry;
    if (token != null && expiry != null && _now().isBefore(expiry)) {
      return Future.value(token);
    }
    return _refreshInFlight ??= _refreshAccessToken().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  /// Drops the cached access token so the next [getAccessToken] refreshes.
  void invalidateAccessToken() {
    _accessToken = null;
    _accessTokenExpiry = null;
  }

  /// The stored connection, or null when Lightroom is not connected.
  Future<LightroomAuthData?> loadAuth() => _store.load();

  /// Persists updated connection data (catalog id, account labels).
  Future<void> updateAuth(LightroomAuthData data) => _store.save(data);

  /// Clears the stored connection. IMS offers no client-side revoke for
  /// this flow; forgetting the refresh token ends the app's access.
  Future<void> disconnect() async {
    invalidateAccessToken();
    await _store.clear();
    _log.info('Lightroom disconnected');
  }

  Future<String> _refreshAccessToken() async {
    final auth = await _store.load();
    if (auth == null) {
      throw const CloudStorageException(
        'Lightroom is not connected. Connect Lightroom in Settings.',
      );
    }
    final refreshToken = auth.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const LightroomReauthRequiredException();
    }
    final tokens = await _requestToken({
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
      'client_id': auth.clientId,
      'client_secret': ?auth.clientSecret,
    });
    final rotated = tokens['refresh_token'];
    if (rotated is String && rotated.isNotEmpty && rotated != refreshToken) {
      await _store.save(auth.copyWith(refreshToken: rotated));
    }
    return _cacheAccessToken(tokens);
  }

  /// POSTs [form] to the IMS token endpoint and returns the decoded JSON.
  /// 4xx means the grant was rejected (bad code, revoked refresh token);
  /// the stored blob is intentionally NOT cleared -- only an explicit
  /// disconnect destroys credentials.
  Future<Map<String, Object?>> _requestToken(Map<String, String> form) async {
    final http.Response response;
    try {
      response = await _http.post(_tokenUri, body: form);
    } on Exception catch (e, st) {
      throw CloudStorageException('Could not reach Adobe', e, st);
    }
    if (response.statusCode != 200) {
      throw CloudStorageException(
        response.statusCode >= 400 && response.statusCode < 500
            ? 'Adobe rejected the authorization. Reconnect Lightroom in '
                  'Settings.'
            : 'Adobe authorization failed (${response.statusCode})',
        _bodySummary(response),
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const CloudStorageException(
        'Unexpected response from Adobe authorization.',
      );
    }
    if (decoded is! Map<String, Object?> ||
        decoded['access_token'] is! String) {
      throw const CloudStorageException(
        'Unexpected response from Adobe authorization.',
      );
    }
    return decoded;
  }

  String _cacheAccessToken(Map<String, Object?> tokens) {
    final token = tokens['access_token'] as String;
    final expiresIn = tokens['expires_in'];
    final seconds = expiresIn is int ? expiresIn : 3600;
    _accessToken = token;
    _accessTokenExpiry = _now()
        .add(Duration(seconds: seconds))
        .subtract(_expiryMargin);
    return token;
  }

  static String _bodySummary(http.Response response) {
    final body = response.body;
    return body.length <= 200 ? body : body.substring(0, 200);
  }
}
