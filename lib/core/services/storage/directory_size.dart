import 'dart:io';

import 'package:path/path.dart' as p;

/// Recursively sums the bytes held by every file under [dir].
///
/// A directory that does not exist measures zero: that is a true measurement,
/// not a failure. A real I/O error (a permission denial, say) is allowed to
/// throw, because reporting a falsely low total is worse than showing the user
/// an error on the row that failed. A user who trusts a falsely low number acts
/// on it; a user who sees an error knows to look again.
Future<int> measureDirectoryBytes(Directory dir) async {
  if (!await dir.exists()) return 0;
  var total = 0;
  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      total += await entity.length();
    }
  }
  return total;
}

/// Sums a known set of files, skipping any that are absent.
///
/// Used for a database and its sidecars, where the `-wal` and `-shm` files
/// exist only while a connection is open.
Future<int> measureFileGroupBytes(Iterable<File> files) async {
  var total = 0;
  for (final file in files) {
    if (await file.exists()) {
      total += await file.length();
    }
  }
  return total;
}

/// Sums the files directly inside [dir], never descending into subdirectories,
/// skipping any whose basename [exclude] returns true for.
///
/// The Documents root needs this shape: exported files land loose at the top
/// level, while the database and the `Submersion/` subtree live alongside them
/// and must not be counted as exports.
Future<int> measureLooseFilesBytes(
  Directory dir, {
  required bool Function(String name) exclude,
}) async {
  if (!await dir.exists()) return 0;
  var total = 0;
  await for (final entity in dir.list(recursive: false, followLinks: false)) {
    if (entity is! File) continue;
    if (exclude(p.basename(entity.path))) continue;
    total += await entity.length();
  }
  return total;
}
