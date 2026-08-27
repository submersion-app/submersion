import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/divelogs/divelogs_credentials.dart';

class DivelogsAuthException implements Exception {
  final String message;
  const DivelogsAuthException(this.message);

  @override
  String toString() => 'DivelogsAuthException: $message';
}

/// Owns the divelogs.de JWT lifecycle for one connected account.
///
/// divelogs.de has no OAuth: POST /login with username/password returns a
/// JWT. Renewal is 401-driven — the API client calls [invalidateToken] and
/// retries once, which triggers a fresh login here.
class DivelogsAuthManager {
  DivelogsAuthManager({
    required AccountCredentialsStore credentials,
    required this.accountId,
    http.Client? httpClient,
  }) : _credentials = credentials,
       _http = httpClient ?? http.Client();

  static final Uri loginUri = Uri.parse('https://divelogs.de/api/login');

  final AccountCredentialsStore _credentials;
  final String accountId;
  final http.Client _http;

  String? _cachedToken;
  bool _forceRelogin = false;
  Future<String>? _loginInFlight;

  /// Unauthenticated login. Used by the connect flow to validate credentials
  /// before a ConnectedAccount exists, and internally for renewal.
  static Future<String> login({
    required String username,
    required String password,
    http.Client? httpClient,
  }) async {
    final client = httpClient ?? http.Client();
    final request = http.MultipartRequest('POST', loginUri)
      ..fields['user'] = username
      ..fields['pass'] = password;
    final http.Response response;
    try {
      response = await http.Response.fromStream(await client.send(request));
    } on Exception {
      throw const DivelogsAuthException('Could not reach divelogs.de.');
    }
    if (response.statusCode == 401) {
      throw const DivelogsAuthException(
        'divelogs.de rejected the username or password.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DivelogsAuthException(
        'divelogs.de login failed (HTTP ${response.statusCode}).',
      );
    }
    final token = _extractToken(response.body);
    if (token == null) {
      throw const DivelogsAuthException(
        'divelogs.de login response did not contain a token.',
      );
    }
    return token;
  }

  static String? _extractToken(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        for (final key in const ['bearer_token', 'token', 'access_token']) {
          final value = decoded[key];
          if (value is String && value.isNotEmpty) return value;
        }
      }
    } on FormatException {
      // fall through
    }
    return null;
  }

  Future<String> getToken() {
    final cached = _cachedToken;
    if (cached != null) return Future.value(cached);
    return _loginInFlight ??= _resolveToken().whenComplete(() {
      _loginInFlight = null;
    });
  }

  Future<String> _resolveToken() async {
    final stored = DivelogsCredentials.fromJsonString(
      await _credentials.read(accountId),
    );
    if (stored == null) {
      throw const DivelogsAuthException('Not signed in to divelogs.de.');
    }
    final persisted = stored.bearerToken;
    if (!_forceRelogin && persisted != null && persisted.isNotEmpty) {
      _cachedToken = persisted;
      return persisted;
    }
    final token = await login(
      username: stored.username,
      password: stored.password,
      httpClient: _http,
    );
    _forceRelogin = false;
    _cachedToken = token;
    await _credentials.write(
      accountId,
      stored.copyWith(bearerToken: token).toJsonString(),
    );
    return token;
  }

  /// Called by the API client when a request came back 401.
  void invalidateToken() {
    _cachedToken = null;
    _forceRelogin = true;
  }

  Future<void> disconnect() async {
    _cachedToken = null;
    _forceRelogin = false;
    await _credentials.delete(accountId);
  }
}
