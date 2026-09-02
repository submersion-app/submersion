import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/garmin_connect/garmin_auth_tokens.dart';
import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

/// The cached Garmin session: the long-lived OAuth 1 token plus the account
/// email shown in the sign-in UI. The password is never persisted -- only
/// this resulting token, which Garmin can revoke independently of it.
class GarminSessionData {
  const GarminSessionData({required this.email, required this.token});

  final String email;
  final GarminOAuth1Token token;

  Map<String, Object?> toJson() => {'email': email, ...token.toJson()};

  factory GarminSessionData.fromJson(Map<String, Object?> json) =>
      GarminSessionData(
        email: json['email'] as String,
        token: GarminOAuth1Token.fromJson(json),
      );
}

/// Persists the Garmin session as a single JSON blob in the platform
/// keychain, mirroring `SuuntoSessionStore`/`DropboxAuthStore`: one blob
/// keeps load/save atomic; nothing touches SharedPreferences or the
/// database.
///
/// A corrupt blob is left in place rather than deleted, so a transient
/// decode bug cannot destroy credentials; [save] simply overwrites it.
class GarminSessionStore {
  GarminSessionStore({FlutterSecureStorage? storage})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage());

  final FallbackSecureStorage _storage;

  static const String storageKey = 'garmin_connect_session';

  /// The stored session, or null when unset or the stored blob is corrupt.
  Future<GarminSessionData?> load() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      if (decoded['email'] is! String ||
          decoded['token'] is! String ||
          decoded['tokenSecret'] is! String) {
        return null;
      }
      return GarminSessionData.fromJson(decoded);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> save(GarminSessionData data) =>
      _storage.write(key: storageKey, value: jsonEncode(data.toJson()));

  Future<void> clear() => _storage.delete(key: storageKey);
}
