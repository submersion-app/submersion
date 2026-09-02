import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/media/data/services/image_dimensions_reader.dart';
import 'package:submersion/features/media/data/services/local_media_metadata.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_metadata.dart';

/// Photo picker implementation for Windows and Linux using image_picker.
///
/// This is a fallback implementation that doesn't support date-filtered
/// gallery browsing. Users must manually browse and select files.
///
/// Windows and Linux have no platform photo library, so every [AssetInfo]
/// this service produces carries its [AssetInfo.filePath]. That path is the
/// only durable pointer to the file: [AssetInfo.id] is a synthetic key into
/// [_filePathCache], which lives and dies with the process. Importers must
/// persist the path (as a `localFile` row) rather than the id, or the photo
/// resolves through photo_manager -- which has no Windows backend -- and
/// renders "File not found".
class PhotoPickerServiceDesktop implements PhotoPickerService {
  final ImagePicker _picker = ImagePicker();

  /// Cache of selected file paths keyed by a generated ID.
  final Map<String, String> _filePathCache = {};

  @override
  bool get supportsGalleryBrowsing => false;

  @override
  Future<PhotoPermissionStatus> checkPermission() async {
    // Desktop platforms don't require explicit permission for file access
    return PhotoPermissionStatus.authorized;
  }

  @override
  Future<PhotoPermissionStatus> requestPermission() async {
    // Desktop platforms don't require explicit permission for file access
    return PhotoPermissionStatus.authorized;
  }

  @override
  Future<List<AssetInfo>> getAssetsInDateRange(
    DateTime start,
    DateTime end,
  ) async {
    // Desktop doesn't support date-filtered gallery browsing.
    // Instead, open a multi-file picker dialog.
    final files = await _picker.pickMultipleMedia();

    if (files.isEmpty) {
      return [];
    }

    // Reading the capture time still means reading each file's bytes -- a
    // JPEG's EXIF comes out of a full-file parse -- which would jank the UI
    // thread for a pick of large photos (the old stat()-only implementation
    // was cheap enough to inline). Do the batch on a background isolate, then
    // register the paths here -- the isolate only ever mutates its own copy
    // of [_filePathCache].
    final assets = await compute(
      _extractAssets,
      files.map((f) => f.path).toList(),
    );
    for (final asset in assets) {
      final path = asset.filePath;
      if (path != null) _filePathCache[asset.id] = path;
    }
    return assets;
  }

  /// Builds the [AssetInfo] for one file chosen from the desktop file dialog
  /// and registers its path under the returned [AssetInfo.id].
  ///
  /// Returns null when [ioFile] does not exist.
  ///
  /// The capture time and the position both come from the file's own
  /// container metadata, read in one pass by [readLocalMediaMetadata]: EXIF
  /// `DateTimeOriginal` and the GPS IFD for stills, the `mvhd` creation time
  /// and the QuickTime location atom (or GoPro telemetry) for video. The
  /// capture time falls back to the mtime only when the file carries none at
  /// all. Reporting the mtime unconditionally --
  /// as this service used to -- dates a photo to when it was copied off the
  /// camera card rather than when it was shot, which pushes it outside the
  /// dive window and leaves it unmatched.
  ///
  /// That capture time is wall-clock-UTC, but [AssetInfo] is
  /// contractually LOCAL (photo_manager's convention on mobile, which
  /// consumers such as `TripMediaScanner.toWallClockUtc` reinterpret). The
  /// components are therefore carried across verbatim into a local DateTime;
  /// returning the UTC value directly would double-convert it.
  AssetInfo? assetInfoForFile(File ioFile) {
    final asset = _assetInfoForPath(ioFile.path);
    if (asset != null) _filePathCache[asset.id] = asset.filePath!;
    return asset;
  }

  @override
  Future<Uint8List?> getThumbnail(String assetId, {int size = 200}) async {
    final path = _filePathCache[assetId];
    if (path == null) return null;

    final file = File(path);
    if (!await file.exists()) return null;

    // For desktop, just return the full file bytes
    // (thumbnail generation would require additional dependencies)
    return file.readAsBytes();
  }

  @override
  Future<Uint8List?> getFileBytes(String assetId) async {
    final path = _filePathCache[assetId];
    if (path == null) return null;

    final file = File(path);
    if (!await file.exists()) return null;

    return file.readAsBytes();
  }

  @override
  Future<String?> getFilePath(String assetId) async {
    final path = _filePathCache[assetId];
    if (path == null) return null;

    final file = File(path);
    if (!await file.exists()) return null;

    return path;
  }

  @override
  Future<MediaSourceMetadata?> getAssetMetadata(String assetId) async => null;
}

/// Batch entry point for [compute]: top-level so it can cross the isolate
/// boundary (an instance method would close over `this`). Paths that no
/// longer resolve are dropped.
List<AssetInfo> _extractAssets(List<String> paths) {
  final results = <AssetInfo>[];
  for (final path in paths) {
    final asset = _assetInfoForPath(path);
    // Null means the picked path vanished between dialog and read.
    if (asset != null) results.add(asset);
  }
  return results;
}

/// Pure metadata read for one path. Top-level and cache-free so it is safe to
/// run on a [compute] isolate; [PhotoPickerServiceDesktop.assetInfoForFile]
/// wraps it to register the path on the main isolate.
AssetInfo? _assetInfoForPath(String path) {
  final ioFile = File(path);
  if (!ioFile.existsSync()) return null;

  final modified = ioFile.lastModifiedSync();
  final mime = _mimeFromExtension(p.extension(path).toLowerCase());

  // One read for both answers: a still's EXIF block is parsed once and
  // serves the capture time and the position together.
  final meta = readLocalMediaMetadata(ioFile, mime);
  final capturedUtc = meta.capturedUtc;
  final createDateTime = capturedUtc == null
      ? modified
      : DateTime(
          capturedUtc.year,
          capturedUtc.month,
          capturedUtc.day,
          capturedUtc.hour,
          capturedUtc.minute,
          capturedUtc.second,
          capturedUtc.millisecond,
          // Today's readers are all second-granularity (EXIF
          // DateTimeOriginal, mvhd creation_time), so this is defensive --
          // but dropping sub-second components on a reinterpretation that
          // exists only to swap the isUtc flag would be a silent lossy step.
          capturedUtc.microsecond,
        );

  final size = readImageDimensions(ioFile, mime);

  return AssetInfo(
    // Keyed on mtime + path so re-picking the same file in one session reuses
    // the entry. Only meaningful in-process; the durable pointer is the path.
    id: '${modified.millisecondsSinceEpoch}_${path.hashCode}',
    type: mime.startsWith('video/') ? AssetType.video : AssetType.image,
    createDateTime: createDateTime,
    // AssetResolutionService's timestamp+dimensions tiers reject a 0x0 row
    // outright, so real dimensions are what keep those tiers usable.
    width: size?.width ?? 0,
    height: size?.height ?? 0,
    durationSeconds: null,
    latitude: meta.fix?.latitude,
    longitude: meta.fix?.longitude,
    filename: p.basename(path),
    filePath: path,
  );
}

String _mimeFromExtension(String ext) => switch (ext) {
  '.jpg' || '.jpeg' => 'image/jpeg',
  '.png' => 'image/png',
  '.heic' => 'image/heic',
  '.heif' => 'image/heif',
  '.webp' => 'image/webp',
  '.gif' => 'image/gif',
  '.mp4' => 'video/mp4',
  '.mov' => 'video/quicktime',
  '.m4v' => 'video/x-m4v',
  '.avi' || '.mkv' || '.webm' => 'video/x-generic',
  _ => 'application/octet-stream',
};
