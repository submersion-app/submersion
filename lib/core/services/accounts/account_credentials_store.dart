import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

/// Per-account keychain blobs under `account_<id>_credentials`. The payload
/// is an opaque JSON string owned by the account's adapter (S3Config JSON,
/// Dropbox refresh-token blob, Adobe IMS tokens, ...). Mirrors the legacy
/// single-key stores (S3CredentialsStore etc.), which remain readable for
/// rollback; migration copies rather than moves.
class AccountCredentialsStore {
  AccountCredentialsStore({FlutterSecureStorage? storage})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage());

  final FallbackSecureStorage _storage;

  static String keyFor(String accountId) => 'account_${accountId}_credentials';

  Future<String?> read(String accountId) =>
      _storage.read(key: keyFor(accountId));

  Future<void> write(String accountId, String json) =>
      _storage.write(key: keyFor(accountId), value: json);

  Future<void> delete(String accountId) =>
      _storage.delete(key: keyFor(accountId));

  /// Copies a legacy single-key blob to the per-account key. Keeps the
  /// legacy entry (rollback safety) and never overwrites an existing
  /// per-account blob (idempotent across repeated startups).
  Future<void> rekeyFromLegacy({
    required String legacyKey,
    required String accountId,
  }) async {
    if (await read(accountId) != null) return;
    final legacy = await _storage.read(key: legacyKey);
    if (legacy == null) return;
    await write(accountId, legacy);
  }
}
