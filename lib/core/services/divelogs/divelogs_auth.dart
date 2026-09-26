import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:submersion/core/services/divelogs/divelogs_session_store.dart';

/// Why a divelogs.de sign-in failed.
enum DivelogsAuthFailure { badCredentials, unreachable, unexpectedResponse }

class DivelogsAuthException implements Exception {
  const DivelogsAuthException(this.reason);

  final DivelogsAuthFailure reason;

  @override
  String toString() => 'DivelogsAuthException(${reason.name})';
}

/// The session is gone and there is no password in memory to renew it:
/// the user has to sign in again.
class DivelogsSessionExpiredException implements Exception {
  const DivelogsSessionExpiredException();

  @override
  String toString() => 'DivelogsSessionExpiredException';
}

/// Owns the divelogs.de JWT for one import wizard run.
///
/// divelogs.de has no OAuth: POST /login with username and password returns
/// a JWT. The token and username are cached in the keychain; the password
/// is kept in memory only, for this object's lifetime, so a token that
/// expires mid-import can be renewed without asking again. A session
/// restored from the keychain has no password, so when its token is
/// rejected the session is cleared and the user signs in again.
class DivelogsAuth {
  DivelogsAuth({
    required http.Client httpClient,
    required DivelogsSessionStore store,
    Uri? loginUri,
  }) : _http = httpClient,
       _store = store,
       _loginUri = loginUri ?? Uri.parse('https://divelogs.de/api/login');

  final http.Client _http;
  final DivelogsSessionStore _store;
  final Uri _loginUri;

  String? _username;
  String? _password;
  String? _token;
  Future<String>? _renewal;

  /// Bumped by every sign-in and sign-out. A renewal that started under an
  /// earlier generation must not install its token: the account it belongs
  /// to has been signed out of, or replaced, while it was in flight.
  int _generation = 0;

  String? get username => _username;

  /// Logs in and caches the session. Throws [DivelogsAuthException].
  Future<void> signIn(String username, String password) async {
    final generation = ++_generation;
    final token = await _login(username, password);
    if (generation != _generation) {
      throw const DivelogsSessionExpiredException();
    }
    _username = username;
    _password = password;
    _token = token;
    await _store.save(DivelogsSession(username: username, token: token));
  }

  /// Loads a cached session. True when one exists; its token may still be
  /// rejected by the server, which the caller finds out on first use.
  Future<bool> restore() async {
    final session = await _store.load();
    if (session == null) return false;
    _username = session.username;
    _token = session.token;
    return true;
  }

  /// The current token, renewing it once (single-flight) when a 401
  /// invalidated it and the password is known.
  Future<String> getToken() async {
    final token = _token;
    if (token != null) return token;
    final username = _username;
    final password = _password;
    if (username == null || password == null) {
      await _store.clear();
      throw const DivelogsSessionExpiredException();
    }
    return _renewal ??= _renew(username, password).whenComplete(() {
      _renewal = null;
    });
  }

  Future<String> _renew(String username, String password) async {
    final generation = _generation;
    final token = await _login(username, password);
    if (generation != _generation) {
      throw const DivelogsSessionExpiredException();
    }
    _token = token;
    await _store.save(DivelogsSession(username: username, token: token));
    return token;
  }

  /// Called by the API client when a request came back 401.
  void invalidateToken() {
    _token = null;
  }

  /// Forgets the session. The keychain is cleared first: if it refuses,
  /// the error propagates and the in-memory session stays, so a sign-out
  /// that did not happen is never reported as one (the cached token would
  /// otherwise sign the same account straight back in next time). Any
  /// renewal in flight is abandoned either way.
  Future<void> signOut() async {
    _generation++;
    _renewal = null;
    await _store.clear();
    _username = null;
    _password = null;
    _token = null;
  }

  Future<String> _login(String username, String password) async {
    final request = http.MultipartRequest('POST', _loginUri)
      ..fields['user'] = username
      ..fields['pass'] = password;
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request));
    } on Exception {
      throw const DivelogsAuthException(DivelogsAuthFailure.unreachable);
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const DivelogsAuthException(DivelogsAuthFailure.badCredentials);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const DivelogsAuthException(DivelogsAuthFailure.unexpectedResponse);
    }
    final token = _extractToken(response.body);
    if (token == null) {
      throw const DivelogsAuthException(DivelogsAuthFailure.unexpectedResponse);
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
      return null;
    }
    return null;
  }
}
