import 'dart:convert';

import 'package:submersion/core/services/accounts/account_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/s3/s3_credentials_store.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_client.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_config.dart';
import 'package:submersion/core/services/cloud_storage/webdav/webdav_errors.dart';
import 'package:submersion/core/services/cloud_storage/webdav_storage_provider.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';

/// Helpers for the storage account a shared site library connects through
/// (issue #2567). A library's folder is its own, `submersion-sites/<folder>`,
/// which is also its row's identity: beside `submersion-sync`,
/// `submersion-media` and every other library on the same server it is a
/// row of its own, so one library's (perhaps read-only) keys never replace
/// another's. The rows are made by AccountGroupService.ensureRole (issue
/// #3482); this checks a library's server read only and reads what a row
/// stores.
class LibraryAccountSetup {
  LibraryAccountSetup({
    AccountCredentialsStore? credentials,
    WebDavClientFactory? webdavClient,
  }) : _credentials = credentials ?? AccountCredentialsStore(),
       _webdavClient = webdavClient ?? WebDavClient.new;

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
    final bucket = decodeS3Config(
      await _credentials.read(accountId),
    )?.bucket.trim();
    return bucket == null || bucket.isEmpty ? null : bucket;
  }

  /// The server address the stored settings of the WebDAV account
  /// [accountId] name, or null when they hold none (issue #3389).
  Future<String?> webdavServer(String accountId) async {
    try {
      final json = await _credentials.read(accountId);
      if (json == null) return null;
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return null;
      final url = WebDavConfig.fromJson(decoded).serverUrl.trim();
      return url.isEmpty ? null : url;
    } on Object {
      return null;
    }
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
}
