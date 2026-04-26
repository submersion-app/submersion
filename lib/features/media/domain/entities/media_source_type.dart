/// The kind of source a [MediaItem] originated from.
///
/// Drives which [MediaSourceResolver] handles displaying the item, and
/// whether the row syncs across devices or stays per-device.
enum MediaSourceType {
  /// Device photo library (Apple Photos / Google Photos / iCloud) via photo_manager.
  platformGallery,

  /// Filesystem path on this device (desktop) or security-scoped handle (iOS/Android).
  localFile,

  /// Ad-hoc HTTP/HTTPS URL.
  networkUrl,

  /// Photo whose origin is a row in a manifest feed (Atom/RSS, JSON, or CSV).
  manifestEntry,

  /// Photo from a configured service connector (Immich, Dropbox, etc.).
  serviceConnector,

  /// Instructor or buddy signature (existing v1.5 feature).
  signature;

  /// Parse from a stored string, returning null if no match is found.
  static MediaSourceType? fromString(String? value) {
    if (value == null) return null;
    for (final type in MediaSourceType.values) {
      if (type.name == value) return type;
    }
    return null;
  }
}
