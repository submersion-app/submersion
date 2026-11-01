import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Native error code for an asset the platform cannot edit in place because
/// it is a Live Photo (a still paired with a short video).
///
/// PhotoKit's content-editing round-trip expects the output to represent both
/// resources, so writing back a bare modified still is rejected with
/// `PHPhotosErrorDomain error 3302`. The iOS and macOS handlers detect the
/// case up front and return this code instead of that raw error.
const metadataWriteLivePhotoUnsupportedCode = 'LIVE_PHOTO_UNSUPPORTED';

/// Native error code for a video, which Submersion deliberately refuses.
///
/// Writing metadata to a video cannot be done in place: it meant exporting a
/// copy, creating a new asset from it and deleting the original. Submersion
/// must never delete a user's original media (issue #1472), so the whole path
/// was removed rather than made non-destructive.
const metadataWriteVideoUnsupportedCode = 'VIDEO_UNSUPPORTED';

/// Exception thrown when metadata writing fails.
class MetadataWriteException implements Exception {
  final String message;

  /// The originating native error code, when the failure came from the
  /// platform channel. Null for failures raised on the Dart side.
  ///
  /// Callers in the presentation layer use this to substitute a localized
  /// message for [message], which is English-only.
  final String? code;

  final Object? cause;

  const MetadataWriteException(this.message, {this.code, this.cause});

  @override
  String toString() => message;
}

/// Dive metadata to write to photo/video files.
class DiveMediaMetadata {
  /// Depth in meters (written as GPS altitude below sea level).
  final double? depthMeters;

  /// Water temperature in Celsius.
  final double? temperatureCelsius;

  /// GPS latitude.
  final double? latitude;

  /// GPS longitude.
  final double? longitude;

  /// Dive site name.
  final String? siteName;

  /// Original media timestamp.
  final DateTime? takenAt;

  /// Elapsed time from dive start in seconds.
  final int? elapsedSeconds;

  const DiveMediaMetadata({
    this.depthMeters,
    this.temperatureCelsius,
    this.latitude,
    this.longitude,
    this.siteName,
    this.takenAt,
    this.elapsedSeconds,
  });

  /// Create from MediaItem and its enrichment.
  factory DiveMediaMetadata.fromMediaItem(MediaItem item, {String? siteName}) {
    final enrichment = item.enrichment;
    return DiveMediaMetadata(
      depthMeters: enrichment?.depthMeters,
      temperatureCelsius: enrichment?.temperatureCelsius,
      latitude: item.latitude,
      longitude: item.longitude,
      siteName: siteName,
      takenAt: item.takenAt,
      elapsedSeconds: enrichment?.elapsedSeconds,
    );
  }

  /// Convert to map for platform channel.
  Map<String, dynamic> toMap() {
    return {
      if (depthMeters != null) 'depthMeters': depthMeters,
      if (temperatureCelsius != null) 'temperatureCelsius': temperatureCelsius,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (siteName != null) 'siteName': siteName,
      if (takenAt != null) 'takenAt': takenAt!.toIso8601String(),
      if (elapsedSeconds != null) 'elapsedSeconds': elapsedSeconds,
    };
  }

  /// Build a description string for metadata fields.
  String buildDescription() {
    final parts = <String>[];

    if (depthMeters != null) {
      parts.add('Depth: ${depthMeters!.toStringAsFixed(1)}m');
    }
    if (temperatureCelsius != null) {
      parts.add('Temp: ${temperatureCelsius!.toStringAsFixed(0)}C');
    }
    if (elapsedSeconds != null) {
      final minutes = elapsedSeconds! ~/ 60;
      final secs = elapsedSeconds! % 60;
      parts.add('Dive time: +$minutes:${secs.toString().padLeft(2, '0')}');
    }
    if (siteName != null && siteName!.isNotEmpty) {
      parts.add('Site: $siteName');
    }

    return parts.join(' | ');
  }

  /// Check if there's any metadata worth writing.
  bool get hasData =>
      depthMeters != null ||
      temperatureCelsius != null ||
      (latitude != null && longitude != null);
}

/// Service for writing dive metadata to photos.
///
/// Uses platform channels to access native APIs:
/// - iOS/macOS: PHPhotoLibrary with CGImageDestination
/// - Android: MediaStore with ExifInterface
///
/// Supports:
/// - JPEG photos (EXIF)
/// - HEIC/HEIF photos (EXIF via CGImageDestination)
///
/// Photos are edited in place, so the asset keeps its identity and the user
/// keeps Revert to Original.
///
/// Does not support videos: see [metadataWriteVideoUnsupportedCode]. Does not
/// support Live Photos on iOS or macOS: see
/// [metadataWriteLivePhotoUnsupportedCode].
class MetadataWriteService {
  static const _channel = MethodChannel('com.submersion.app/metadata');
  final _log = LoggerService.forClass(MetadataWriteService);

  /// Debug-only seam overriding the platform-support check. Leave null to use
  /// the real `Platform` check.
  ///
  /// Without it every test here has to be skipped off Apple and Android, and
  /// CI runs its test shards on Linux, so both files would be dead weight
  /// exactly where they are meant to guard against regressions.
  ///
  /// [isSupported] reads this inside an `assert`, which is stripped from
  /// release builds, so assigning it cannot change shipped behavior. Same
  /// shape as Flutter's own `debugDefaultTargetPlatformOverride`.
  @visibleForTesting
  static bool? debugSupportedOverride;

  /// Whether [item] is something this service can write to at all: a photo in
  /// a device library, on a platform with a native writer.
  ///
  /// Media with no library asset (a Files tab pick, a cloud-backed row, a
  /// linked URL) has no original to edit in place, so the action is not
  /// offered for it (issue #3808).
  bool canWriteTo(MediaItem item) =>
      isSupported && item.isGalleryPhoto && !item.isVideo;

  /// Write dive metadata to a photo in the device library.
  ///
  /// [platformAssetId] - This device's identifier for the asset. A row's stored
  ///                     id belongs to the device that linked it, so pass the
  ///                     id `AssetResolutionService` resolves.
  /// [metadata] - The dive metadata to write.
  /// [isVideo] - Whether the caller believes the asset is a video. Videos are
  ///             refused two ways. When this is true the refusal happens here,
  ///             before the platform channel, and nothing is sent. When it is
  ///             false the call proceeds, and the native handler refuses
  ///             anyway if the library reports the asset as a video, which is
  ///             how a mislabelled asset is caught.
  ///
  /// Returns true if successful.
  /// Throws [MetadataWriteException] with a user-friendly message on failure.
  Future<bool> writeMetadata({
    required String platformAssetId,
    required DiveMediaMetadata metadata,
    required bool isVideo,
  }) async {
    if (!isSupported) {
      throw const MetadataWriteException(
        'Metadata writing is only supported on iOS, macOS, and Android.',
      );
    }

    // Refused up front so no argument that could destroy an original ever
    // reaches the platform channel. The UI does not offer the action for a
    // video, so this is a backstop rather than a user-facing path.
    if (isVideo) {
      _log.warning('Refusing to write metadata to a video: $platformAssetId');
      throw const MetadataWriteException(
        'Writing dive data to videos is not supported.',
        code: metadataWriteVideoUnsupportedCode,
      );
    }

    _log.info('Writing metadata to photo: $platformAssetId');

    if (!metadata.hasData) {
      _log.warning('No metadata to write');
      return false;
    }

    try {
      _log.info('Invoking platform channel writeMetadata...');
      // ignore: avoid_print
      print('[MetadataWriteService] Invoking platform channel...');
      final result = await _channel.invokeMethod<bool>('writeMetadata', {
        'assetId': platformAssetId,
        'metadata': metadata.toMap(),
        'description': metadata.buildDescription(),
        'isVideo': isVideo,
      });
      // ignore: avoid_print
      print('[MetadataWriteService] Platform channel returned: $result');
      _log.info('Platform channel returned: $result');

      if (result == true) {
        _log.info('Successfully wrote metadata to: $platformAssetId');
        return true;
      } else {
        throw const MetadataWriteException(
          'Failed to write metadata. The operation returned false.',
        );
      }
    } on PlatformException catch (e) {
      _log.error('Platform exception writing metadata', error: e);
      throw MetadataWriteException(
        _parseErrorMessage(e),
        code: e.code,
        cause: e,
      );
    } catch (e) {
      _log.error('Unexpected error writing metadata', error: e);
      throw MetadataWriteException(
        'An unexpected error occurred: ${e.toString()}',
        cause: e,
      );
    }
  }

  /// Parse platform exception into user-friendly message.
  String _parseErrorMessage(PlatformException e) {
    final code = e.code;
    final message = e.message ?? '';

    switch (code) {
      case 'PERMISSION_DENIED':
        return 'Photo library permission denied. '
            'Please grant full access in Settings.';
      case 'ASSET_NOT_FOUND':
        return 'Photo/video not found. It may have been deleted.';
      case 'READ_ONLY':
        return 'This media is read-only. '
            'Cannot modify iCloud-only or shared album items.';
      case 'UNSUPPORTED_FORMAT':
        return 'This file format does not support metadata writing.';
      case metadataWriteVideoUnsupportedCode:
        // Deliberately discards the native message for the same reason as the
        // Live Photo case below.
        return 'Writing dive data to videos is not supported.';
      case metadataWriteLivePhotoUnsupportedCode:
        // Deliberately discards the native message: PhotoKit's own text for
        // this case is an untranslated error-domain string.
        return 'Live Photos are not supported yet. '
            'Duplicate this as a still photo, '
            'then write the dive data to the copy.';
      case 'WRITE_FAILED':
        return message.isNotEmpty ? message : 'Failed to write metadata.';
      default:
        return message.isNotEmpty
            ? message
            : 'Failed to write metadata (error: $code).';
    }
  }

  /// Check if metadata writing is supported on this platform.
  bool get isSupported {
    var supported = Platform.isIOS || Platform.isMacOS || Platform.isAndroid;
    // The override is read inside an assert so it is compiled out of release
    // builds entirely: production behavior cannot be changed by assigning it,
    // whatever the analyzer's @visibleForTesting enforcement does or does not
    // catch. Mirrors how `defaultTargetPlatform` honours
    // `debugDefaultTargetPlatformOverride`.
    assert(() {
      final override = debugSupportedOverride;
      if (override != null) supported = override;
      return true;
    }());
    return supported;
  }

  /// Get supported file types for the current platform.
  List<String> get supportedTypes {
    if (Platform.isIOS || Platform.isMacOS) {
      return ['JPEG', 'HEIC', 'HEIF', 'PNG'];
    } else if (Platform.isAndroid) {
      return ['JPEG', 'PNG'];
    }
    return [];
  }
}
