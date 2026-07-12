import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_app.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_store.dart';
import 'package:submersion/core/services/oauth/oauth_pkce.dart';
import 'package:submersion/core/services/logger_service.dart';

/// OAuth 2 PKCE lifecycle for Dropbox: authorize-URL construction, the
/// copy-paste code exchange, in-memory access-token caching with
/// single-flight refresh, and disconnect.
///
/// The refresh token is the only persisted credential (DropboxAuthStore);
/// access tokens (~4 h lifetime) live in memory only.
class DropboxAuthManager {
  DropboxAuthManager({
    this.appKey = dropboxAppKey,
    DropboxAuthStore? store,
    http.Client? httpClient,
    DateTime Function()? now,
    String Function()? verifierGenerator,
  }) : _store = store ?? DropboxAuthStore(),
       _http = httpClient ?? http.Client(),
       _now = now ?? DateTime.now,
       _generateVerifier = verifierGenerator ?? generateCodeVerifier;

  static final _log = LoggerService.forClass(DropboxAuthManager);

  static final Uri _authorizeUri = Uri.parse(
    'https://www.dropbox.com/oauth2/authorize',
  );
  static final Uri _tokenUri = Uri.parse(
    'https://api.dropboxapi.com/oauth2/token',
  );
  static final Uri _revokeUri = Uri.parse(
    'https://api.dropboxapi.com/2/auth/token/revoke',
  );
  static final Uri _accountUri = Uri.parse(
    'https://api.dropboxapi.com/2/users/get_current_account',
  );

  /// Refresh slightly before Dropbox's expiry so an access token is never
  /// presented within its final minute.
  static const Duration _expiryMargin = Duration(seconds: 60);

  final String appKey;
  final DropboxAuthStore _store;
  final http.Client _http;
  final DateTime Function() _now;
  final String Function() _generateVerifier;

  String? _pendingVerifier;
  String? _accessToken;
  DateTime? _accessTokenExpiry;
  Future<String>? _refreshInFlight;

  /// Generates a fresh PKCE verifier and returns the authorize URL to open
  /// in the system browser. No redirect_uri: Dropbox then displays the
  /// authorization code for the user to copy into the app.
  Uri beginAuthorization() {
    if (appKey.isEmpty) {
      throw const CloudStorageException(
        'Dropbox is not configured in this build (missing app key).',
      );
    }
    final verifier = _generateVerifier();
    _pendingVerifier = verifier;
    return _authorizeUri.replace(
      queryParameters: {
        'client_id': appKey,
        'response_type': 'code',
        'code_challenge': codeChallengeS256(verifier),
        'code_challenge_method': 'S256',
        'token_access_type': 'offline',
      },
    );
  }

  /// Exchanges the pasted [code] for tokens, fetches the account labels,
  /// and persists the connection. Requires a preceding [beginAuthorization]
  /// in this session (the PKCE verifier is memory-only by design).
  Future<DropboxAuthData> completeAuthorization(String code) async {
    final verifier = _pendingVerifier;
    if (verifier == null) {
      throw const CloudStorageException(
        'No Dropbox authorization is in progress. Reopen the connect '
        'dialog and try again.',
      );
    }
    final tokens = await _requestToken({
      'code': code,
      'grant_type': 'authorization_code',
      'code_verifier': verifier,
      'client_id': appKey,
    });
    final refreshToken = tokens['refresh_token'];
    if (refreshToken is! String || refreshToken.isEmpty) {
      throw const CloudStorageException(
        'Dropbox did not return a refresh token.',
      );
    }

    String? email;
    String? displayName;
    try {
      final account = await _fetchAccount(tokens['access_token'] as String);
      email = account.$1;
      displayName = account.$2;
    } catch (e) {
      // Account labels are cosmetic; the connection itself succeeded, so
      // no account-fetch failure of any kind may abort the connect.
      _log.warning('Could not fetch Dropbox account info: $e');
    }

    final auth = DropboxAuthData(
      refreshToken: refreshToken,
      email: email,
      displayName: displayName,
    );
    await _store.save(auth);
    _pendingVerifier = null;
    _cacheAccessToken(tokens);
    _log.info('Dropbox connected');
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
  /// Called by the API client when Dropbox rejects a token mid-flight.
  void invalidateAccessToken() {
    _accessToken = null;
    _accessTokenExpiry = null;
  }

  /// The stored connection, or null when Dropbox is not connected.
  Future<DropboxAuthData?> loadAuth() => _store.load();

  /// Revokes the session best-effort (a network failure must not block
  /// disconnecting) and clears the stored connection.
  Future<void> disconnect() async {
    try {
      final token = await getAccessToken();
      await _http.post(_revokeUri, headers: {'Authorization': 'Bearer $token'});
    } on Exception catch (e) {
      _log.warning('Dropbox token revoke failed (ignored): $e');
    }
    invalidateAccessToken();
    await _store.clear();
    _log.info('Dropbox disconnected');
  }

  Future<String> _refreshAccessToken() async {
    final auth = await _store.load();
    if (auth == null) {
      throw const CloudStorageException(
        'Dropbox is not connected. Connect Dropbox in the Cloud Sync '
        'settings.',
      );
    }
    final tokens = await _requestToken({
      'grant_type': 'refresh_token',
      'refresh_token': auth.refreshToken,
      'client_id': appKey,
    });
    return _cacheAccessToken(tokens);
  }

  /// POSTs [form] to the token endpoint and returns the decoded JSON.
  /// 4xx means the grant was rejected (bad code, revoked refresh token);
  /// the stored blob is intentionally NOT cleared -- only an explicit
  /// disconnect destroys credentials.
  Future<Map<String, Object?>> _requestToken(Map<String, String> form) async {
    final http.Response response;
    try {
      response = await _http.post(_tokenUri, body: form);
    } on Exception catch (e, st) {
      throw CloudStorageException('Could not reach Dropbox', e, st);
    }
    if (response.statusCode != 200) {
      throw CloudStorageException(
        response.statusCode >= 400 && response.statusCode < 500
            ? 'Dropbox rejected the authorization. Reconnect Dropbox in '
                  'the Cloud Sync settings.'
            : 'Dropbox authorization failed (${response.statusCode})',
        _bodySummary(response),
      );
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const CloudStorageException(
        'Unexpected response from Dropbox authorization.',
      );
    }
    if (decoded is! Map<String, Object?> ||
        decoded['access_token'] is! String) {
      throw const CloudStorageException(
        'Unexpected response from Dropbox authorization.',
      );
    }
    return decoded;
  }

  String _cacheAccessToken(Map<String, Object?> tokens) {
    final token = tokens['access_token'] as String;
    final expiresIn = tokens['expires_in'];
    final seconds = expiresIn is int ? expiresIn : 14400;
    _accessToken = token;
    _accessTokenExpiry = _now()
        .add(Duration(seconds: seconds))
        .subtract(_expiryMargin);
    return token;
  }

  /// (email, displayName) from /users/get_current_account.
  Future<(String?, String?)> _fetchAccount(String accessToken) async {
    final response = await _http.post(
      _accountUri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: 'null',
    );
    if (response.statusCode != 200) {
      throw http.ClientException('account fetch ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) return (null, null);
    final email = decoded['email'];
    final name = decoded['name'];
    final displayName = name is Map<String, Object?>
        ? name['display_name']
        : null;
    return (
      email is String ? email : null,
      displayName is String ? displayName : null,
    );
  }

  static String _bodySummary(http.Response response) {
    final body = response.body;
    return body.length <= 200 ? body : body.substring(0, 200);
  }
}
