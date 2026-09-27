import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

/// A cached divelogs.de session: the JWT and the username shown in the
/// sign-in step. The password is never persisted.
class DivelogsSession {
  const DivelogsSession({required this.username, required this.token});

  final String username;
  final String token;

  Map<String, Object?> toJson() => {'username': username, 'token': token};
}

/// Persists the divelogs.de session as one JSON blob in the platform
/// keychain, mirroring `SuuntoSessionStore`. A corrupt blob is left in
/// place rather than deleted, so a transient decode bug cannot destroy a
/// session; [save] overwrites it.
class DivelogsSessionStore {
  DivelogsSessionStore({FlutterSecureStorage? storage})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage());

  final FallbackSecureStorage _storage;

  static const String storageKey = 'divelogs_session';

  /// The stored session, or null when unset or the blob is corrupt.
  Future<DivelogsSession?> load() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      final username = decoded['username'];
      final token = decoded['token'];
      if (username is! String || token is! String) return null;
      return DivelogsSession(username: username, token: token);
    } on FormatException {
      return null;
    }
  }

  Future<void> save(DivelogsSession session) =>
      _storage.write(key: storageKey, value: jsonEncode(session.toJson()));

  Future<void> clear() => _storage.delete(key: storageKey);
}
