import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/storage/storage_category.dart';
import 'package:submersion/core/services/storage/storage_inventory.dart';
import 'package:submersion/features/backup/data/repositories/backup_preferences.dart';
import 'package:submersion/features/backup/data/services/backup_service.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/presentation/providers/storage_providers.dart';

/// The real inventory, wired to path_provider and the live services.
final storageInventoryProvider = Provider<StorageInventory>((ref) {
  // Memoized because the local cache database and the two thumbnail categories
  // each resolve it, and it is a platform channel round trip that returns the
  // same immutable path every time for the life of the process. The media
  // cache rows go through mediaCacheRoot(), which carries its own memo.
  //
  // The MediaCacheStore itself is rebuilt per call on purpose: it captures the
  // LocalCacheDatabase at construction, and caching one across the session
  // would hold a stale handle after a database location migration.
  Future<Directory>? supportDirectory;
  Future<Directory> resolveSupport() =>
      supportDirectory ??= getApplicationSupportDirectory();

  return StorageInventory(
    supportDirectory: resolveSupport,
    documentsDirectory: getApplicationDocumentsDirectory,
    temporaryDirectory: getTemporaryDirectory,
    databasePath: () =>
        ref.read(databaseLocationServiceProvider).getDatabasePath(),
    backupsDirectoryPath: _resolveBackupsDirectoryPath,
    mediaCacheBytes: (kind) async {
      final store = MediaCacheStore(
        database: LocalCacheDatabaseService.instance.database,
        root: await mediaCacheRoot(),
      );
      return store.totalBytes(kind);
    },
    mapTileKibibytes: _resolveMapTileKibibytes,
    networkImageDirectory: () async => Directory(
      p.join((await getTemporaryDirectory()).path, DefaultCacheManager.key),
    ),
  );
});

/// The descriptor list. Pure construction, so a plain Provider.
final storageCategoriesProvider = Provider<List<StorageCategory>>(
  (ref) => ref.watch(storageInventoryProvider).categories,
);

/// One future per category, keyed by [StorageCategory.id].
///
/// Keyed rather than a single future over the whole list so every row loads
/// independently: the media cache pools resolve instantly off an index while
/// the network image walk can take seconds, and a category that throws shows an
/// error on its own row instead of blanking the page.
final storageCategorySizeProvider = FutureProvider.family<int?, String>((
  ref,
  id,
) {
  final category = ref
      .watch(storageCategoriesProvider)
      .firstWhere((c) => c.id == id);
  return category.measure();
});

/// Chooses the directory to measure for the backups category, or null when
/// there is no directory to measure.
///
/// An Android SAF location is a content:// tree URI with no Directory behind
/// it. Reporting it as zero bytes would tell the user their backups had
/// vanished, so it reports unavailable instead.
///
/// Split out from [_resolveBackupsDirectoryPath] because this is the whole of
/// the decision, and the SAF branch is the reason StorageCategory.measure
/// returns a nullable int at all. It deserves a test that does not need
/// SharedPreferences to run.
///
/// [defaultPath] is a callback rather than a value on purpose:
/// `resolveDefaultBackupsDirectory` creates the directory if it is missing, and
/// measuring storage must not have that side effect on a device whose backups
/// live somewhere else entirely.
@visibleForTesting
Future<String?> backupsPathToMeasure({
  required String? configuredLocation,
  required Future<String> Function() defaultPath,
}) async {
  if (configuredLocation == null || configuredLocation.isEmpty) {
    return defaultPath();
  }
  if (configuredLocation.startsWith('content://')) return null;
  return configuredLocation;
}

Future<String?> _resolveBackupsDirectoryPath() async {
  final prefs = await SharedPreferences.getInstance();
  return backupsPathToMeasure(
    configuredLocation: BackupPreferences(prefs).getSettings().backupLocation,
    defaultPath: BackupService.resolveDefaultBackupsDirectory,
  );
}

/// Returns null when the tile store never initialized.
///
/// Startup swallows a tile cache initialization failure (see the tileCache step
/// in startup_page.dart), so an uninitialized store is a normal state rather
/// than a bug, and getTotalCacheSize would throw a StateError on it.
Future<double?> _resolveMapTileKibibytes() async {
  try {
    return await TileCacheService.instance.getTotalCacheSize();
  } on StateError {
    return null;
  }
}
