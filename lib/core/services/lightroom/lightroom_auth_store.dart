import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

/// Persisted Lightroom connection credentials. BYO client id: the user's
/// own Adobe Developer Console credentials live alongside the refresh
/// token so the whole connection is one atomic blob.
class LightroomAuthData {
  const LightroomAuthData({
    required this.clientId,
    this.redirectUri,
    this.refreshToken,
    this.clientSecret,
    this.email,
    this.displayName,
    this.catalogId,
  });

  final String clientId;

  /// The redirect URI this connection authorized against. For a Native App
  /// credential this is Adobe's generated custom scheme; null on legacy
  /// blobs saved before per-connection redirects existed.
  final String? redirectUri;

  /// Null for a Native App credential (public clients get no refresh token)
  /// or on a legacy blob; present only when Adobe returned one.
  final String? refreshToken;

  final String? clientSecret;
  final String? email;
  final String? displayName;
  final String? catalogId;

  LightroomAuthData copyWith({
    String? redirectUri,
    String? refreshToken,
    String? email,
    String? displayName,
    String? catalogId,
  }) {
    return LightroomAuthData(
      clientId: clientId,
      redirectUri: redirectUri ?? this.redirectUri,
      refreshToken: refreshToken ?? this.refreshToken,
      clientSecret: clientSecret,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      catalogId: catalogId ?? this.catalogId,
    );
  }

  Map<String, Object?> toJson() => {
    'clientId': clientId,
    'redirectUri': redirectUri,
    'clientSecret': clientSecret,
    'refreshToken': refreshToken,
    'email': email,
    'displayName': displayName,
    'catalogId': catalogId,
  };

  factory LightroomAuthData.fromJson(Map<String, Object?> json) {
    return LightroomAuthData(
      clientId: json['clientId'] as String,
      redirectUri: json['redirectUri'] as String?,
      clientSecret: json['clientSecret'] as String?,
      refreshToken: json['refreshToken'] as String?,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      catalogId: json['catalogId'] as String?,
    );
  }
}

/// Secure-storage persistence for the Lightroom connection. One JSON blob
/// under a single key so load/save stay atomic (S3/Dropbox precedent).
class LightroomAuthStore {
  /// [storageKey] overrides the legacy single-connection key; the Connected
  /// Accounts layer passes per-account keys (`account_<id>_credentials`).
  LightroomAuthStore({FlutterSecureStorage? storage, String? storageKey})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage()),
      _storageKey = storageKey ?? LightroomAuthStore.storageKey;

  static const String storageKey = 'lightroom_auth';

  final String _storageKey;

  final FallbackSecureStorage _storage;

  /// Null when unset or when the stored blob does not decode. A corrupt
  /// blob is left in place so a decode bug cannot destroy credentials.
  Future<LightroomAuthData?> load() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return LightroomAuthData.fromJson(
        jsonDecode(raw) as Map<String, Object?>,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> save(LightroomAuthData data) =>
      _storage.write(key: _storageKey, value: jsonEncode(data.toJson()));

  Future<void> clear() => _storage.delete(key: _storageKey);
}
