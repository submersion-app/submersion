import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'package:submersion/features/media/data/services/photo_picker_service.dart';

/// Photo picker implementation for Windows and Linux using image_picker.
///
/// This is a fallback implementation that doesn't support date-filtered
/// gallery browsing. Users must manually browse and select files.
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

    final List<AssetInfo> results = [];

    for (final file in files) {
      final path = file.path;
      final ioFile = File(path);

      // Check if file exists
      if (!await ioFile.exists()) continue;

      // Get file metadata
      final stat = await ioFile.stat();
      final modified = stat.modified;

      // Generate a unique ID for this file
      final id = '${modified.millisecondsSinceEpoch}_${path.hashCode}';
      _filePathCache[id] = path;

      // Determine if it's a video based on extension
      final extension = path.toLowerCase().split('.').last;
      final isVideo = ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(extension);

      results.add(
        AssetInfo(
          id: id,
          type: isVideo ? AssetType.video : AssetType.image,
          createDateTime: modified,
          width: 0, // Not available without decoding
          height: 0,
          durationSeconds: null,
          latitude: null,
          longitude: null,
          filename: path.split(Platform.pathSeparator).last,
        ),
      );
    }

    return results;
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
}
