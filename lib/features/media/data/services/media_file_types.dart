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
/// Top-level so it can run on a `compute` isolate.
Future<List<String>> scanFolderForMediaFiles(String rootPath) async {
  final results = <String>[];
  final dir = Directory(rootPath);
  if (!dir.existsSync()) return results;
  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File && isLinkableMediaPath(entity.path)) {
      results.add(entity.path);
      if (results.length >= maxScannedMediaFiles) break;
    }
  }
  results.sort();
  return results;
}
