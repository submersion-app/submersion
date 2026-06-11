import 'dart:async';
import 'dart:typed_data';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';

/// In-memory [CloudStorageProvider] for tests. Files are keyed by name, so the
/// canonical sync file maps to a single stable id across uploads.
class FakeCloudStorageProvider extends CloudStorageProvider
    with CloudStorageProviderMixin {
  final Map<String, _FakeFile> _files = {};
  bool authenticated = true;
  bool available = true;

  int get fileCount => _files.length;
  Uint8List? bytesOf(String name) => _files[name]?.data;

  /// Counts every call to [uploadFile], including those that throw.
  int uploadAttempts = 0;

  /// When true, [uploadFile] throws, modelling an offline/denied provider.
  bool failUploads = false;

  /// When true, [uploadFile] WRITES the file and then throws
  /// [TimeoutException], modelling a PUT that landed server-side while the
  /// response was lost.
  bool timeoutUploadsAfterWrite = false;

  /// When true, [deleteFile] throws, modelling an offline/denied provider.
  bool failDeletes = false;

  /// Seed a file as though another device had uploaded it.
  void seedFile(String name, Uint8List data) {
    _files[name] = _FakeFile(data, DateTime.now());
  }

  /// Bytes of the single sync payload file present, regardless of its
  /// per-device filename (`submersion_sync_<deviceId>.json`) or the legacy
  /// canonical name. Convenience for export-shape assertions in tests.
  Uint8List? syncFileBytes() {
    for (final e in _files.entries) {
      if (e.key.startsWith(CloudStorageProviderMixin.syncFilePrefix) ||
          e.key == CloudStorageProviderMixin.canonicalSyncFileName) {
        return e.value.data;
      }
    }
    return null;
  }

  @override
  String get providerName => 'Fake';

  @override
  String get providerId => 'fake';

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> isAuthenticated() async => authenticated;

  @override
  Future<void> authenticate() async {
    authenticated = true;
  }

  @override
  Future<void> signOut() async {
    authenticated = false;
  }

  @override
  Future<String?> getUserEmail() async => 'tester@example.com';

  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) async {
    uploadAttempts++;
    if (failUploads) {
      throw const CloudStorageException('upload failed (test)');
    }
    _files[filename] = _FakeFile(data, DateTime.now());
    if (timeoutUploadsAfterWrite) {
      throw TimeoutException('upload timed out (test)');
    }
    return UploadResult(
      fileId: filename,
      uploadTime: _files[filename]!.modified,
    );
  }

  @override
  Future<Uint8List> downloadFile(String fileId) async {
    final f = _files[fileId];
    if (f == null) {
      throw CloudStorageException('File not found: $fileId');
    }
    return f.data;
  }

  @override
  Future<CloudFileInfo?> getFileInfo(String fileId) async {
    final f = _files[fileId];
    if (f == null) return null;
    return CloudFileInfo(
      id: fileId,
      name: fileId,
      modifiedTime: f.modified,
      sizeBytes: f.data.length,
    );
  }

  @override
  Future<List<CloudFileInfo>> listFiles({
    String? folderId,
    String? namePattern,
  }) async {
    return _files.entries
        .where((e) => namePattern == null || e.key.contains(namePattern))
        .map(
          (e) => CloudFileInfo(
            id: e.key,
            name: e.key,
            modifiedTime: e.value.modified,
            sizeBytes: e.value.data.length,
          ),
        )
        .toList();
  }

  @override
  Future<void> deleteFile(String fileId) async {
    if (failDeletes) {
      throw const CloudStorageException('delete failed (test)');
    }
    _files.remove(fileId);
  }

  @override
  Future<bool> fileExists(String fileId) async => _files.containsKey(fileId);

  @override
  Future<String> createFolder(
    String folderName, {
    String? parentFolderId,
  }) async => 'fake-folder';

  @override
  Future<String> getOrCreateSyncFolder() async => 'fake-sync-folder';
}

class _FakeFile {
  final Uint8List data;
  final DateTime modified;
  _FakeFile(this.data, this.modified);
}
