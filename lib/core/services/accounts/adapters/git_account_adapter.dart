import 'dart:convert';

import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_sync_providers.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/cloud_provider_instances.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/git/git_config.dart';
import 'package:submersion/core/services/cloud_storage/git/git_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/git_storage_provider.dart';

/// Git repositories as accounts. The whole GitConfig, token included, is the
/// per-account keychain payload. Sync only: Git is never a media store,
/// since photos in Git history would grow the repository without bound.
class GitAccountAdapter extends AccountProviderAdapter implements SyncCapable {
  GitAccountAdapter({
    AccountCredentialsStore? credentials,
    GitCredentialsStore? legacySync,
    GitStorageProvider? syncSettings,
  }) : _credentials = credentials ?? AccountCredentialsStore(),
       _legacySync = legacySync ?? GitCredentialsStore(),
       _syncSettings = syncSettings ?? gitProviderInstance;

  final AccountCredentialsStore _credentials;

  /// The Git settings page's own blob, the source the sync account's
  /// per-account key is mirrored from.
  final GitCredentialsStore _legacySync;

  /// The settings singleton that caches [_legacySync]'s config; it must
  /// forget the config when the blob is cleared here.
  final GitStorageProvider _syncSettings;

  @override
  AccountKind get kind => AccountKind.git;

  Future<GitConfig?> loadConfig(domain.ConnectedAccount account) async =>
      decodeGitConfig(await _credentials.read(account.id));

  Future<void> saveConfig(domain.ConnectedAccount account, GitConfig config) =>
      _credentials.write(account.id, jsonEncode(config.toJson()));

  @override
  Future<AccountStatus> status(domain.ConnectedAccount account) async =>
      await loadConfig(account) == null
      ? AccountStatus.needsSignIn
      : AccountStatus.signedIn;

  /// Removes this device's credentials for [account]. When [account] is the
  /// sync endpoint, the sync settings blob goes too: otherwise the next
  /// credential mirror would copy it straight back and sign it in again.
  @override
  Future<void> disconnect(domain.ConnectedAccount account) async {
    await _credentials.delete(account.id);
    final sync = await _legacySync.load();
    if (sync == null) return;
    final syncAccountId = accountIdFor(
      kind: AccountKind.git,
      naturalKey: gitNaturalKey(sync),
    );
    if (syncAccountId != account.id) return;
    await _legacySync.clear();
    _syncSettings.forgetCachedConfig();
  }

  @override
  CloudStorageProvider syncProvider(domain.ConnectedAccount account) =>
      gitSyncProviderFor(account.id);
}
