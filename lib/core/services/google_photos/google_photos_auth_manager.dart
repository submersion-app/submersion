import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:submersion/core/services/google_photos/google_photos_auth_store.dart';
import 'package:submersion/core/services/google_photos/google_photos_client_config.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/oauth/oauth_pkce.dart';

/// A Google Photos authorization failure surfaced to the user. [message] is
/// already user-facing -- no `Exception:` / class-name prefix.
class GooglePhotosAuthException implements Exception {
  const GooglePhotosAuthException(this.message, [this.detail]);

  final String message;
  final Object? detail;

  @override
  String toString() => message;
}

/// Thrown when the stored grant can no longer be refreshed (the user
/// revoked access in their Google account, or the refresh token expired).
/// The connection must be re-established from scratch.
class GooglePhotosReauthRequiredException extends GooglePhotosAuthException {
  const GooglePhotosReauthRequiredException()
    : super('Google Photos access has expired; connect the account again.');
}

/// OAuth 2 PKCE lifecycle against Google for the Google Photos connector:
/// authorize-URL construction, the redirect code exchange, in-memory
/// access-token caching with single-flight refresh, and disconnect (with a
/// best-effort server-side revoke).
///
/// The redirect transport -- a loopback HTTP server on desktop, the native
/// account sheet on mobile -- is a UI concern and lives above this class:
/// callers hand [beginAuthorization] the redirect URI they will listen on
/// and pass whatever the browser lands on back to [completeAuthorization].
///
/// Google authenticates its "Desktop app" clients at the token endpoint
/// with the client secret (PKCE notwithstanding), so a non-empty
/// [clientSecret] is required for a working connection; see
/// [GooglePhotosClientConfig.desktopClientSecret].
class GooglePhotosAuthManager {
  GooglePhotosAuthManager({
    GooglePhotosAuthStore? store,
    http.Client? httpClient,
    String? clientId,
    String? clientSecret,
    DateTime Function()? now,
    String Function()? verifierGenerator,
  }) : _store = store ?? GooglePhotosAuthStore(),
       _http = httpClient ?? http.Client(),
       _clientId = clientId ?? GooglePhotosClientConfig.desktopClientId,
       _clientSecret =
           clientSecret ?? GooglePhotosClientConfig.desktopClientSecret,
       _now = now ?? DateTime.now,
       _generateVerifier = verifierGenerator ?? generateCodeVerifier;

  static final _log = LoggerService.forClass(GooglePhotosAuthManager);

  static final Uri _authorizeUri = Uri.parse(
    'https://accounts.google.com/o/oauth2/v2/auth',
  );
  static final Uri _tokenUri = Uri.parse('https://oauth2.googleapis.com/token');
  static final Uri _revokeUri = Uri.parse(
    'https://oauth2.googleapis.com/revoke',
  );

  /// `openid` + `email` label the account for the Connected Accounts list;
  /// the picker scope is the one that does the work.
  static const List<String> scopes = [
    'openid',
    'email',
    GooglePhotosClientConfig.pickerScope,
  ];

  /// Refresh slightly before Google's expiry so an access token is never
  /// presented within its final minute.
  static const Duration _expiryMargin = Duration(seconds: 60);

  final GooglePhotosAuthStore _store;
  final http.Client _http;
  final String _clientId;
  final String _clientSecret;
  final DateTime Function() _now;
  final String Function() _generateVerifier;

  String? _pendingVerifier;
  String? _pendingRedirectUri;
  String? _accessToken;
  DateTime? _accessTokenExpiry;
  Future<String>? _refreshInFlight;

  /// The authorization code from a redirect: either the raw code or the
  /// full redirected URL carrying a `code` query parameter. Null when the
  /// input is empty, or a URL without a code (e.g. `?error=access_denied`).
  static String? extractAuthorizationCode(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.contains('://') || trimmed.startsWith('/?')) {
      final uri = Uri.tryParse(trimmed);
      final code = uri?.queryParameters['code'];
      return (code == null || code.isEmpty) ? null : code;
    }
    return trimmed;
  }

  /// Generates a fresh PKCE verifier and returns the Google authorize URL
  /// to open in the system browser. [redirectUri] must match a redirect URI
  /// registered on the OAuth client and is where the browser lands after
  /// consent.
  Uri beginAuthorization({required String redirectUri}) {
    if (_clientId.isEmpty) {
      throw const GooglePhotosAuthException(
        'Google Photos is not configured in this build.',
      );
    }
    final verifier = _generateVerifier();
    _pendingVerifier = verifier;
    _pendingRedirectUri = redirectUri;
    return _authorizeUri.replace(
      queryParameters: {
        'client_id': _clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': scopes.join(' '),
        'code_challenge': codeChallengeS256(verifier),
        'code_challenge_method': 'S256',
        // Ask for a refresh token, and force the consent screen so one is
        // returned even on a re-grant (Google omits it otherwise).
        'access_type': 'offline',
        'prompt': 'consent',
        'include_granted_scopes': 'true',
      },
    );
  }

  /// Exchanges the redirect (or raw code) for tokens and persists the
  /// connection. Requires a preceding [beginAuthorization] in this session
  /// (the PKCE verifier is memory-only by design).
  Future<GooglePhotosAuthData> completeAuthorization(
    String codeOrRedirectUrl,
  ) async {
    final verifier = _pendingVerifier;
    final redirectUri = _pendingRedirectUri;
    if (verifier == null || redirectUri == null) {
      throw const GooglePhotosAuthException(
        'No Google authorization is in progress. Reopen the connect dialog '
        'and try again.',
      );
    }
    final code = extractAuthorizationCode(codeOrRedirectUrl);
    if (code == null) {
      throw const GooglePhotosAuthException(
        'No authorization code found. The browser did not complete the '
        'Google sign-in.',
      );
    }
    final tokens = await _requestToken({
      'grant_type': 'authorization_code',
      'client_id': _clientId,
      'client_secret': _clientSecret,
      'code': code,
      'code_verifier': verifier,
      'redirect_uri': redirectUri,
    });
    final refreshToken = tokens['refresh_token'];
    if (refreshToken is! String || refreshToken.isEmpty) {
      throw const GooglePhotosAuthException(
        'Google did not return a refresh token. Remove Submersion from your '
        "Google account's third-party access and connect again.",
      );
    }
    final email = _emailFromIdToken(tokens['id_token']);
    final auth = GooglePhotosAuthData(
      refreshToken: refreshToken,
      email: email,
      displayName: email,
    );
    await _store.save(auth);
    _pendingVerifier = null;
    _pendingRedirectUri = null;
    _cacheAccessToken(tokens);
    _log.info('Google Photos connected');
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

  /// The stored connection, or null when Google Photos is not connected.
  Future<GooglePhotosAuthData?> loadAuth() => _store.load();

  /// Revokes the grant with Google (best effort) and clears the stored
  /// connection. A failed revoke still clears local state -- forgetting the
  /// refresh token ends the app's access regardless.
  Future<void> disconnect() async {
    invalidateAccessToken();
    final auth = await _store.load();
    final refreshToken = auth?.refreshToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await _http.post(_revokeUri, body: {'token': refreshToken});
      } on Exception catch (e) {
        _log.warning('Google Photos revoke failed (clearing locally): $e');
      }
    }
    await _store.clear();
    _log.info('Google Photos disconnected');
  }

  Future<String> _refreshAccessToken() async {
    final auth = await _store.load();
    if (auth == null) {
      throw const GooglePhotosAuthException(
        'Google Photos is not connected. Connect the account in Settings.',
      );
    }
    final Map<String, Object?> tokens;
    try {
      tokens = await _requestToken({
        'grant_type': 'refresh_token',
        'refresh_token': auth.refreshToken,
        'client_id': _clientId,
        'client_secret': _clientSecret,
      });
    } on GooglePhotosAuthException catch (e) {
      // A 4xx on a refresh_token grant means the grant is gone for good.
      if (e.detail == _grantRejected) {
        throw const GooglePhotosReauthRequiredException();
      }
      rethrow;
    }
    return _cacheAccessToken(tokens);
  }

  static const Object _grantRejected = Object();

  /// POSTs [form] to Google's token endpoint and returns the decoded JSON.
  /// A 4xx carries [_grantRejected] as the exception detail so the refresh
  /// path can turn it into [GooglePhotosReauthRequiredException]; the
  /// stored blob is intentionally NOT cleared here -- only an explicit
  /// [disconnect] destroys credentials.
  Future<Map<String, Object?>> _requestToken(Map<String, String> form) async {
    final http.Response response;
    try {
      response = await _http.post(_tokenUri, body: form);
    } on Exception catch (e, st) {
      throw GooglePhotosAuthException('Could not reach Google', (e, st));
    }
    if (response.statusCode != 200) {
      final rejected = response.statusCode >= 400 && response.statusCode < 500;
      throw GooglePhotosAuthException(
        rejected
            ? 'Google rejected the authorization. Connect Google Photos '
                  'again in Settings.'
            : 'Google authorization failed (${response.statusCode})',
        rejected ? _grantRejected : _bodySummary(response),
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const GooglePhotosAuthException(
        'Unexpected response from Google authorization.',
      );
    }
    if (decoded is! Map<String, Object?> ||
        decoded['access_token'] is! String) {
      throw const GooglePhotosAuthException(
        'Unexpected response from Google authorization.',
      );
    }
    return decoded;
  }

  String _cacheAccessToken(Map<String, Object?> tokens) {
    final token = tokens['access_token'] as String;
    final expiresIn = tokens['expires_in'];
    final seconds = expiresIn is int
        ? expiresIn
        : expiresIn is String
        ? int.tryParse(expiresIn) ?? 3600
        : 3600;
    _accessToken = token;
    _accessTokenExpiry = _now()
        .add(Duration(seconds: seconds))
        .subtract(_expiryMargin);
    return token;
  }

  /// Pulls the `email` claim out of an unverified id_token payload. The
  /// token came straight from Google's HTTPS token endpoint over the
  /// exchange we initiated, so it is used only as a display label, never
  /// as an authorization decision -- no signature check is warranted.
  static String? _emailFromIdToken(Object? idToken) {
    if (idToken is! String) return null;
    final parts = idToken.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = utf8.decode(base64Url.decode(base64.normalize(parts[1])));
      final claims = jsonDecode(payload);
      final email = claims is Map<String, Object?> ? claims['email'] : null;
      return email is String && email.isNotEmpty ? email : null;
    } on Object {
      return null;
    }
  }

  static String _bodySummary(http.Response response) {
    final body = response.body;
    return body.length <= 200 ? body : body.substring(0, 200);
  }
}
