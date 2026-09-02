import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:submersion/core/services/storage/directory_size.dart';
import 'package:submersion/core/services/storage/storage_category.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';

/// Builds the list of places this app accumulates bytes on disk.
///
/// Every external dependency arrives as a closure rather than being looked up
/// internally, so the whole inventory is testable without path_provider, a real
/// database, or an initialized FMTC store.
class StorageInventory {
  StorageInventory({
    required Future<Directory> Function() supportDirectory,
    required Future<Directory> Function() documentsDirectory,
    required Future<Directory> Function() temporaryDirectory,
    required Future<String> Function() databasePath,
    required Future<String?> Function() backupsDirectoryPath,
    required Future<int> Function(MediaCacheKind kind) mediaCacheBytes,
    required Future<double?> Function() mapTileKibibytes,
    required Future<Directory> Function() networkImageDirectory,
  }) : _supportDirectory = supportDirectory,
       _documentsDirectory = documentsDirectory,
       _temporaryDirectory = temporaryDirectory,
       _databasePath = databasePath,
       _backupsDirectoryPath = backupsDirectoryPath,
       _mediaCacheBytes = mediaCacheBytes,
       _mapTileKibibytes = mapTileKibibytes,
       _networkImageDirectory = networkImageDirectory;

  final Future<Directory> Function() _supportDirectory;
  final Future<Directory> Function() _documentsDirectory;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<String> Function() _databasePath;
  final Future<String?> Function() _backupsDirectoryPath;
  final Future<int> Function(MediaCacheKind kind) _mediaCacheBytes;
  final Future<double?> Function() _mapTileKibibytes;
  final Future<Directory> Function() _networkImageDirectory;

  static const _appDir = 'Submersion';
  static const _localCacheDb = 'submersion_local.db';
  static const _pickedDir = 'picked';

  /// Order is display order on the usage page.
  List<StorageCategory> get categories => [
    StorageCategory(
      id: StorageCategoryId.database,
      group: StorageGroup.appData,
      measure: _measureDatabase,
    ),
    StorageCategory(
      id: StorageCategoryId.localCache,
      group: StorageGroup.appData,
      measure: _measureLocalCache,
    ),
    StorageCategory(
      id: StorageCategoryId.mediaCacheOriginals,
      group: StorageGroup.mediaCache,
      measure: () => _mediaCacheBytes(MediaCacheKind.original),
    ),
    StorageCategory(
      id: StorageCategoryId.mediaCacheThumbs,
      group: StorageGroup.mediaCache,
      measure: () => _mediaCacheBytes(MediaCacheKind.thumb),
    ),
    StorageCategory(
      id: StorageCategoryId.mediaCacheRenditions,
      group: StorageGroup.mediaCache,
      measure: () => _mediaCacheBytes(MediaCacheKind.rendition),
    ),
    // Staging and transcode are walked rather than read from the index: the
    // LRU caps in MediaCacheStore are enforced only over rows in
    // media_cache_entries, and neither subdirectory is indexed. Their bytes are
    // invisible to the 3.25 GiB budget, which is precisely why they get rows.
    StorageCategory(
      id: StorageCategoryId.mediaCacheStaging,
      group: StorageGroup.mediaCache,
      measure: () => _measureSupportSubdirectory(['media_cache', 'staging']),
    ),
    StorageCategory(
      id: StorageCategoryId.mediaCacheTranscode,
      group: StorageGroup.mediaCache,
      measure: () => _measureSupportSubdirectory(['media_cache', 'transcode']),
    ),
    StorageCategory(
      id: StorageCategoryId.mapTiles,
      group: StorageGroup.caches,
      measure: _measureMapTiles,
    ),
    StorageCategory(
      id: StorageCategoryId.networkImages,
      group: StorageGroup.caches,
      measure: _measureNetworkImages,
    ),
    StorageCategory(
      id: StorageCategoryId.videoThumbnails,
      group: StorageGroup.caches,
      measure: () => _measureSupportSubdirectory(['video_thumbnails']),
    ),
    StorageCategory(
      id: StorageCategoryId.pdfThumbnails,
      group: StorageGroup.caches,
      measure: () => _measureSupportSubdirectory(['pdf_thumbnails']),
    ),
    StorageCategory(
      id: StorageCategoryId.backups,
      group: StorageGroup.backups,
      measure: _measureBackups,
    ),
    StorageCategory(
      id: StorageCategoryId.temporary,
      group: StorageGroup.temporary,
      measure: _measureTemporary,
    ),
    StorageCategory(
      id: StorageCategoryId.exports,
      group: StorageGroup.exports,
      measure: _measureExports,
    ),
  ];

  Future<int?> _measureDatabase() async {
    final path = await _databasePath();
    return measureFileGroupBytes([
      File(path),
      File('$path-wal'),
      File('$path-shm'),
    ]);
  }

  /// Includes the WAL sidecars for the same reason the main database does:
  /// drift opens this file in WAL mode and the app holds it open for the whole
  /// session, so `-wal` and `-shm` are present exactly when a user is looking
  /// at this page. Counting only the base file would under-report it.
  Future<int?> _measureLocalCache() async {
    final support = await _supportDirectory();
    final path = p.join(support.path, _appDir, _localCacheDb);
    return measureFileGroupBytes([
      File(path),
      File('$path-wal'),
      File('$path-shm'),
    ]);
  }

  Future<int?> _measureSupportSubdirectory(List<String> segments) async {
    final support = await _supportDirectory();
    return measureDirectoryBytes(
      Directory(p.joinAll([support.path, _appDir, ...segments])),
    );
  }

  /// FMTC reports kibibytes as a double. Converting here rather than at the
  /// call site keeps every category's contract in bytes.
  ///
  /// Floored, not rounded. The difference is at most half a byte and the source
  /// is only KiB-granular anyway, so this is about direction rather than
  /// accuracy: every other category reports a figure that cannot exceed the
  /// truth, and this one should not be the exception.
  Future<int?> _measureMapTiles() async {
    final kibibytes = await _mapTileKibibytes();
    if (kibibytes == null) return null;
    return (kibibytes * 1024).floor();
  }

  Future<int?> _measureBackups() async {
    final path = await _backupsDirectoryPath();
    if (path == null) return null;
    return measureDirectoryBytes(Directory(path));
  }

  /// Walked here rather than delegated to CachedNetworkImageDiagnostics.
  ///
  /// That class's `cacheSize()` catches everything and returns 0, which is the
  /// right call for the card it was written for but wrong here: a permission
  /// failure would arrive as a successful "0 B" and let the header claim a
  /// final total over a measurement that never happened. `measureDirectoryBytes`
  /// keeps the distinction, returning 0 only when the directory genuinely is
  /// not there and throwing when it cannot be read.
  Future<int?> _measureNetworkImages() async =>
      measureDirectoryBytes(await _networkImageDirectory());

  /// The picked/ subtree plus the loose share files at the temp root, never
  /// the whole temp directory.
  ///
  /// A recursive walk of the root would double count: DefaultCacheManager keeps
  /// the network image cache at `<temp>/libCachedImageData`, which already has
  /// its own row, so walking the tree would add those bytes twice. It
  /// would also sweep in temp subtrees belonging to plugins this app does not
  /// own, which is not something a user can act on.
  Future<int?> _measureTemporary() async {
    final temp = await _temporaryDirectory();
    final picked = await measureDirectoryBytes(
      Directory(p.join(temp.path, _pickedDir)),
    );
    final loose = await measureLooseFilesBytes(temp, exclude: (_) => false);
    return picked + loose;
  }

  /// Loose files in the Documents root, which is where saveAndShareFile leaves
  /// every export permanently. The database may or may not live here depending
  /// on the configured location, so it is excluded by name either way, as are
  /// its sidecars and every subdirectory.
  Future<int?> _measureExports() async {
    final documents = await _documentsDirectory();
    final dbName = p.basename(await _databasePath());
    return measureLooseFilesBytes(
      documents,
      exclude: (name) => name.startsWith(dbName),
    );
  }
}
