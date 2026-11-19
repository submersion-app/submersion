import 'dart:io';

import 'package:submersion/features/media/domain/entities/media_item.dart';

/// How many of [items] have no readable file on this device, so a Find
/// species run would have to download them (issue #4727). A cheap look at
/// the media rows, not a network call, so photo library items stored only
/// in the cloud can be counted as present: the count is approximate.
int notOnDeviceCount(
  List<MediaItem> items, {
  bool Function(String path)? fileExists,
}) {
  final exists = fileExists ?? (path) => File(path).existsSync();
  var missing = 0;
  for (final item in items) {
    if (item.platformAssetId != null) continue;
    final path = item.localPath;
    if (path == null || path.isEmpty || !exists(path)) missing++;
  }
  return missing;
}
