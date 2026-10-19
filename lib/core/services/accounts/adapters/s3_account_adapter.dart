import 'dart:convert';

import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
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
  S3AccountAdapter({
    AccountCredentialsStore? credentials,
    S3CredentialsStore? legacySync,
    S3StorageProvider? syncSettings,
  }) : _credentials = credentials ?? AccountCredentialsStore(),
       _legacySync = legacySync,
       _syncSettings = syncSettings;

  final AccountCredentialsStore _credentials;

  /// The sync settings blob (`sync_s3_config`), the source the sync
  /// account's per-account key is mirrored from; null where nothing syncs
  /// (tests of other uses).
  final S3CredentialsStore? _legacySync;

  /// The settings singleton that caches [_legacySync]'s config; it must
  /// forget the config when the blob is cleared here.
  final S3StorageProvider? _syncSettings;

  @override
  AccountKind get kind => AccountKind.s3;

  /// The account's S3 configuration, or null when unset or corrupt (same
  /// null-signalling contract as S3CredentialsStore.load).
  Future<S3Config?> loadConfig(domain.ConnectedAccount account) async =>
      decodeS3Config(await _credentials.read(account.id));

  Future<void> saveConfig(domain.ConnectedAccount account, S3Config config) =>
      _credentials.write(account.id, jsonEncode(config.toJson()));

  @override
  Future<AccountStatus> status(domain.ConnectedAccount account) async =>
      await loadConfig(account) == null
      ? AccountStatus.needsSignIn
      : AccountStatus.signedIn;

  /// Removes this device's credentials for [account]. When [account] is the
  /// sync endpoint, the sync settings go too, as WebDAV's adapter does:
  /// otherwise the next credential mirror would copy them straight back and
  /// sign the account in again. Another folder on the bucket leaves sync
  /// alone.
  @override
  Future<void> disconnect(domain.ConnectedAccount account) async {
    await _credentials.delete(account.id);
    final legacy = _legacySync;
    if (legacy == null) return;
    final sync = await legacy.load();
    if (sync == null) return;
    final syncAccountId = accountIdFor(
      kind: AccountKind.s3,
      naturalKey: s3NaturalKey(sync),
    );
    if (syncAccountId != account.id) return;
    await legacy.clear();
    _syncSettings?.forgetCachedConfig();
  }

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
