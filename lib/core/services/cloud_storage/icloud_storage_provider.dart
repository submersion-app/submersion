import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';

/// iCloud implementation of CloudStorageProvider
///
/// Uses the app's iCloud container directory for storage.
/// Files written to this directory are automatically synced by iOS/macOS.
///
/// Note: This requires proper iCloud entitlements in the Xcode project:
/// 1. Enable iCloud capability
/// 2. Enable iCloud Documents
/// 3. Configure container identifier (iCloud.com.yourcompany.submersion)
class ICloudStorageProvider
    with CloudStorageProviderMixin
    implements CloudStorageProvider {
  static final _log = LoggerService.forClass(ICloudStorageProvider);

  Directory? _icloudContainer;
  Directory? _syncFolder;

  @override
  String get providerName => 'iCloud';

  @override
  String get providerId => 'icloud';

  @override
  Future<bool> isAvailable() async {
    // iCloud is only available on iOS and macOS
    if (!Platform.isIOS && !Platform.isMacOS) {
      return false;
    }

    try {
      final container = await _getICloudContainer();
      return container != null;
    } catch (e) {
      _log.warning('iCloud availability check failed: $e');
      return false;
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    // iCloud authentication is handled by the OS
    // If the container exists and is accessible, user is signed in
    return await isAvailable();
  }

  @override
  Future<void> authenticate() async {
    // iCloud authentication is handled by the OS
    // We just need to verify access to the container
    final container = await _getICloudContainer();
    if (container == null) {
      throw const CloudStorageException(
        'iCloud is not available. Please sign in to iCloud in System Settings.',
      );
    }
    _log.info('iCloud container available at: ${container.path}');
  }

  @override
  Future<void> signOut() async {
    // Cannot programmatically sign out of iCloud
    // Clear cached references
    _icloudContainer = null;
    _syncFolder = null;
    _log.info('Cleared iCloud references');
  }

  @override
  Future<String?> getUserEmail() async {
    // Cannot access iCloud user email from Flutter
    // Would need platform channel to native code
    return null;
  }

  /// Get the iCloud container directory
  Future<Directory?> _getICloudContainer() async {
    _log.info(
      '_getICloudContainer called, cached: ${_icloudContainer != null}',
    );
    if (_icloudContainer != null) {
      return _icloudContainer;
    }

    try {
      _log.info('Platform: macOS=${Platform.isMacOS}, iOS=${Platform.isIOS}');
      if (Platform.isMacOS) {
        // On macOS, use the app's container in ~/Library/Mobile Documents/
        final home = Platform.environment['HOME'];
        _log.info('HOME = $home');
        if (home != null) {
          // The container ID should match your iCloud container identifier
          // Format: iCloud~bundleid (with dots replaced by tildes)
          final containerPath = path.join(
            home,
            'Library',
            'Mobile Documents',
            'iCloud~app~submersion',
            'Documents',
          );
          _log.info('iCloud container path: $containerPath');
          final container = Directory(containerPath);

          // Create if doesn't exist
          final exists = await container.exists();
          _log.info('Container exists: $exists');
          if (!exists) {
            await container.create(recursive: true);
            _log.info('Created container directory');
          }

          _icloudContainer = container;
          return container;
        }
      } else if (Platform.isIOS) {
        _log.warning(
          'iOS: Using local Documents directory (not real iCloud Drive)',
        );
        // On iOS, use getApplicationDocumentsDirectory
        // Files here are backed up to iCloud if iCloud backup is enabled
        // For explicit iCloud Drive storage, we need a different approach
        final docsDir = await getApplicationDocumentsDirectory();

        // Create an iCloud subdirectory
        final icloudDir = Directory(path.join(docsDir.path, 'iCloud'));
        if (!await icloudDir.exists()) {
          await icloudDir.create(recursive: true);
        }

        _icloudContainer = icloudDir;
        return icloudDir;
      }

      return null;
    } catch (e) {
      _log.error('Failed to get iCloud container', e, null);
      return null;
    }
  }

  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) async {
    try {
      final syncFolder = await getOrCreateSyncFolder();
      final file = File(path.join(syncFolder, filename));

      await file.writeAsBytes(data);

      _log.info('Uploaded file to iCloud: ${file.path}');

      return UploadResult(fileId: file.path, uploadTime: DateTime.now());
    } catch (e, stackTrace) {
      _log.error('Failed to upload file to iCloud: $filename', e, stackTrace);
      throw CloudStorageException('Upload failed: $e', e, stackTrace);
    }
  }

  @override
  Future<Uint8List> downloadFile(String fileId) async {
    try {
      final file = File(fileId);

      if (!await file.exists()) {
        throw CloudStorageException('File not found: $fileId');
      }

      final data = await file.readAsBytes();
      _log.info('Downloaded file from iCloud: $fileId (${data.length} bytes)');

      return data;
    } catch (e, stackTrace) {
      _log.error('Failed to download file from iCloud: $fileId', e, stackTrace);
      throw CloudStorageException('Download failed: $e', e, stackTrace);
    }
  }

  @override
  Future<CloudFileInfo?> getFileInfo(String fileId) async {
    try {
      final file = File(fileId);

      if (!await file.exists()) {
        return null;
      }

      final stat = await file.stat();

      return CloudFileInfo(
        id: fileId,
        name: path.basename(fileId),
        modifiedTime: stat.modified,
        sizeBytes: stat.size,
      );
    } catch (e) {
      _log.warning('Failed to get file info: $fileId - $e');
      return null;
    }
  }

  @override
  Future<List<CloudFileInfo>> listFiles({
    String? folderId,
    String? namePattern,
  }) async {
    try {
      final folderPath = folderId ?? await getOrCreateSyncFolder();
      final folder = Directory(folderPath);

      if (!await folder.exists()) {
        return [];
      }

      final files = <CloudFileInfo>[];

      await for (final entity in folder.list()) {
        if (entity is File) {
          final filename = path.basename(entity.path);

          // Apply name pattern filter if specified
          if (namePattern != null && !filename.contains(namePattern)) {
            continue;
          }

          final stat = await entity.stat();
          files.add(
            CloudFileInfo(
              id: entity.path,
              name: filename,
              modifiedTime: stat.modified,
              sizeBytes: stat.size,
            ),
          );
        }
      }

      return files;
    } catch (e, stackTrace) {
      _log.error('Failed to list files in iCloud', e, stackTrace);
      throw CloudStorageException('List files failed: $e', e, stackTrace);
    }
  }

  @override
  Future<void> deleteFile(String fileId) async {
    try {
      final file = File(fileId);

      if (await file.exists()) {
        await file.delete();
        _log.info('Deleted file from iCloud: $fileId');
      }
    } catch (e, stackTrace) {
      _log.error('Failed to delete file from iCloud: $fileId', e, stackTrace);
      throw CloudStorageException('Delete failed: $e', e, stackTrace);
    }
  }

  @override
  Future<bool> fileExists(String fileId) async {
    try {
      return await File(fileId).exists();
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String> createFolder(
    String folderName, {
    String? parentFolderId,
  }) async {
    try {
      final container = await _getICloudContainer();
      if (container == null) {
        throw const CloudStorageException('iCloud container not available');
      }

      final parentPath = parentFolderId ?? container.path;
      final folderPath = path.join(parentPath, folderName);
      final folder = Directory(folderPath);

      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      _log.info('Created folder in iCloud: $folderPath');
      return folderPath;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to create folder in iCloud: $folderName',
        e,
        stackTrace,
      );
      throw CloudStorageException('Create folder failed: $e', e, stackTrace);
    }
  }

  @override
  Future<String> getOrCreateSyncFolder() async {
    if (_syncFolder != null) {
      return _syncFolder!.path;
    }

    final container = await _getICloudContainer();
    if (container == null) {
      throw const CloudStorageException('iCloud container not available');
    }

    final syncFolderPath = path.join(
      container.path,
      CloudStorageProviderMixin.syncFolderName,
    );
    _syncFolder = Directory(syncFolderPath);

    if (!await _syncFolder!.exists()) {
      await _syncFolder!.create(recursive: true);
      _log.info('Created sync folder: $syncFolderPath');
    }

    return syncFolderPath;
  }
}
