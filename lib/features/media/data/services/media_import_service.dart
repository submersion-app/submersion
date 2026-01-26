import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/enrichment_service.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Result of a media import operation.
class ImportResult {
  /// Successfully imported items.
  final List<MediaItem> imported;

  /// Asset IDs that failed to import, with error messages.
  final Map<String, String> failures;

  const ImportResult({required this.imported, required this.failures});

  /// Total number of items attempted.
  int get totalAttempted => imported.length + failures.length;

  /// Whether all imports succeeded.
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
  }) : _mediaRepository = mediaRepository,
       _enrichmentService = enrichmentService;

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

    for (final asset in selectedAssets) {
      try {
        // Create MediaItem
        final mediaItem = _createMediaItemFromAsset(asset, dive.id);

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
        _log.info('Imported asset ${asset.id} as media ${saved.id}');
      } catch (e, stackTrace) {
        _log.error('Failed to import asset ${asset.id}', e, stackTrace);
        failures[asset.id] = e.toString();
      }
    }

    _log.info(
      'Import complete: ${imported.length} succeeded, ${failures.length} failed',
    );

    return ImportResult(imported: imported, failures: failures);
  }

  MediaItem _createMediaItemFromAsset(AssetInfo asset, String diveId) {
    final now = DateTime.now();

    return MediaItem(
      id: '',
      diveId: diveId,
      platformAssetId: asset.id,
      originalFilename: asset.filename,
      mediaType: asset.isVideo ? MediaType.video : MediaType.photo,
      latitude: asset.latitude,
      longitude: asset.longitude,
      takenAt: asset.createDateTime,
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
