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

  /// Makes the per-account key an EXACT mirror of a legacy source-of-truth
  /// key: copies the blob when present, deletes the per-account key when the
  /// legacy key is absent. Used by account-first sync resolution so a
  /// cleared legacy credential (sign-out / remove) can neither be read from
  /// nor resurrected into the per-account key. The legacy key is left
  /// untouched (it remains the source of truth).
  Future<void> mirrorLegacy({
    required String legacyKey,
    required String accountId,
  }) async {
    final legacy = await _storage.read(key: legacyKey);
    if (legacy != null) {
      await write(accountId, legacy);
    } else {
      await delete(accountId);
    }
  }

  /// Copies a legacy single-key blob to the per-account key. Keeps the
  /// legacy entry (rollback safety).
  ///
  /// By default (`overwrite: false`) an existing per-account blob is left
  /// untouched, which keeps the one-time startup migration idempotent. The
  /// connect flow passes `overwrite: true` to REFRESH the per-account blob
  /// from the legacy key: after the user re-authenticates the underlying
  /// provider (e.g. re-links Dropbox in Cloud Sync, rotating
  /// `sync_dropbox_auth`), a stale per-account copy would otherwise make
  /// account-first runtime resolution fail with revoked credentials.
  Future<void> rekeyFromLegacy({
    required String legacyKey,
    required String accountId,
    bool overwrite = false,
  }) async {
    if (!overwrite && await read(accountId) != null) return;
    final legacy = await _storage.read(key: legacyKey);
    if (legacy == null) return;
    await write(accountId, legacy);
  }
}
