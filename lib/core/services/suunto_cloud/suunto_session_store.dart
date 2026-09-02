import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

/// A cached Suunto cloud session: the session key plus the account email
/// shown in the sign-in UI. The password is never persisted -- only this
/// resulting session token is cached, so the diver doesn't have to sign in
/// again next time.
class SuuntoSessionData {
  const SuuntoSessionData({required this.email, required this.sessionKey});

  final String email;
  final String sessionKey;

  Map<String, Object?> toJson() => {'email': email, 'sessionKey': sessionKey};

  factory SuuntoSessionData.fromJson(Map<String, Object?> json) =>
      SuuntoSessionData(
        email: json['email'] as String,
        sessionKey: json['sessionKey'] as String,
      );
}

/// Persists the Suunto cloud session as a single JSON blob in the platform
/// keychain, mirroring `DropboxAuthStore`: one blob keeps load/save atomic;
/// nothing touches SharedPreferences or the database.
///
/// A corrupt blob is left in place rather than deleted, so a transient
/// decode bug cannot destroy credentials; [save] simply overwrites it.
class SuuntoSessionStore {
  SuuntoSessionStore({FlutterSecureStorage? storage})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage());

  final FallbackSecureStorage _storage;

  static const String storageKey = 'suunto_cloud_session';

  /// The stored session, or null when unset or the stored blob is corrupt.
  Future<SuuntoSessionData?> load() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      if (decoded['sessionKey'] is! String || decoded['email'] is! String) {
        return null;
      }
      return SuuntoSessionData.fromJson(decoded);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> save(SuuntoSessionData data) =>
      _storage.write(key: storageKey, value: jsonEncode(data.toJson()));

  Future<void> clear() => _storage.delete(key: storageKey);
}
