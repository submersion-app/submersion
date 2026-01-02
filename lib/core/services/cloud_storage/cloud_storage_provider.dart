import 'dart:typed_data';

/// Information about a file stored in cloud storage
class CloudFileInfo {
  final String id;
  final String name;
  final DateTime modifiedTime;
  final int? sizeBytes;

  const CloudFileInfo({
    required this.id,
    required this.name,
    required this.modifiedTime,
    this.sizeBytes,
  });

  @override
  String toString() =>
      'CloudFileInfo(id: $id, name: $name, modified: $modifiedTime)';
}

/// Result of an upload operation
class UploadResult {
  final String fileId;
  final DateTime uploadTime;

  const UploadResult({
    required this.fileId,
    required this.uploadTime,
  });
}

/// Exception thrown by cloud storage operations
class CloudStorageException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const CloudStorageException(this.message, [this.cause, this.stackTrace]);

  @override
  String toString() =>
      'CloudStorageException: $message${cause != null ? ' ($cause)' : ''}';
}

/// Abstract interface for cloud storage providers (iCloud, Google Drive, etc.)
///
/// This interface defines the contract that all cloud storage implementations
/// must follow, enabling the sync system to work with any supported provider.
abstract class CloudStorageProvider {
  /// The display name of this provider (e.g., "iCloud", "Google Drive")
  String get providerName;

  /// Unique identifier for this provider type
  String get providerId;

  /// Check if this provider is available on the current platform
  ///
  /// Returns false if the platform doesn't support this provider
  /// (e.g., iCloud on Android)
  Future<bool> isAvailable();

  /// Check if the user is currently authenticated with this provider
  Future<bool> isAuthenticated();

  /// Authenticate the user with this provider
  ///
  /// This may show a sign-in UI or use stored credentials.
  /// Throws [CloudStorageException] if authentication fails.
  Future<void> authenticate();

  /// Sign out from this provider
  ///
  /// Clears stored credentials and authentication state.
  Future<void> signOut();

  /// Get the current user's email or identifier (if available)
  Future<String?> getUserEmail();

  /// Upload data to cloud storage
  ///
  /// [data] The bytes to upload
  /// [filename] The name to give the file in cloud storage
  /// [folderId] Optional folder to upload to (provider-specific)
  ///
  /// Returns the file ID of the uploaded file.
  /// Throws [CloudStorageException] on failure.
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  });

  /// Download a file from cloud storage
  ///
  /// [fileId] The ID of the file to download
  ///
  /// Returns the file contents as bytes.
  /// Throws [CloudStorageException] if the file doesn't exist or download fails.
  Future<Uint8List> downloadFile(String fileId);

  /// Get information about a file
  ///
  /// [fileId] The ID of the file
  ///
  /// Returns file info or null if the file doesn't exist.
  Future<CloudFileInfo?> getFileInfo(String fileId);

  /// List files in a folder or root
  ///
  /// [folderId] Optional folder ID (null for app's root folder)
  /// [namePattern] Optional pattern to filter files by name
  ///
  /// Returns a list of files matching the criteria.
  Future<List<CloudFileInfo>> listFiles({
    String? folderId,
    String? namePattern,
  });

  /// Delete a file from cloud storage
  ///
  /// [fileId] The ID of the file to delete
  ///
  /// Throws [CloudStorageException] on failure.
  Future<void> deleteFile(String fileId);

  /// Check if a file exists
  ///
  /// [fileId] The ID of the file to check
  Future<bool> fileExists(String fileId);

  /// Create a folder in cloud storage (if supported)
  ///
  /// [folderName] The name of the folder to create
  /// [parentFolderId] Optional parent folder (null for root)
  ///
  /// Returns the folder ID.
  /// May throw [UnsupportedError] if the provider doesn't support folders.
  Future<String> createFolder(String folderName, {String? parentFolderId});

  /// Get or create the app's sync folder
  ///
  /// Returns the folder ID where sync files should be stored.
  Future<String> getOrCreateSyncFolder();
}

/// Mixin providing common functionality for cloud storage providers
mixin CloudStorageProviderMixin {
  static const String syncFolderName = 'Submersion Sync';
  static const String syncFilePrefix = 'submersion_sync_';
  static const String syncFileExtension = '.json';

  /// Generate a sync filename with timestamp
  String generateSyncFilename() {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    return '$syncFilePrefix$timestamp$syncFileExtension';
  }

  /// Check if a filename matches the sync file pattern
  bool isSyncFile(String filename) {
    return filename.startsWith(syncFilePrefix) &&
        filename.endsWith(syncFileExtension);
  }
}
