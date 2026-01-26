import 'dart:io';

import 'package:native_exif/native_exif.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

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
        return false;
      }

      // Get the file path
      final file = await asset.file;
      if (file == null) {
        _log.error('Could not get file for asset: $platformAssetId');
        return false;
      }

      final filePath = file.path;
      _log.debug('Writing EXIF to file: $filePath');

      // Check if file exists and is writable
      if (!await File(filePath).exists()) {
        _log.error('File does not exist: $filePath');
        return false;
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
    } catch (e, stackTrace) {
      _log.error(
        'Failed to write EXIF metadata to: $platformAssetId',
        e,
        stackTrace,
      );
      return false;
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
