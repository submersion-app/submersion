import 'dart:io';

import 'package:native_exif/native_exif.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Exception thrown when EXIF writing fails.
class ExifWriteException implements Exception {
  final String message;
  final Object? cause;

  const ExifWriteException(this.message, {this.cause});

  @override
  String toString() => message;
}

/// Metadata to write to photo EXIF.
class DiveMetadata {
  /// Depth in meters (will be written as negative altitude).
  final double? depthMeters;

  /// Water temperature in Celsius.
  final double? temperatureCelsius;

  /// GPS latitude (preserved or updated).
  final double? latitude;

  /// GPS longitude (preserved or updated).
  final double? longitude;

  /// Dive site name for description.
  final String? siteName;

  /// Original photo timestamp.
  final DateTime? takenAt;

  /// Elapsed time from dive start in seconds.
  final int? elapsedSeconds;

  const DiveMetadata({
    this.depthMeters,
    this.temperatureCelsius,
    this.latitude,
    this.longitude,
    this.siteName,
    this.takenAt,
    this.elapsedSeconds,
  });

  /// Create from MediaItem and its enrichment.
  factory DiveMetadata.fromMediaItem(MediaItem item, {String? siteName}) {
    final enrichment = item.enrichment;
    return DiveMetadata(
      depthMeters: enrichment?.depthMeters,
      temperatureCelsius: enrichment?.temperatureCelsius,
      latitude: item.latitude,
      longitude: item.longitude,
      siteName: siteName,
      takenAt: item.takenAt,
      elapsedSeconds: enrichment?.elapsedSeconds,
    );
  }

  /// Build a description string for ImageDescription EXIF field.
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

/// Service for writing dive metadata to photo EXIF data.
///
/// Uses the native_exif package for cross-platform EXIF manipulation.
/// Note: This modifies the original photo file in the device gallery.
class ExifWriteService {
  final _log = LoggerService.forClass(ExifWriteService);

  /// Write dive metadata to the original photo file.
  ///
  /// Returns true if successful, false if failed.
  /// Throws if the asset cannot be found or accessed.
  ///
  /// Note: On iOS/macOS, this requires full photo library access permission.
  /// The function tries `originFile` first (actual file) before falling back
  /// to `file` (which may be a temporary copy on some platforms).
  Future<bool> writeMetadataToPhoto({
    required String platformAssetId,
    required DiveMetadata metadata,
  }) async {
    _log.info('Writing EXIF metadata to asset: $platformAssetId');

    try {
      // Get the asset from photo library
      final asset = await pm.AssetEntity.fromId(platformAssetId);
      if (asset == null) {
        _log.error('Asset not found: $platformAssetId');
        throw const ExifWriteException(
          'Photo not found in library. It may have been deleted.',
        );
      }

      // Check file type - EXIF only works reliably on JPEG
      final mimeType = asset.mimeType;
      _log.debug('Asset mimeType: $mimeType, type: ${asset.type}');

      if (mimeType != null &&
          !mimeType.contains('jpeg') &&
          !mimeType.contains('jpg')) {
        _log.warning('Non-JPEG file type: $mimeType - EXIF write may fail');
      }

      // Try to get the original file first (required for actual modification)
      // On iOS/macOS, `file` returns a copy, `originFile` returns the actual file
      File? file;
      String fileSource = 'unknown';

      if (Platform.isIOS || Platform.isMacOS) {
        // Try originFile first - this is the actual file in the photo library
        file = await asset.originFile;
        fileSource = 'originFile';

        if (file == null) {
          _log.warning('originFile returned null, trying file property');
          file = await asset.file;
          fileSource = 'file (copy)';
        }
      } else {
        // On Android, file property typically returns the actual file
        file = await asset.file;
        fileSource = 'file';
      }

      if (file == null) {
        _log.error('Could not get file for asset: $platformAssetId');
        throw const ExifWriteException(
          'Could not access photo file. Check photo library permissions.',
        );
      }

      final filePath = file.path;
      _log.debug('Writing EXIF to $fileSource: $filePath');

      // Check if file exists
      if (!await File(filePath).exists()) {
        _log.error('File does not exist: $filePath');
        throw const ExifWriteException(
          'Photo file not found at expected location.',
        );
      }

      // Check if file is writable
      try {
        final testFile = File(filePath);
        final stat = await testFile.stat();
        _log.debug(
          'File stat - size: ${stat.size}, mode: ${stat.mode}, '
          'modified: ${stat.modified}',
        );
      } catch (e) {
        _log.warning('Could not stat file: $e');
      }

      // Open EXIF interface
      final exif = await Exif.fromPath(filePath);

      // Write depth as GPS altitude (negative = below sea level)
      if (metadata.depthMeters != null) {
        // GPSAltitude is stored as positive value
        // GPSAltitudeRef: 0 = above sea level, 1 = below sea level
        await exif.writeAttributes({
          'GPSAltitude': metadata.depthMeters!.abs().toString(),
          'GPSAltitudeRef': '1', // 1 = below sea level
        });
        _log.debug('Wrote depth: ${metadata.depthMeters}m');
      }

      // Write GPS coordinates if available
      if (metadata.latitude != null && metadata.longitude != null) {
        await exif.writeAttributes({
          'GPSLatitude': _formatGpsCoordinate(metadata.latitude!.abs()),
          'GPSLatitudeRef': metadata.latitude! >= 0 ? 'N' : 'S',
          'GPSLongitude': _formatGpsCoordinate(metadata.longitude!.abs()),
          'GPSLongitudeRef': metadata.longitude! >= 0 ? 'E' : 'W',
        });
        _log.debug('Wrote GPS: ${metadata.latitude}, ${metadata.longitude}');
      }

      // Write description with dive info
      final description = metadata.buildDescription();
      if (description.isNotEmpty) {
        await exif.writeAttribute('ImageDescription', description);
        _log.debug('Wrote description: $description');
      }

      // Close to ensure changes are written
      await exif.close();

      _log.info('Successfully wrote EXIF metadata to: $platformAssetId');
      return true;
    } on ExifWriteException {
      rethrow;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to write EXIF metadata to: $platformAssetId',
        e,
        stackTrace,
      );

      // Provide helpful error message based on common failure modes
      String message = 'Failed to write metadata to photo.';
      final errorStr = e.toString().toLowerCase();

      if (errorStr.contains('permission') || errorStr.contains('access')) {
        message =
            'Permission denied. Grant full photo library access in Settings.';
      } else if (errorStr.contains('read-only') ||
          errorStr.contains('readonly')) {
        message =
            'Photo is read-only. Cannot modify photos from iCloud or shared albums.';
      } else if (errorStr.contains('heic') || errorStr.contains('heif')) {
        message =
            'HEIC photos not supported. Only JPEG photos can have EXIF written.';
      } else if (Platform.isMacOS) {
        message =
            'macOS photo library access may be limited. '
            'Try granting Full Disk Access in System Settings > Privacy.';
      }

      throw ExifWriteException(message, cause: e);
    }
  }

  /// Format decimal degrees to EXIF GPS format (degrees, minutes, seconds).
  String _formatGpsCoordinate(double decimal) {
    final degrees = decimal.floor();
    final minutesDecimal = (decimal - degrees) * 60;
    final minutes = minutesDecimal.floor();
    final seconds = (minutesDecimal - minutes) * 60;
    return '$degrees/1,$minutes/1,${(seconds * 100).round()}/100';
  }

  /// Check if EXIF writing is supported on this platform.
  bool get isSupported => Platform.isIOS || Platform.isAndroid;

  /// Read current EXIF data from a photo (for preview/debugging).
  Future<Map<String, dynamic>?> readExifData(String platformAssetId) async {
    try {
      final asset = await pm.AssetEntity.fromId(platformAssetId);
      if (asset == null) return null;

      final file = await asset.file;
      if (file == null) return null;

      final exif = await Exif.fromPath(file.path);
      final attributes = await exif.getAttributes();
      await exif.close();

      return attributes;
    } catch (e) {
      _log.error('Failed to read EXIF data: $platformAssetId', e);
      return null;
    }
  }
}
