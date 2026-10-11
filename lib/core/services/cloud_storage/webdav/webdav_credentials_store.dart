import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

/// Persists a WebDAV configuration, password included, as one JSON blob in
/// the platform keychain (the S3CredentialsStore pattern). A corrupt blob
/// reads as null and is left for save() to overwrite.
class WebDavCredentialsStore {
  /// [storageKey] overrides the legacy sync key; the accounts layer passes
  /// per-account keys (`account_<id>_credentials`).
  WebDavCredentialsStore({FlutterSecureStorage? storage, String? storageKey})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage()),
      _storageKey = storageKey ?? WebDavCredentialsStore.storageKey;

  final FallbackSecureStorage _storage;
  final String _storageKey;

  static const String storageKey = 'sync_webdav_config';

  Future<WebDavConfig?> load() async {
    final raw = await _storage.read(key: _storageKey);
    return decodeWebDavConfig(raw);
  }

  Future<void> save(WebDavConfig config) =>
      _storage.write(key: _storageKey, value: jsonEncode(config.toJson()));

  Future<void> clear() => _storage.delete(key: _storageKey);
}

/// Null for an absent or malformed blob; never throws.
WebDavConfig? decodeWebDavConfig(String? raw) {
  if (raw == null) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) return null;
    return WebDavConfig.fromJson(decoded);
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}
