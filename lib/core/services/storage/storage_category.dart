/// Where a storage category is shown on the usage page.
enum StorageGroup { appData, mediaCache, caches, backups, temporary, exports }

/// Stable category ids.
///
/// These key the l10n label, the size provider, and the reclaim policy that a
/// later slice adds. They are deliberately not derived from directory names: a
/// directory can be renamed without breaking a saved layout or a test, and an
/// id cannot.
abstract final class StorageCategoryId {
  static const database = 'database';
  static const localCache = 'localCache';
  static const mediaCacheOriginals = 'mediaCacheOriginals';
  static const mediaCacheThumbs = 'mediaCacheThumbs';
  static const mediaCacheRenditions = 'mediaCacheRenditions';
  static const mediaCacheStaging = 'mediaCacheStaging';
  static const mediaCacheTranscode = 'mediaCacheTranscode';
  static const mapTiles = 'mapTiles';
  static const networkImages = 'networkImages';
  static const videoThumbnails = 'videoThumbnails';
  static const pdfThumbnails = 'pdfThumbnails';
  static const backups = 'backups';
  static const temporary = 'temporary';
  static const exports = 'exports';
}

/// One place on disk where the app accumulates bytes.
///
/// Measurement cost is uneven by an order of magnitude across categories: the
/// media cache pools are a SUM over an index, the tile cache has a native size
/// call, and the rest need a recursive walk. Each category therefore brings its
/// own strategy rather than everything sharing one directory walk, and the page
/// renders each result as it arrives instead of being paced by the slowest.
class StorageCategory {
  const StorageCategory({
    required this.id,
    required this.group,
    required this.measure,
  });

  /// One of [StorageCategoryId].
  final String id;

  final StorageGroup group;

  /// Returns the bytes held, or null when the category is structurally
  /// unmeasurable on this platform or in this configuration. Null is not zero:
  /// an Android SAF backup location has no directory to enumerate, and
  /// reporting it as empty would tell the user their backups had vanished.
  final Future<int?> Function() measure;
}
