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
  while (await File(candidate).exists()) {
    candidate = p.join(directory, '$stem ($n)$extension');
    n++;
  }
  return candidate;
}
