import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

/// Persists the S3 sync configuration -- secrets included -- as a single
/// JSON blob in the platform keychain. One blob keeps load/save atomic;
/// nothing about the S3 setup ever touches SharedPreferences or the
/// database.
///
/// A corrupt blob is left in place rather than deleted, so a transient
/// decode bug cannot destroy credentials; save() simply overwrites it.
///
/// Keychain access goes through [FallbackSecureStorage], which retries on the
/// legacy keychain when the ad-hoc no-sandbox build has no access group.
class S3CredentialsStore {
  S3CredentialsStore({FlutterSecureStorage? storage})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage());

  final FallbackSecureStorage _storage;

  static const String storageKey = 'sync_s3_config';

  /// The stored config, or null when unset or the stored blob is corrupt.
  /// Keychain errors other than a missing entitlement propagate.
  Future<S3Config?> load() async {
    final raw = await _storage.read(key: storageKey);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return null;
      return S3Config.fromJson(decoded);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> save(S3Config config) =>
      _storage.write(key: storageKey, value: jsonEncode(config.toJson()));

  Future<void> clear() => _storage.delete(key: storageKey);
}
