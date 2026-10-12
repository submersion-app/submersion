import 'dart:convert';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/cloud_storage/s3/s3_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_client.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav_storage_provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';

/// Creates the storage account a shared site library connects through,
/// from the connect page (issue #2567).
///
/// The account's folder is `submersion-sites`, which is also its identity:
/// on a bucket or server that already holds `submersion-sync` and
/// `submersion-media`, it is a third account, so a club's (perhaps
/// read-only) keys never replace the sync or media keys. Its label names
/// the folder too, as the sync account on the same server has the same
/// `bucket @ host` label.
class LibraryAccountSetup {
  LibraryAccountSetup({
    ConnectedAccountsRepository? accounts,
    AccountCredentialsStore? credentials,
    WebDavClientFactory? webdavClient,
  }) : _accounts = accounts ?? ConnectedAccountsRepository(),
       _credentials = credentials ?? AccountCredentialsStore(),
       _webdavClient = webdavClient ?? WebDavClient.new;

  final ConnectedAccountsRepository _accounts;
  final AccountCredentialsStore _credentials;
  final WebDavClientFactory _webdavClient;

  static const _folderNote = ' (${SharedLibraryLayout.librariesDir})';

  Future<domain.ConnectedAccount> saveS3(S3Config server) async {
    final config = server.copyWith(
      prefix: '${SharedLibraryLayout.librariesDir}/',
    );
    final account = await _accounts.ensure(
      kind: AccountKind.s3,
      naturalKey: s3NaturalKey(config),
      label: '${config.bucket} @ ${config.displayHost}$_folderNote',
    );
    await _credentials.write(account.id, jsonEncode(config.toJson()));
    return account;
  }

  /// Reaches the top folder of [server], read only, and returns it. A club
  /// may hand out logins that cannot write, which the sync settings' write
  /// probe would refuse. A self-signed certificate surfaces as
  /// [WebDavUntrustedCertificateException], for the caller to offer trust.
  Future<WebDavConfig> reachWebDav(WebDavConfig server) async {
    final problem = server.validate();
    if (problem != null) {
      throw WebDavException(problem, code: WebDavErrorCode.invalidConfig);
    }
    final client = _webdavClient(server);
    try {
      final top = await client.stat('');
      if (top == null || !top.isCollection) {
        throw WebDavException(
          'No WebDAV folder at this address. Check the address.',
          code: WebDavErrorCode.notFound,
        );
      }
    } finally {
      client.close();
    }
    return server;
  }

  Future<domain.ConnectedAccount> saveWebDav(WebDavConfig server) async {
    final config = server.copyWith(folder: SharedLibraryLayout.librariesDir);
    final account = await _accounts.ensure(
      kind: AccountKind.webdav,
      naturalKey: webdavNaturalKey(config),
      label: '${config.displayLabel}$_folderNote',
    );
    await _credentials.write(account.id, jsonEncode(config.toJson()));
    return account;
  }
}
