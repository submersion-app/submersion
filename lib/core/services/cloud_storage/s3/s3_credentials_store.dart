import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';

/// Persists the S3 sync configuration -- secrets included -- as a single
/// JSON blob in the platform keychain. One blob keeps load/save atomic;
/// nothing about the S3 setup ever touches SharedPreferences or the
/// database.
class S3CredentialsStore {
  S3CredentialsStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String storageKey = 'sync_s3_config';

  /// The stored config, or null when unset or unreadable.
  Future<S3Config?> load() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null) return null;
    try {
      return S3Config.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on FormatException {
      return null;
    }
  }

  Future<void> save(S3Config config) =>
      _storage.write(key: storageKey, value: jsonEncode(config.toJson()));

  Future<void> clear() => _storage.delete(key: storageKey);
}
