import 'dart:convert';

import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_api_client.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/s3_storage_provider.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/s3_media_object_store.dart';

/// S3 endpoints as accounts. The whole S3Config (secrets included) is the
/// per-account keychain payload; multiple S3 accounts are first-class (sync
/// and media storage can point at different endpoints or buckets).
class S3AccountAdapter extends AccountProviderAdapter
    implements SyncCapable, MediaStoreCapable {
  S3AccountAdapter({AccountCredentialsStore? credentials})
    : _credentials = credentials ?? AccountCredentialsStore();

  final AccountCredentialsStore _credentials;

  @override
  AccountKind get kind => AccountKind.s3;

  /// The account's S3 configuration, or null when unset or corrupt (same
  /// null-signalling contract as S3CredentialsStore.load).
  Future<S3Config?> loadConfig(domain.ConnectedAccount account) async {
    final raw = await _credentials.read(account.id);
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

  Future<void> saveConfig(domain.ConnectedAccount account, S3Config config) =>
      _credentials.write(account.id, jsonEncode(config.toJson()));

  @override
  Future<AccountStatus> status(domain.ConnectedAccount account) async =>
      await loadConfig(account) == null
      ? AccountStatus.needsSignIn
      : AccountStatus.signedIn;

  @override
  Future<void> disconnect(domain.ConnectedAccount account) =>
      _credentials.delete(account.id);

  @override
  CloudStorageProvider syncProvider(domain.ConnectedAccount account) =>
      S3StorageProvider(
        store: S3CredentialsStore(
          storageKey: AccountCredentialsStore.keyFor(account.id),
        ),
      );

  @override
  Future<MediaObjectStore?> mediaObjectStore(
    domain.ConnectedAccount account,
  ) async {
    final config = await loadConfig(account);
    if (config == null) return null;
    return S3MediaObjectStore(
      client: S3ApiClient(config),
      keyPrefix: config.prefix,
    );
  }
}
