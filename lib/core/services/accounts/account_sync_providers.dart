import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart'
    show CloudProviderType;
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/adapters/dropbox_account_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/cloud_storage/cloud_provider_instances.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_store.dart';
import 'package:submersion/core/services/cloud_storage/git/git_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/git_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/s3_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/webdav_storage_provider.dart';

/// The S3 provider for the roster row [accountId], reading its per-account
/// keychain key. The S3 adapter builds through here too, so the foreground
/// and the scheduled backup cannot reach the row differently. [storage] is
/// the keychain, injectable for tests.
S3StorageProvider s3SyncProviderFor(
  String accountId, {
  FlutterSecureStorage? storage,
}) => S3StorageProvider(
  store: S3CredentialsStore(
    storage: storage,
    storageKey: AccountCredentialsStore.keyFor(accountId),
  ),
);

/// The WebDAV provider for the roster row [accountId]; see
/// [s3SyncProviderFor].
WebDavStorageProvider webdavSyncProviderFor(
  String accountId, {
  FlutterSecureStorage? storage,
}) => WebDavStorageProvider(
  store: WebDavCredentialsStore(
    storage: storage,
    storageKey: AccountCredentialsStore.keyFor(accountId),
  ),
);

/// The Git provider for the roster row [accountId]; see
/// [s3SyncProviderFor].
GitStorageProvider gitSyncProviderFor(
  String accountId, {
  FlutterSecureStorage? storage,
}) => GitStorageProvider(
  store: GitCredentialsStore(
    storage: storage,
    storageKey: AccountCredentialsStore.keyFor(accountId),
  ),
);

/// A roster row named by id and kind only. Every `SyncCapable.syncProvider`
/// reads nothing else from the row: credentials live in the keychain under
/// the id.
ConnectedAccount accountRowReference(String id, AccountKind kind) =>
    ConnectedAccount(
      id: id,
      kind: kind,
      label: '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );

/// A sync-capable provider for the roster row [accountId] of [kind], built
/// with no database or Riverpod container (the scheduled backup's isolate).
///
/// S3, WebDAV, Git and Dropbox build exactly as their adapters do (Dropbox
/// through its adapter); session-managed kinds (Google Drive, iCloud) are
/// the per-type instances, as everywhere else. Lightroom cannot hold files
/// and yields null.
CloudStorageProvider? accountSyncProvider(
  AccountKind kind,
  String accountId, {
  CloudStorageProvider Function(CloudProviderType type)? instanceFor,
  FlutterSecureStorage? storage,
}) => switch (kind) {
  AccountKind.s3 => s3SyncProviderFor(accountId, storage: storage),
  AccountKind.webdav => webdavSyncProviderFor(accountId, storage: storage),
  AccountKind.git => gitSyncProviderFor(accountId, storage: storage),
  AccountKind.dropbox => DropboxAccountAdapter(
    authStoreFactory: storage == null
        ? null
        : (key) => DropboxAuthStore(storage: storage, storageKey: key),
  ).syncProvider(accountRowReference(accountId, kind)),
  AccountKind.googledrive || AccountKind.icloud =>
    (instanceFor ?? cloudProviderInstanceFor)(kind.cloudProviderType!),
  AccountKind.adobeLightroom => null,
};
