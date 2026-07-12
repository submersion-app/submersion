import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
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

/// One adapter instance per kind for the process lifetime (token caches and
/// single-flight refresh live inside adapters).
final accountProviderRegistryProvider = Provider<AccountProviderRegistry>(
  (ref) => AccountProviderRegistry([
    S3AccountAdapter(),
    DropboxAccountAdapter(),
    GoogleDriveAccountAdapter(),
    ICloudAccountAdapter(),
    LightroomAccountAdapter(),
  ]),
);
