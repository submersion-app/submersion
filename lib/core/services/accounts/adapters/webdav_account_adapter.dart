import 'dart:convert';

import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/cloud_provider_instances.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_client.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/webdav_storage_provider.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/webdav_media_object_store.dart';

/// WebDAV servers as accounts. The whole WebDavConfig, password included,
/// is the per-account keychain payload; sync and media storage can point at
/// different servers or folders.
class WebDavAccountAdapter extends AccountProviderAdapter
    implements SyncCapable, MediaStoreCapable {
  WebDavAccountAdapter({
    AccountCredentialsStore? credentials,
    WebDavCredentialsStore? legacySync,
    WebDavStorageProvider? syncSettings,
  }) : _credentials = credentials ?? AccountCredentialsStore(),
       _legacySync = legacySync ?? WebDavCredentialsStore(),
       _syncSettings = syncSettings ?? webdavProviderInstance;

  final AccountCredentialsStore _credentials;

  /// The sync settings page's own blob, the source the sync account's
  /// per-account key is mirrored from.
  final WebDavCredentialsStore _legacySync;

  /// The settings singleton that caches [_legacySync]'s config; it must
  /// forget the config when the blob is cleared here.
  final WebDavStorageProvider _syncSettings;

  @override
  AccountKind get kind => AccountKind.webdav;

  Future<WebDavConfig?> loadConfig(domain.ConnectedAccount account) async =>
      decodeWebDavConfig(await _credentials.read(account.id));

  Future<void> saveConfig(
    domain.ConnectedAccount account,
    WebDavConfig config,
  ) => _credentials.write(account.id, jsonEncode(config.toJson()));

  @override
  Future<AccountStatus> status(domain.ConnectedAccount account) async =>
      await loadConfig(account) == null
      ? AccountStatus.needsSignIn
      : AccountStatus.signedIn;

  /// Removes this device's credentials for [account]. When [account] is the
  /// sync endpoint, the sync settings blob goes too: otherwise the next
  /// credential mirror would copy it straight back and sign the account in
  /// again. A media account on another folder leaves sync alone.
  @override
  Future<void> disconnect(domain.ConnectedAccount account) async {
    await _credentials.delete(account.id);
    final sync = await _legacySync.load();
    if (sync == null) return;
    final syncAccountId = accountIdFor(
      kind: AccountKind.webdav,
      naturalKey: webdavNaturalKey(sync),
    );
    if (syncAccountId != account.id) return;
    await _legacySync.clear();
    _syncSettings.forgetCachedConfig();
  }

  @override
  CloudStorageProvider syncProvider(domain.ConnectedAccount account) =>
      WebDavStorageProvider(
        store: WebDavCredentialsStore(
          storageKey: AccountCredentialsStore.keyFor(account.id),
        ),
      );

  @override
  Future<MediaObjectStore?> mediaObjectStore(
    domain.ConnectedAccount account,
  ) async {
    final config = await loadConfig(account);
    if (config == null) return null;
    return WebDavMediaObjectStore(client: WebDavClient(config));
  }
}
