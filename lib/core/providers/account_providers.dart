import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_provider_registry.dart';
import 'package:submersion/core/services/accounts/adapters/dropbox_account_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/google_drive_account_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/icloud_account_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/lightroom_account_adapter.dart';
import 'package:submersion/core/services/accounts/adapters/s3_account_adapter.dart';

final connectedAccountsRepositoryProvider =
    Provider<ConnectedAccountsRepository>(
      (ref) => ConnectedAccountsRepository(),
    );

/// Per-account keychain access. Overridable so widget tests can supply an
/// in-memory keychain (the real one has no platform channel under test).
final accountCredentialsStoreProvider = Provider<AccountCredentialsStore>(
  (ref) => AccountCredentialsStore(),
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
    DropboxAccountAdapter(),
    GoogleDriveAccountAdapter(),
    ICloudAccountAdapter(),
    LightroomAccountAdapter(),
  ]),
);
