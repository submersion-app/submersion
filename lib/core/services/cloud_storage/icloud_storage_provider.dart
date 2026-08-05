import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/icloud_native_service.dart';

/// The host platform, as far as iCloud availability is concerned.
///
/// [ICloudStorageProvider] takes one of these rather than separate `isApple` /
/// `isIOS` booleans, so that an impossible combination (iOS but not Apple)
/// cannot be constructed at all. A provider built from mismatched booleans
/// would fail the platform guard before ever consulting the container, making
/// a test pass for the wrong reason.
enum ICloudHostPlatform {
  ios,
  macos,
  other;

  /// The real host platform this process is running on.
  static ICloudHostPlatform current() {
    if (Platform.isIOS) return ICloudHostPlatform.ios;
    if (Platform.isMacOS) return ICloudHostPlatform.macos;
    return ICloudHostPlatform.other;
  }

  /// Whether iCloud can exist here at all.
  bool get isApple => this != ICloudHostPlatform.other;
}

/// Resolves the iCloud container's Documents path, or null when iCloud cannot
/// serve this app.
typedef ICloudContainerPathLookup = Future<String?> Function();

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
  /// [platform] defaults to the real host platform. It is injectable because
  /// unit tests never run on a real iOS device, so the iOS-specific behaviour
  /// of this provider is otherwise unreachable from a test host.
  ///
  /// [containerPathLookup] defaults to the native channel call. It is
  /// injectable because [ICloudNativeService.getContainerPath] carries its own
  /// `Platform.isIOS || Platform.isMacOS` guard and returns null without
  /// reaching the channel on other hosts — so on a Linux CI runner a mocked
  /// channel is never consulted, and a test would reach its assertion via a
  /// short circuit rather than via the branch it means to exercise.
  ICloudStorageProvider({
    ICloudHostPlatform? platform,
    ICloudContainerPathLookup? containerPathLookup,
  }) : _platform = platform ?? ICloudHostPlatform.current(),
       _lookupContainerPath =
           containerPathLookup ?? ICloudNativeService.getContainerPath;

  static final _log = LoggerService.forClass(ICloudStorageProvider);

  final ICloudHostPlatform _platform;
  final ICloudContainerPathLookup _lookupContainerPath;

  Directory? _icloudContainer;
  Directory? _syncFolder;

  @override
  String get providerName => 'iCloud';

  @override
  String get providerId => 'icloud';

  @override
  Future<bool> isAvailable() async {
    // iCloud is only available on iOS and macOS
    if (!_platform.isApple) {
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
      _log.info('Platform: ${_platform.name}');

      final containerPath = await _lookupContainerPath();
      if (containerPath != null) {
        _log.info('iCloud container path: $containerPath');
        final container = Directory(containerPath);

        final exists = await container.exists();
        _log.info('Container exists: $exists');
        if (!exists) {
          await container.create(recursive: true);
          _log.info('Created container directory');
        }

        _icloudContainer = container;
        return container;
      }

      // No fallback: a null container means iCloud cannot serve this app (no
      // account signed in, no ubiquity entitlement, or the iOS Simulator,
      // which never propagates ubiquity documents). Substituting a local
      // directory would make the provider report itself available and strand
      // every synced byte in the app sandbox, where no other device can reach
      // it -- silently, because nothing in the stack would raise an error.
      _log.warning('iCloud container unavailable; reporting iCloud as offline');
      return null;
    } catch (e) {
      _log.error('Failed to get iCloud container', error: e);
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
      _log.info('uploadFile: START for $filename (${data.length} bytes)');

      // Step 1: Get sync folder with timeout
      _log.info('uploadFile: Step 1 - getting sync folder...');
      final syncFolder = await getOrCreateSyncFolder().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw const CloudStorageException(
            'Timeout getting sync folder (15s)',
          );
        },
      );
      _log.info('uploadFile: Step 1 DONE - sync folder: $syncFolder');

      final filePath = path.join(syncFolder, filename);

      // Step 2: Write directly to iCloud using native file coordination
      // Native code handles direct file write with timeout
      _log.info('uploadFile: Step 2 - writing to iCloud via native: $filePath');
      await ICloudNativeService.writeFile(filePath, data).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw const CloudStorageException('Timeout writing to iCloud (30s)');
        },
      );
      _log.info('uploadFile: Step 2 DONE - write complete');

      _log.info('uploadFile: SUCCESS - $filePath');
      return UploadResult(fileId: filePath, uploadTime: DateTime.now());
    } catch (e, stackTrace) {
      _log.error('uploadFile: FAILED - $e', error: e, stackTrace: stackTrace);
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

      final downloaded = await ICloudNativeService.downloadIfNeeded(fileId);
      if (!downloaded) {
        throw CloudStorageException('iCloud file not downloaded: $fileId');
      }

      final data = await file.readAsBytes();
      _log.info('Downloaded file from iCloud: $fileId (${data.length} bytes)');

      return data;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to download file from iCloud: $fileId',
        error: e,
        stackTrace: stackTrace,
      );
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

      await ICloudNativeService.downloadIfNeeded(fileId);

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

      // Refresh the folder to ensure we see files synced from other devices.
      // On iOS especially, iCloud files may not be visible until explicitly downloaded.
      await ICloudNativeService.refreshFolder(folderPath);

      final files = <CloudFileInfo>[];

      await for (final entity in folder.list()) {
        if (entity is File) {
          final filename = path.basename(entity.path);

          // Apply name pattern filter if specified
          if (namePattern != null && !filename.contains(namePattern)) {
            continue;
          }

          // Ensure the file is downloaded before reading its stats
          await ICloudNativeService.downloadIfNeeded(entity.path);

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
      _log.error(
        'Failed to list files in iCloud',
        error: e,
        stackTrace: stackTrace,
      );
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
      _log.error(
        'Failed to delete file from iCloud: $fileId',
        error: e,
        stackTrace: stackTrace,
      );
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
        error: e,
        stackTrace: stackTrace,
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

  /// Get or create the media folder in the iCloud container.
  Future<String> getOrCreateMediaFolder() async {
    final container = await _getICloudContainer();
    if (container == null) {
      throw const CloudStorageException('iCloud container not available');
    }

    final mediaFolderPath = path.join(container.path, 'Media');
    final mediaFolder = Directory(mediaFolderPath);
    if (!await mediaFolder.exists()) {
      await mediaFolder.create(recursive: true);
      _log.info('Created media folder: $mediaFolderPath');
    }
    return mediaFolderPath;
  }
}
