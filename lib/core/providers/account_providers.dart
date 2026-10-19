import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/providers/ref_invalidate_on_change.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_provider_registry.dart';
import 'package:submersion/core/services/accounts/adapters/dropbox_account_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/google_drive_account_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/icloud_account_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/lightroom_account_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/s3_account_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/webdav_account_adapter.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_credentials_store.dart';

final connectedAccountsRepositoryProvider =
    Provider<ConnectedAccountsRepository>(
      (ref) => ConnectedAccountsRepository(),
    );

/// The name the account [id] is shown under (issue #3522): the diver's
/// nickname, else its label with a well-known service's host named. Null
/// when the roster has no such row. Follows renames and syncs.
final accountDisplayNameProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, id) async {
      final repository = ref.watch(connectedAccountsRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchAccountsChanges());
      return (await repository.getById(id))?.displayName;
    });

/// Per-account keychain access. Overridable so widget tests can supply an
/// in-memory keychain (the real one has no platform channel under test).
final accountCredentialsStoreProvider = Provider<AccountCredentialsStore>(
  (ref) => AccountCredentialsStore(),
);

/// The LEGACY single-key sync S3 config store, still the source of truth for
/// the S3 connect UI. Sync account derivation reads it to identify the
/// endpoint. Overridable for the same reason as
/// [accountCredentialsStoreProvider]: the real keychain has no platform
/// channel under test.
final s3CredentialsStoreProvider = Provider<S3CredentialsStore>(
  (ref) => S3CredentialsStore(),
);

/// The legacy WebDAV sync blob (`sync_webdav_config`) the WebDAV settings
/// page writes; overridable for tests like [s3CredentialsStoreProvider].
final webdavCredentialsStoreProvider = Provider<WebDavCredentialsStore>(
  (ref) => WebDavCredentialsStore(),
);

/// One adapter instance per kind for the process lifetime (token caches and
/// single-flight refresh live inside adapters).
///
/// S3AccountAdapter is wired to [accountCredentialsStoreProvider] so a test
/// override of that provider (in-memory keychain) reaches the adapter's
/// credential reads/writes. Dropbox and Lightroom adapters use their own
/// auth stores (DropboxAuthStore / LightroomAuthStore), overridden
/// separately via their store factories when a test needs to.
final accountProviderRegistryProvider = Provider<AccountProviderRegistry>(
  (ref) => AccountProviderRegistry([
    S3AccountAdapter(credentials: ref.watch(accountCredentialsStoreProvider)),
    WebDavAccountAdapter(
      credentials: ref.watch(accountCredentialsStoreProvider),
      legacySync: ref.watch(webdavCredentialsStoreProvider),
    ),
    DropboxAccountAdapter(),
    GoogleDriveAccountAdapter(),
    ICloudAccountAdapter(),
    LightroomAccountAdapter(),
  ]),
);
