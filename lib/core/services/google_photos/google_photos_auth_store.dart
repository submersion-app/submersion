import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

/// Persisted Google Photos connection credentials.
///
/// Unlike the Lightroom connector, the OAuth client is the app's own
/// (compile-time, see [GooglePhotosClientConfig]), so the blob holds only
/// the per-user grant: the long-lived refresh token plus a display label
/// for the Connected Accounts list. The short-lived access token is cached
/// in memory by [GooglePhotosAuthManager] and never written here.
class GooglePhotosAuthData {
  const GooglePhotosAuthData({
    required this.refreshToken,
    this.email,
    this.displayName,
  });

  /// The offline-access refresh token returned by Google's token endpoint.
  final String refreshToken;

  final String? email;
  final String? displayName;

  GooglePhotosAuthData copyWith({
    String? refreshToken,
    String? email,
    String? displayName,
  }) {
    return GooglePhotosAuthData(
      refreshToken: refreshToken ?? this.refreshToken,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
    );
  }

  Map<String, Object?> toJson() => {
    'refreshToken': refreshToken,
    'email': email,
    'displayName': displayName,
  };

  factory GooglePhotosAuthData.fromJson(Map<String, Object?> json) {
    return GooglePhotosAuthData(
      refreshToken: json['refreshToken'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
    );
  }
}

/// Secure-storage persistence for the Google Photos connection. One JSON
/// blob under a single key so load/save stay atomic (S3/Dropbox/Lightroom
/// precedent).
class GooglePhotosAuthStore {
  /// [storageKey] overrides the default single-connection key; the
  /// Connected Accounts layer passes per-account keys
  /// (`account_<id>_credentials`).
  GooglePhotosAuthStore({FlutterSecureStorage? storage, String? storageKey})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage()),
      _storageKey = storageKey ?? GooglePhotosAuthStore.storageKey;

  static const String storageKey = 'google_photos_auth';

  final String _storageKey;

  final FallbackSecureStorage _storage;

  /// Null when unset or when the stored blob does not decode. A corrupt
  /// blob is left in place so a decode bug cannot destroy credentials.
  Future<GooglePhotosAuthData?> load() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return GooglePhotosAuthData.fromJson(
        jsonDecode(raw) as Map<String, Object?>,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> save(GooglePhotosAuthData data) =>
      _storage.write(key: _storageKey, value: jsonEncode(data.toJson()));

  Future<void> clear() => _storage.delete(key: _storageKey);
}
