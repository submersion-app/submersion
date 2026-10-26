import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/cloud_storage/git/git_config.dart';
import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

/// Persists a Git configuration, token included, as one JSON blob in the
/// platform keychain (the WebDavCredentialsStore pattern). A corrupt blob
/// reads as null and is left for save() to overwrite.
class GitCredentialsStore {
  /// [storageKey] overrides the sync key; the accounts layer passes
  /// per-account keys (`account_<id>_credentials`).
  GitCredentialsStore({FlutterSecureStorage? storage, String? storageKey})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage()),
      _storageKey = storageKey ?? GitCredentialsStore.storageKey;

  final FallbackSecureStorage _storage;
  final String _storageKey;

  static const String storageKey = 'sync_git_config';

  Future<GitConfig?> load() async =>
      decodeGitConfig(await _storage.read(key: _storageKey));

  Future<void> save(GitConfig config) =>
      _storage.write(key: _storageKey, value: jsonEncode(config.toJson()));

  Future<void> clear() => _storage.delete(key: _storageKey);
}

/// Null for an absent or malformed blob; never throws.
GitConfig? decodeGitConfig(String? raw) {
  if (raw == null) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) return null;
    return GitConfig.fromJson(decoded);
  } on FormatException {
    return null;
  } on TypeError {
    return null;
  }
}
