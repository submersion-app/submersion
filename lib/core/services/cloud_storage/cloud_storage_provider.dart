import 'dart:io';
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

  const UploadResult({required this.fileId, required this.uploadTime});
}

/// Exception thrown by cloud storage operations
class CloudStorageException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const CloudStorageException(this.message, [this.cause, this.stackTrace]);

  /// User-facing message that appends the underlying [cause] when present.
  ///
  /// The top-level [message] is intentionally generic (e.g. "Could not reach
  /// S3 endpoint ..."); the [cause] carries the actionable transport detail
  /// (TLS handshake / certificate / socket errors). Unlike [toString] this
  /// omits the class-name prefix, so it is safe to show directly in a
  /// snackbar.
  String get displayMessage => '$message${_causeSuffix(cause)}';

  @override
  String toString() => 'CloudStorageException: $message${_causeSuffix(cause)}';

  /// `' (<cause>)'` for a non-null [cause], else `''`.
  ///
  /// Prefers the cause's own (informative) `toString` -- which carries the
  /// actionable detail like `CERTIFICATE_VERIFY_FAILED` -- but falls back to
  /// [Error.safeToString] if that throws, so an error-display path can never
  /// itself throw. (A bare [Error.safeToString] is not used because it
  /// renders exceptions as "Instance of '...'", discarding the detail.)
  static String _causeSuffix(Object? cause) {
    if (cause == null) return '';
    try {
      return ' ($cause)';
    } catch (_) {
      return ' (${Error.safeToString(cause)})';
    }
  }
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

  /// Upload a local file to cloud storage.
  ///
  /// The path-based twin of [uploadFile] for large artifacts (database
  /// backups): providers override it to stream from disk so the whole file is
  /// never resident in memory. [CloudStorageProviderMixin] supplies a
  /// buffering fallback that delegates to [uploadFile].
  Future<UploadResult> uploadFileFromPath(
    String sourcePath,
    String filename, {
    String? folderId,
  });

  /// Download a file from cloud storage straight to [destinationPath].
  ///
  /// The path-based twin of [downloadFile]; same memory rationale as
  /// [uploadFileFromPath]. Implementations must not leave a partial file at
  /// [destinationPath] on failure.
  Future<void> downloadToFile(String fileId, String destinationPath);

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
mixin CloudStorageProviderMixin implements CloudStorageProvider {
  static const String syncFolderName = 'Submersion Sync';

  /// Buffering fallback: reads the source into memory and delegates to
  /// [uploadFile]. Providers with a streaming transport override this.
  @override
  Future<UploadResult> uploadFileFromPath(
    String sourcePath,
    String filename, {
    String? folderId,
  }) async {
    final data = await File(sourcePath).readAsBytes();
    return uploadFile(data, filename, folderId: folderId);
  }

  /// Buffering fallback: downloads into memory via [downloadFile] and spills
  /// to [destinationPath]. Providers with a streaming transport override
  /// this. Deletes a partial destination on failure so callers never see a
  /// truncated file.
  @override
  Future<void> downloadToFile(String fileId, String destinationPath) async {
    final bytes = await downloadFile(fileId);
    final dest = File(destinationPath);
    try {
      await dest.writeAsBytes(bytes, flush: true);
    } catch (_) {
      try {
        if (await dest.exists()) await dest.delete();
      } catch (_) {
        // Best-effort cleanup; the original error is the one that matters.
      }
      rethrow;
    }
  }

  static const String syncFileStem = 'submersion_sync';
  static const String canonicalSyncFileName = '$syncFileStem.json';
  static const String syncFilePrefix = '${syncFileStem}_';
  static const String syncFileExtension = '.json';

  /// Generate a sync filename with timestamp
  String generateSyncFilename() {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    return '$syncFilePrefix$timestamp$syncFileExtension';
  }

  /// Check if a filename matches the sync file pattern
  bool isSyncFile(String filename) {
    if (filename == canonicalSyncFileName) {
      return true;
    }
    return filename.startsWith(syncFilePrefix) &&
        filename.endsWith(syncFileExtension);
  }

  /// Returns true if the filename looks like an iCloud conflicted copy.
  bool isConflictCopy(String filename) {
    final lower = filename.toLowerCase();
    return lower.contains('conflicted copy') || lower.contains('conflict');
  }
}
