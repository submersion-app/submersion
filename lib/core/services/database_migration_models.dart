/// Result of a database migration operation
class MigrationResult {
  final bool success;
  final String? errorMessage;
  final String? oldPath;
  final String? newPath;
  final String? backupPath;

  const MigrationResult._({
    required this.success,
    this.errorMessage,
    this.oldPath,
    this.newPath,
    this.backupPath,
  });

  factory MigrationResult.success({
    required String oldPath,
    required String newPath,
    String? backupPath,
  }) {
    return MigrationResult._(
      success: true,
      oldPath: oldPath,
      newPath: newPath,
      backupPath: backupPath,
    );
  }

  factory MigrationResult.failure(String errorMessage) {
    return MigrationResult._(success: false, errorMessage: errorMessage);
  }
}

/// Information about an existing database found at a location
class ExistingDatabaseInfo {
  final String path;
  final int userCount;
  final int diveCount;
  final int siteCount;
  final int tripCount;
  final int buddyCount;
  final int fileSize;
  final DateTime? lastModified;

  const ExistingDatabaseInfo({
    required this.path,
    required this.userCount,
    required this.diveCount,
    required this.siteCount,
    required this.tripCount,
    required this.buddyCount,
    required this.fileSize,
    this.lastModified,
  });

  String get formattedFileSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
