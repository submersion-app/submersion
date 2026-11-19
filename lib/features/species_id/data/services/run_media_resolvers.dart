import 'dart:io';

import 'package:submersion/features/media/domain/entities/media_item.dart';

/// How many of [items] have no original on this device, so a Find species
/// run would have to download them (issue #4727): a file it names that is
/// missing, or a photo library item whose original the library holds only
/// in iCloud ([libraryOriginalHere] says no). Media in [checked] (looked at
/// already with the installed model) is left out: the run does not open it
/// again.
Future<int> notOnDeviceCount(
  List<MediaItem> items, {
  required Future<bool> Function(MediaItem item) libraryOriginalHere,
  bool Function(String path)? fileExists,
  Set<String> checked = const {},
}) async {
  final exists = fileExists ?? (path) => File(path).existsSync();
  var missing = 0;
  for (final item in items) {
    if (checked.contains(item.id)) continue;
    if (item.platformAssetId != null) {
      if (!await libraryOriginalHere(item)) missing++;
      continue;
    }
    final path = item.localPath;
    if (path == null || path.isEmpty || !exists(path)) missing++;
  }
  return missing;
}
