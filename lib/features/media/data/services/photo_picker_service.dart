import 'dart:typed_data';

/// Permission status for photo library access.
enum PhotoPermissionStatus {
  /// User has granted access.
  authorized,

  /// User has denied access.
  denied,

  /// User has limited access (iOS 14+).
  limited,

  /// Permission has not been requested yet.
  notDetermined,

  /// Access is restricted by device policy.
  restricted,
}

/// Information about a gallery asset (photo or video).
class AssetInfo {
  /// Platform-specific unique identifier for the asset.
  final String id;

  /// Type of asset (image or video).
  final AssetType type;

  /// When the asset was created (from EXIF or file metadata).
  final DateTime createDateTime;

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  /// Duration in seconds (for videos only).
  final int? durationSeconds;

  /// GPS latitude if available.
  final double? latitude;

  /// GPS longitude if available.
  final double? longitude;

  /// Original filename if available.
  final String? filename;

  const AssetInfo({
    required this.id,
    required this.type,
    required this.createDateTime,
    required this.width,
    required this.height,
    this.durationSeconds,
    this.latitude,
    this.longitude,
    this.filename,
  });

  /// Whether this asset is a video.
  bool get isVideo => type == AssetType.video;
}

/// Type of gallery asset.
enum AssetType { image, video }

/// Abstract service for accessing the device's photo gallery.
///
/// This service provides platform-specific implementations for:
/// - Querying photos/videos by date range (iOS/Android/macOS via photo_manager)
/// - Falling back to file picker on unsupported platforms (Windows/Linux)
abstract class PhotoPickerService {
  /// Query the gallery for photos and videos taken within a date range.
  ///
  /// [start] - Start of the date range (inclusive).
  /// [end] - End of the date range (inclusive).
  ///
  /// Returns a list of [AssetInfo] objects sorted by creation date (newest first).
  /// Returns an empty list if permission is denied or no assets match.
  Future<List<AssetInfo>> getAssetsInDateRange(DateTime start, DateTime end);

  /// Get a thumbnail image for an asset.
  ///
  /// [assetId] - Platform-specific asset identifier from [AssetInfo.id].
  /// [size] - Desired thumbnail size in pixels (width and height).
  ///
  /// Returns thumbnail bytes as JPEG, or null if the asset no longer exists.
  Future<Uint8List?> getThumbnail(String assetId, {int size = 200});

  /// Get the full-resolution file bytes for an asset.
  ///
  /// [assetId] - Platform-specific asset identifier from [AssetInfo.id].
  ///
  /// Returns file bytes, or null if the asset no longer exists.
  Future<Uint8List?> getFileBytes(String assetId);

  /// Check the current photo library permission status.
  Future<PhotoPermissionStatus> checkPermission();

  /// Request photo library permission from the user.
  ///
  /// Returns the new permission status after the request.
  Future<PhotoPermissionStatus> requestPermission();

  /// Whether this platform supports date-filtered gallery browsing.
  ///
  /// Returns true for iOS, Android, macOS (via photo_manager).
  /// Returns false for Windows, Linux (file picker only).
  bool get supportsGalleryBrowsing;

  /// Get the file path for an asset.
  ///
  /// [assetId] - Platform-specific asset identifier from [AssetInfo.id].
  ///
  /// This is needed for video playback, which requires a file path rather
  /// than raw bytes. Returns null if the asset no longer exists.
  Future<String?> getFilePath(String assetId);
}
