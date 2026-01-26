import 'dart:io';

import 'package:flutter/services.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Exception thrown when metadata writing fails.
class MetadataWriteException implements Exception {
  final String message;
  final Object? cause;

  const MetadataWriteException(this.message, {this.cause});

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

/// Service for writing dive metadata to photos and videos.
///
/// Uses platform channels to access native APIs:
/// - iOS/macOS: PHPhotoLibrary with CGImageDestination (photos) and AVFoundation (videos)
/// - Android: MediaStore with ExifInterface (photos) and MediaMetadataRetriever (videos)
///
/// Supports:
/// - JPEG photos (EXIF)
/// - HEIC/HEIF photos (EXIF via CGImageDestination)
/// - MOV/MP4 videos (QuickTime metadata)
class MetadataWriteService {
  static const _channel = MethodChannel('com.submersion.app/metadata');
  final _log = LoggerService.forClass(MetadataWriteService);

  /// Write dive metadata to a photo or video in the device library.
  ///
  /// [platformAssetId] - The platform-specific asset identifier.
  /// [metadata] - The dive metadata to write.
  /// [isVideo] - Whether the asset is a video (affects which metadata format is used).
  /// [keepOriginal] - For videos only: whether to keep the original after creating
  ///                  a new video with metadata. Ignored for photos.
  ///
  /// Returns true if successful.
  /// Throws [MetadataWriteException] with a user-friendly message on failure.
  Future<bool> writeMetadata({
    required String platformAssetId,
    required DiveMediaMetadata metadata,
    required bool isVideo,
    bool keepOriginal = false,
  }) async {
    _log.info(
      'Writing metadata to ${isVideo ? "video" : "photo"}: $platformAssetId'
      '${isVideo ? " (keepOriginal: $keepOriginal)" : ""}',
    );

    if (!isSupported) {
      throw const MetadataWriteException(
        'Metadata writing is only supported on iOS, macOS, and Android.',
      );
    }

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
        'keepOriginal': keepOriginal,
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
      _log.error('Platform exception writing metadata', e);
      throw MetadataWriteException(_parseErrorMessage(e), cause: e);
    } catch (e) {
      _log.error('Unexpected error writing metadata', e);
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
      case 'WRITE_FAILED':
        return message.isNotEmpty ? message : 'Failed to write metadata.';
      default:
        return message.isNotEmpty
            ? message
            : 'Failed to write metadata (error: $code).';
    }
  }

  /// Check if metadata writing is supported on this platform.
  bool get isSupported =>
      Platform.isIOS || Platform.isMacOS || Platform.isAndroid;

  /// Get supported file types for the current platform.
  List<String> get supportedTypes {
    if (Platform.isIOS || Platform.isMacOS) {
      return ['JPEG', 'HEIC', 'HEIF', 'PNG', 'MOV', 'MP4'];
    } else if (Platform.isAndroid) {
      return ['JPEG', 'PNG', 'MP4', 'MOV'];
    }
    return [];
  }
}
