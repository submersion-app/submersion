import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as gauth;

import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

/// Persists the desktop Google Drive OAuth credentials (access token,
/// refresh token, expiry, scopes) as a single JSON blob in the platform
/// keychain. One blob keeps load/save atomic; nothing about the Google
/// Drive setup ever touches SharedPreferences or the database.
///
/// A corrupt blob is left in place rather than deleted, so a transient
/// decode bug cannot destroy credentials; save() simply overwrites it.
///
/// Keychain access goes through [FallbackSecureStorage], which retries on
/// the legacy keychain when the ad-hoc no-sandbox build has no access
/// group. Only the desktop authenticator uses this store; the mobile path
/// relies on google_sign_in's own token cache.
class GoogleDriveTokenStore {
  GoogleDriveTokenStore({FlutterSecureStorage? storage})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage());

  final FallbackSecureStorage _storage;

  static const String storageKey = 'sync_gdrive_credentials';

  /// The stored credentials, or null when unset or the stored blob is
  /// corrupt. Keychain errors other than a missing entitlement propagate.
  Future<gauth.AccessCredentials?> load() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return gauth.AccessCredentials.fromJson(decoded);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    } on ArgumentError {
      // AccessToken.fromJson rejects e.g. a non-UTC expiry.
      return null;
    }
  }

  Future<void> save(gauth.AccessCredentials credentials) =>
      _storage.write(key: storageKey, value: jsonEncode(credentials.toJson()));

  Future<void> clear() => _storage.delete(key: storageKey);
}
