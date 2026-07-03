import 'dart:typed_data';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_api_client.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_manager.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_store.dart';
import 'package:submersion/core/services/logger_service.dart';

/// Dropbox implementation of [CloudStorageProvider] over the HTTP API v2.
///
/// The Dropbox app uses "App folder" access: everything lives under the
/// app folder (shown to the user as Apps/Submersion/), whose root is the
/// empty path ''. File IDs are Dropbox lower-cased paths, the way the
/// iCloud provider uses relative paths.
///
/// Semantic mappings onto the interface:
/// - authenticate() requires an existing connection (made via
///   [beginAuthorization]/[completeAuthorization] from the settings UI)
///   and live-probes it with a get_current_account call.
/// - createFolder is pure path construction: Dropbox creates missing
///   parent folders implicitly on upload.
/// - isAuthenticated is presence-only (no network) like the S3 provider,
///   and keychain failures PROPAGATE for the same reason: a locked
///   keychain must not read as "not connected".
class DropboxStorageProvider
    with CloudStorageProviderMixin
    implements CloudStorageProvider {
  DropboxStorageProvider({
    DropboxAuthManager? authManager,
    DropboxApiClient? apiClient,
  }) : _auth = authManager ?? DropboxAuthManager() {
    _client =
        apiClient ??
        DropboxApiClient(
          getAccessToken: _auth.getAccessToken,
          onAccessTokenRejected: _auth.invalidateAccessToken,
        );
  }

  static final _log = LoggerService.forClass(DropboxStorageProvider);

  final DropboxAuthManager _auth;
  late final DropboxApiClient _client;

  @override
  String get providerName => 'Dropbox';

  @override
  String get providerId => 'dropbox';

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> isAuthenticated() async => (await _auth.loadAuth()) != null;

  /// The authorize URL for the settings UI to open in the browser.
  Uri beginAuthorization() => _auth.beginAuthorization();

  /// Completes the copy-paste OAuth flow with the pasted [code].
  Future<DropboxAuthData> completeAuthorization(String code) =>
      _auth.completeAuthorization(code);

  /// The stored connection (account labels for the UI), or null.
  Future<DropboxAuthData?> loadAuth() => _auth.loadAuth();

  @override
  Future<void> authenticate() async {
    if (await _auth.loadAuth() == null) {
      throw const CloudStorageException(
        'Dropbox is not connected. Connect Dropbox in the Cloud Sync '
        'settings.',
      );
    }
    await _client.getCurrentAccount();
    _log.info('Dropbox probe succeeded');
  }

  @override
  Future<void> signOut() => _auth.disconnect();

  @override
  Future<String?> getUserEmail() async {
    final auth = await _auth.loadAuth();
    return auth?.email ?? auth?.displayName;
  }

  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) async {
    final meta = await _client.upload(_join(folderId, filename), data);
    return UploadResult(
      fileId: meta.pathLower,
      uploadTime: meta.serverModified,
    );
  }

  @override
  Future<Uint8List> downloadFile(String fileId) => _client.download(fileId);

  @override
  Future<CloudFileInfo?> getFileInfo(String fileId) async {
    final meta = await _client.getMetadata(fileId);
    return meta == null ? null : _toCloudFileInfo(meta);
  }

  @override
  Future<List<CloudFileInfo>> listFiles({
    String? folderId,
    String? namePattern,
  }) async {
    final entries = await _client.listFolder(path: folderId ?? '');
    return entries
        .map(_toCloudFileInfo)
        .where((f) => namePattern == null || f.name.contains(namePattern))
        .toList();
  }

  @override
  Future<void> deleteFile(String fileId) => _client.delete(fileId);

  @override
  Future<bool> fileExists(String fileId) async =>
      (await _client.getMetadata(fileId)) != null;

  @override
  Future<String> createFolder(
    String folderName, {
    String? parentFolderId,
  }) async => _join(parentFolderId, folderName);

  /// '' is the app-folder root: with App folder access the whole folder is
  /// ours, so no named subfolder is needed (or created).
  @override
  Future<String> getOrCreateSyncFolder() async => '';

  CloudFileInfo _toCloudFileInfo(DropboxFileMetadata meta) => CloudFileInfo(
    id: meta.pathLower,
    name: meta.name,
    modifiedTime: meta.serverModified,
    sizeBytes: meta.size,
  );

  /// Dropbox paths are absolute and '/'-separated; the app-folder root is
  /// '' but children of it still start with '/'.
  String _join(String? folder, String name) =>
      (folder == null || folder.isEmpty) ? '/$name' : '$folder/$name';
}
