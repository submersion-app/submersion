import 'dart:io';

import 'package:path/path.dart' as p;

/// File extensions the media importer links as photos or videos.
///
/// Images plus the video containers whose `mvhd` creation time the
/// capture-time reader understands, so every file admitted here can be
/// matched to a dive by date.
const linkableMediaExtensions = {
  '.jpg',
  '.jpeg',
  '.heic',
  '.heif',
  '.png',
  '.webp',
  '.gif',
  '.mp4',
  '.mov',
  '.m4v',
};

/// Upper bound on the files one folder scan returns, to bound memory and the
/// metadata read that follows.
const maxScannedMediaFiles = 5000;

/// Whether [path] names a photo or video the media importer can link.
bool isLinkableMediaPath(String path) =>
    linkableMediaExtensions.contains(p.extension(path).toLowerCase());

/// Recursively lists the photos and videos under [rootPath], sorted, up to
/// [maxScannedMediaFiles]. A folder that does not exist yields nothing.
///
/// Hidden files and folders are skipped, the way the dive-log folder scan
/// skips them. Camera cards formatted exFAT and read on macOS carry an
/// AppleDouble `._<name>.jpg` beside every photo: the photo's extension but
/// no image, so it would otherwise be staged as a junk photo dated by its
/// mtime. The test is on the path below [rootPath], so a root that is itself
/// inside a hidden folder still scans.
///
/// Top-level so it can run on a `compute` isolate.
Future<List<String>> scanFolderForMediaFiles(String rootPath) async {
  final results = <String>[];
  final dir = Directory(rootPath);
  if (!dir.existsSync()) return results;
  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is! File || !isLinkableMediaPath(entity.path)) continue;
    final relative = p.split(p.relative(entity.path, from: rootPath));
    if (relative.any((segment) => segment.startsWith('.'))) continue;
    results.add(entity.path);
    if (results.length >= maxScannedMediaFiles) break;
  }
  results.sort();
  return results;
}
