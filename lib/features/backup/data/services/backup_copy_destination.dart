import 'dart:io';

import 'package:path/path.dart' as p;

/// Where a backup copy saved into [directory] lands: [fileName] when the
/// folder has no file of that name, else `name (1).ext`, `name (2).ext` and
/// so on. A save never overwrites, because the folder the diver picks may be
/// the one that holds the very backup being copied (issue #3650).
Future<String> uniqueDestinationPath(String directory, String fileName) async {
  final stem = p.basenameWithoutExtension(fileName);
  final extension = p.extension(fileName);
  var candidate = p.join(directory, fileName);
  var n = 1;
  // Any entry holds the name, a folder or a link included.
  while (await FileSystemEntity.type(candidate, followLinks: false) !=
      FileSystemEntityType.notFound) {
    candidate = p.join(directory, '$stem ($n)$extension');
    n++;
  }
  return candidate;
}

/// Copies [source] to [dest] through a `.partial` file next to it, moved
/// into place only once complete. A copy that fails part way removes its
/// partial file, so the diver's folder never holds a truncated file named
/// like a real backup.
Future<void> copyWithoutPartial(String source, String dest) async {
  final partial = File('$dest.partial');
  try {
    await File(source).copy(partial.path);
    await partial.rename(dest);
  } catch (_) {
    try {
      if (await partial.exists()) await partial.delete();
    } catch (_) {
      // best-effort cleanup
    }
    rethrow;
  }
}
