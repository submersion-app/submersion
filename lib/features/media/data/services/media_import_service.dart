import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/enrichment_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

/// Result of a media import operation.
class ImportResult {
  /// Successfully imported items.
  final List<MediaItem> imported;

  /// Asset IDs that failed to import, with error messages.
  final Map<String, String> failures;

  /// Number of assets skipped because they were already linked to the dive.
  final int skippedDuplicates;

  const ImportResult({
    required this.imported,
    required this.failures,
    this.skippedDuplicates = 0,
  });

  /// Total number of items attempted.
  int get totalAttempted =>
      imported.length + failures.length + skippedDuplicates;

  /// Whether all imports succeeded (skipped duplicates are not failures).
  bool get allSucceeded => failures.isEmpty;
}

/// Service for importing photos from the device gallery into the app.
///
/// Handles the full import flow:
/// 1. Creates MediaItem records in the database
/// 2. Calculates enrichment data from dive profile
/// 3. Saves enrichment data
class MediaImportService {
  final MediaRepository _mediaRepository;
  final EnrichmentService _enrichmentService;
  final _log = LoggerService.forClass(MediaImportService);

  MediaImportService({
    required MediaRepository mediaRepository,
    required EnrichmentService enrichmentService,
    Future<Directory> Function()? documentsDirectory,
    this.onMediaCreated,
  }) : _mediaRepository = mediaRepository,
       _enrichmentService = enrichmentService,
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectory;

  /// Invoked after every successful createMedia so the media store can
  /// enqueue an upload. Null when no store is configured.
  final void Function(String mediaId)? onMediaCreated;

  /// Copies [sourceFile] into the app documents directory (subdir
  /// [subdirectory]) and creates a localFile media row linked to [diveId].
  ///
  /// [subdirectory] defaults to 'scanned_logs' for the OCR scan flow that
  /// introduced this method; file imports pass their own so an imported
  /// logbook's photos are not filed as scanned pages.
  ///
  /// [latitude] and [longitude] are the photo's own coordinates when the
  /// source recorded them, which is not the same as the dive site's.
  Future<MediaItem> importLocalFileForDive({
    required File sourceFile,
    required String diveId,
    DateTime? takenAt,
    double? latitude,
    double? longitude,
    String subdirectory = 'scanned_logs',
  }) async {
    final docs = await _documentsDirectory();
    final dir = Directory(p.join(docs.path, subdirectory));
    await dir.create(recursive: true);
    final sourceExt = p.extension(sourceFile.path);
    final ext = sourceExt.isEmpty ? '.jpg' : sourceExt;
    // A millisecond stamp alone collides when a batch import copies two
    // photos inside the same millisecond, and the second copy would
    // overwrite the first. Disambiguate with a counter.
    var destName = '${DateTime.now().millisecondsSinceEpoch}$ext';
    var destPath = p.join(dir.path, destName);
    var counter = 1;
    while (File(destPath).existsSync()) {
      destName = '${DateTime.now().millisecondsSinceEpoch}_${counter++}$ext';
      destPath = p.join(dir.path, destName);
    }
    final dest = await sourceFile.copy(destPath);
    final now = DateTime.now();
    final item = MediaItem(
      id: '',
      diveId: diveId,
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      filePath: dest.path,
      originalFilename: p.basename(sourceFile.path),
      latitude: latitude,
      longitude: longitude,
      takenAt: takenAt ?? now,
      createdAt: now,
      updatedAt: now,
    );
    final created = await _mediaRepository.createMedia(item);
    onMediaCreated?.call(created.id);
    return created;
  }

  /// Import selected assets for a dive.
  ///
  /// [selectedAssets] - Assets selected from the photo picker.
  /// [dive] - The dive to associate the media with.
  ///
  /// Returns an [ImportResult] with successfully imported items and any failures.
  Future<ImportResult> importPhotosForDive({
    required List<AssetInfo> selectedAssets,
    required Dive dive,
  }) async {
    final List<MediaItem> imported = [];
    final Map<String, String> failures = {};

    _log.info(
      'Starting import of ${selectedAssets.length} assets for dive ${dive.id}',
    );

    // Two dedupe keys, one per origin. Gallery picks are matched on their
    // platform asset id; desktop picks are localFile rows with a null
    // platform_asset_id (see [_createMediaItemFromAsset]), invisible to that
    // query, so they are matched on the path instead.
    //
    // Each lookup only feeds one branch of the filter below, so query a
    // lookup only when the selection actually contains that kind of asset:
    // a mobile pick has no paths to compare and a desktop pick has no
    // gallery ids, and either way the unused set would be dead work.
    bool hasPath(AssetInfo a) => a.filePath != null && a.filePath!.isNotEmpty;
    final anyPaths = selectedAssets.any(hasPath);
    final anyGallery = selectedAssets.any((a) => !hasPath(a));

    final existingAssetIds = anyGallery
        ? await _mediaRepository.getLinkedAssetIdsForDive(dive.id)
        : const <String>{};
    final existingPaths = anyPaths
        ? await _mediaRepository.getLinkedLocalPathsForDive(dive.id)
        : const <String>{};

    // Filter out duplicates before processing
    final newAssets = selectedAssets.where((a) {
      if (hasPath(a)) return !existingPaths.contains(a.filePath);
      return !existingAssetIds.contains(a.id);
    }).toList();
    final skippedCount = selectedAssets.length - newAssets.length;

    if (skippedCount > 0) {
      _log.info('Skipped $skippedCount duplicate assets for dive ${dive.id}');
    }

    for (final asset in newAssets) {
      try {
        // Create MediaItem
        final mediaItem = _createMediaItemFromAsset(asset, diveId: dive.id);

        // Save to database
        final saved = await _mediaRepository.createMedia(mediaItem);

        // Calculate enrichment from dive profile
        final enrichment = _calculateEnrichment(
          asset: asset,
          dive: dive,
          mediaId: saved.id,
        );

        // Save enrichment if we got meaningful data
        if (enrichment != null) {
          await _mediaRepository.saveEnrichment(enrichment);
        }

        imported.add(saved);
        onMediaCreated?.call(saved.id);
        _log.info('Imported asset ${asset.id} as media ${saved.id}');
      } catch (e, stackTrace) {
        _log.error(
          'Failed to import asset ${asset.id}',
          error: e,
          stackTrace: stackTrace,
        );
        failures[asset.id] = e.toString();
      }
    }

    _log.info(
      'Import complete: ${imported.length} succeeded, ${failures.length} failed, $skippedCount skipped',
    );

    return ImportResult(
      imported: imported,
      failures: failures,
      skippedDuplicates: skippedCount,
    );
  }

  /// Import selected assets as direct site attachments. Same dedupe
  /// contract as [importPhotosForDive]; no enrichment (sites have no
  /// profile to position photos on).
  Future<ImportResult> importPhotosForSite({
    required List<AssetInfo> selectedAssets,
    required String siteId,
  }) async {
    final List<MediaItem> imported = [];
    final Map<String, String> failures = {};

    _log.info(
      'Starting import of ${selectedAssets.length} assets for site $siteId',
    );

    // Same two-key dedupe as the dive import: gallery picks match on the
    // platform asset id, desktop picks on the path.
    bool hasPath(AssetInfo a) => a.filePath != null && a.filePath!.isNotEmpty;
    final anyPaths = selectedAssets.any(hasPath);
    final anyGallery = selectedAssets.any((a) => !hasPath(a));

    final existingAssetIds = anyGallery
        ? await _mediaRepository.getLinkedAssetIdsForSite(siteId)
        : const <String>{};
    final existingPaths = anyPaths
        ? await _mediaRepository.getLinkedLocalPathsForSite(siteId)
        : const <String>{};

    final newAssets = selectedAssets.where((a) {
      if (hasPath(a)) return !existingPaths.contains(a.filePath);
      return !existingAssetIds.contains(a.id);
    }).toList();
    final skippedCount = selectedAssets.length - newAssets.length;

    for (final asset in newAssets) {
      try {
        final mediaItem = _createMediaItemFromAsset(asset, siteId: siteId);
        final saved = await _mediaRepository.createMedia(mediaItem);
        imported.add(saved);
        onMediaCreated?.call(saved.id);
      } catch (e, stackTrace) {
        _log.error(
          'Failed to import asset ${asset.id} for site',
          error: e,
          stackTrace: stackTrace,
        );
        failures[asset.id] = e.toString();
      }
    }

    _log.info(
      'Site import complete: ${imported.length} succeeded, '
      '${failures.length} failed, $skippedCount skipped',
    );

    return ImportResult(
      imported: imported,
      failures: failures,
      skippedDuplicates: skippedCount,
    );
  }

  MediaItem _createMediaItemFromAsset(
    AssetInfo asset, {
    String? diveId,
    String? siteId,
  }) {
    final now = DateTime.now();

    // Windows / Linux have no platform photo library: the picker opens a file
    // dialog and the asset's id is a synthetic key into an in-memory map on
    // the picker service. Persisting such a row with the default
    // platformGallery sourceType left every path column blank and sent
    // display through PlatformGalleryResolver -> photo_manager, which has no
    // desktop-Windows backend, so the photo rendered "File not found" and the
    // pointer died with the process. When the picker hands us a real path,
    // store a localFile row instead: LocalFileResolver reads localPath
    // straight off disk on every desktop platform and survives a restart.
    final path = asset.filePath;
    final isLocalFile = path != null && path.isNotEmpty;

    return MediaItem(
      id: '',
      diveId: diveId,
      siteId: siteId,
      // Deliberately null for a localFile row. The desktop picker's asset id
      // is a synthetic in-memory key, and several features gate purely on
      // `platformAssetId != null` -- MediaItem.isGalleryPhoto,
      // PhotoViewerPage's write-metadata action, resolvedFilePathProvider's
      // gallery fast path -- so carrying it would route a Windows file
      // through photo_manager, which has no backend there. Duplicate
      // detection for these rows keys on localPath instead.
      platformAssetId: isLocalFile ? null : asset.id,
      originalFilename: asset.filename,
      mediaType: asset.isVideo ? MediaType.video : MediaType.photo,
      sourceType: isLocalFile
          ? MediaSourceType.localFile
          : MediaSourceType.platformGallery,
      localPath: isLocalFile ? path : null,
      latitude: asset.latitude,
      longitude: asset.longitude,
      // AssetInfo.createDateTime is contractually LOCAL (photo_manager's
      // convention on mobile; the desktop picker mirrors it by reinterpreting
      // the file's wall-clock capture digits as a local DateTime). MediaItem
      // .takenAt is wall-clock-UTC -- MediaRepository persists
      // `takenAt.millisecondsSinceEpoch` verbatim and hydrates it back with
      // `isUtc: true`. Storing the local value would bake the host's UTC
      // offset into that number, and the fullscreen viewer's metadata overlay,
      // which formats the hydrated UTC value directly, would show a capture
      // time shifted by that offset. The gallery-scan write path
      // (TripMediaScanner) already normalises the same way.
      takenAt: TripMediaScanner.toWallClockUtc(asset.createDateTime),
      width: asset.width,
      height: asset.height,
      durationSeconds: asset.durationSeconds,
      createdAt: now,
      updatedAt: now,
    );
  }

  MediaEnrichment? _calculateEnrichment({
    required AssetInfo asset,
    required Dive dive,
    required String mediaId,
  }) {
    // Need dive start time and profile (use effectiveEntryTime which handles the fallback)
    final diveStartTime = dive.effectiveEntryTime;
    final profile = dive.profile;

    if (profile.isEmpty) {
      _log.info('No profile data for dive ${dive.id}, skipping enrichment');
      return null;
    }

    final result = _enrichmentService.calculateEnrichment(
      profile: profile,
      diveStartTime: diveStartTime,
      photoTime: asset.createDateTime,
    );

    // Don't save enrichment if we couldn't calculate depth
    if (result.depthMeters == null &&
        result.matchConfidence == MatchConfidence.noProfile) {
      return null;
    }

    return MediaEnrichment(
      id: '',
      mediaId: mediaId,
      diveId: dive.id,
      depthMeters: result.depthMeters,
      temperatureCelsius: result.temperatureCelsius,
      elapsedSeconds: result.elapsedSeconds,
      matchConfidence: result.matchConfidence,
      timestampOffsetSeconds: result.timestampOffsetSeconds,
      createdAt: DateTime.now(),
    );
  }
}
