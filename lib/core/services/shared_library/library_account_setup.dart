import 'dart:convert';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';

/// Creates the storage account a shared site library connects through,
/// from the connect page (issue #2567).
///
/// The account's folder is `submersion-sites`, which is also its identity:
/// on a bucket or server that already holds `submersion-sync` and
/// `submersion-media`, it is a third account, so a club's (perhaps
/// read-only) keys never replace the sync or media keys.
class LibraryAccountSetup {
  LibraryAccountSetup({
    ConnectedAccountsRepository? accounts,
    AccountCredentialsStore? credentials,
  }) : _accounts = accounts ?? ConnectedAccountsRepository(),
       _credentials = credentials ?? AccountCredentialsStore();

  final ConnectedAccountsRepository _accounts;
  final AccountCredentialsStore _credentials;

  Future<domain.ConnectedAccount> saveS3(S3Config server) async {
    final config = server.copyWith(
      prefix: '${SharedLibraryLayout.librariesDir}/',
    );
    final account = await _accounts.ensure(
      kind: AccountKind.s3,
      naturalKey: s3NaturalKey(config),
      label: '${config.bucket} @ ${config.displayHost}',
    );
    await _credentials.write(account.id, jsonEncode(config.toJson()));
    return account;
  }

  Future<domain.ConnectedAccount> saveWebDav(WebDavConfig server) async {
    final config = server.copyWith(folder: SharedLibraryLayout.librariesDir);
    final account = await _accounts.ensure(
      kind: AccountKind.webdav,
      naturalKey: webdavNaturalKey(config),
      label: config.displayLabel,
    );
    await _credentials.write(account.id, jsonEncode(config.toJson()));
    return account;
  }
}
