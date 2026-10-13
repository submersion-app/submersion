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
/// The account's folder is the library's own, `submersion-sites/<folder>`,
/// which is also its identity: beside `submersion-sync` and
/// `submersion-media`, and beside every other library on the same server,
/// it is an account of its own, so one library's (perhaps read-only) keys
/// never replace another's, nor the sync or media keys. Its label names the
/// folder too, as the sync account on the same server has the same
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

  /// `submersion-sites/<folder>`, or `submersion-sites` for an empty one.
  static String libraryFolder(String folder) {
    final f = folder.trim().replaceAll(RegExp(r'^/+|/+$'), '').trim();
    return f.isEmpty
        ? SharedLibraryLayout.librariesDir
        : '${SharedLibraryLayout.librariesDir}/$f';
  }

  /// The bucket the stored settings of the S3 account [accountId] name, or
  /// null when it holds none.
  Future<String?> s3Bucket(String accountId) async {
    try {
      final json = await _credentials.read(accountId);
      if (json == null) return null;
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return null;
      final bucket = S3Config.fromJson(decoded).bucket.trim();
      return bucket.isEmpty ? null : bucket;
    } on Object {
      return null;
    }
  }

  Future<domain.ConnectedAccount> saveS3(
    S3Config server, {
    required String folder,
  }) async {
    final where = libraryFolder(folder);
    final config = server.copyWith(prefix: '$where/');
    final account = await _accounts.ensure(
      kind: AccountKind.s3,
      naturalKey: s3NaturalKey(config),
      label: '${config.bucket} @ ${config.displayHost} ($where)',
    );
    await _credentials.write(account.id, jsonEncode(config.toJson()));
    return account;
  }

  /// Reaches the top folder of [server], read only, and returns it. A library
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

  Future<domain.ConnectedAccount> saveWebDav(
    WebDavConfig server, {
    required String folder,
  }) async {
    final where = libraryFolder(folder);
    final config = server.copyWith(folder: where);
    final account = await _accounts.ensure(
      kind: AccountKind.webdav,
      naturalKey: webdavNaturalKey(config),
      label: '${config.displayLabel} ($where)',
    );
    await _credentials.write(account.id, jsonEncode(config.toJson()));
    return account;
  }
}
