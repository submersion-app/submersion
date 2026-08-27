import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

/// The persisted Dropbox connection: the long-lived refresh token plus the
/// account labels shown in the settings UI. Access tokens are short-lived
/// and kept in memory only (DropboxAuthManager).
class DropboxAuthData {
  DropboxAuthData({required this.refreshToken, this.email, this.displayName});

  final String refreshToken;
  final String? email;
  final String? displayName;

  Map<String, Object?> toJson() => {
    'refreshToken': refreshToken,
    'email': email,
    'displayName': displayName,
  };

  /// Null-signalling parse is done by [DropboxAuthStore.load]; this factory
  /// assumes [json] already carries a string refreshToken.
  factory DropboxAuthData.fromJson(Map<String, Object?> json) =>
      DropboxAuthData(
        refreshToken: json['refreshToken'] as String,
        email: json['email'] as String?,
        displayName: json['displayName'] as String?,
      );
}

/// Persists the Dropbox connection -- refresh token included -- as a single
/// JSON blob in the platform keychain, mirroring S3CredentialsStore: one
/// blob keeps load/save atomic; nothing touches SharedPreferences or the
/// database.
///
/// A corrupt blob is left in place rather than deleted, so a transient
/// decode bug cannot destroy credentials; save() simply overwrites it.
///
/// Keychain access goes through [FallbackSecureStorage], which retries on
/// the legacy keychain when the ad-hoc no-sandbox build has no access group.
class DropboxAuthStore {
  /// [storageKey] overrides the legacy sync-auth key; the Connected
  /// Accounts layer passes per-account keys (`account_<id>_credentials`).
  DropboxAuthStore({FlutterSecureStorage? storage, String? storageKey})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage()),
      _storageKey = storageKey ?? DropboxAuthStore.storageKey;

  final FallbackSecureStorage _storage;
  final String _storageKey;

  static const String storageKey = 'sync_dropbox_auth';

  /// The stored connection, or null when unset or the stored blob is
  /// corrupt. Keychain errors other than a missing entitlement propagate.
  Future<DropboxAuthData?> load() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      if (decoded['refreshToken'] is! String) return null;
      return DropboxAuthData.fromJson(decoded);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> save(DropboxAuthData data) =>
      _storage.write(key: _storageKey, value: jsonEncode(data.toJson()));

  Future<void> clear() => _storage.delete(key: _storageKey);
}
