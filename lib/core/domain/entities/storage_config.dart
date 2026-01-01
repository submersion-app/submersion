/// Storage location mode for the database
enum StorageLocationMode {
  /// Default app-managed location (Documents/Submersion)
  appDefault,

  /// Custom user-selected folder (for Dropbox, Google Drive desktop sync, etc.)
  customFolder,
}

/// Configuration for where the database is stored
class StorageConfig {
  /// The storage location mode
  final StorageLocationMode mode;

  /// The custom folder path (only used when mode is customFolder)
  final String? customFolderPath;

  /// When the custom folder was last verified to be accessible
  final DateTime? lastVerified;

  const StorageConfig({
    this.mode = StorageLocationMode.appDefault,
    this.customFolderPath,
    this.lastVerified,
  });

  /// Whether we're using a custom storage location
  bool get isCustomLocation => mode == StorageLocationMode.customFolder;

  /// Whether the custom folder path needs verification
  bool get requiresPathVerification =>
      isCustomLocation && customFolderPath != null;

  /// Create a copy with updated values
  StorageConfig copyWith({
    StorageLocationMode? mode,
    String? customFolderPath,
    DateTime? lastVerified,
    bool clearCustomFolderPath = false,
    bool clearLastVerified = false,
  }) {
    return StorageConfig(
      mode: mode ?? this.mode,
      customFolderPath:
          clearCustomFolderPath ? null : (customFolderPath ?? this.customFolderPath),
      lastVerified:
          clearLastVerified ? null : (lastVerified ?? this.lastVerified),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StorageConfig &&
        other.mode == mode &&
        other.customFolderPath == customFolderPath &&
        other.lastVerified == lastVerified;
  }

  @override
  int get hashCode => Object.hash(mode, customFolderPath, lastVerified);

  @override
  String toString() {
    return 'StorageConfig(mode: $mode, customFolderPath: $customFolderPath, lastVerified: $lastVerified)';
  }
}
