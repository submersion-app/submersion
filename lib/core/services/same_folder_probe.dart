import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Whether [a] and [b] name the same folder, however each one is spelled.
///
/// Comparing the strings misses every other name a folder can have: a NAS
/// reached through a second server name, a mapped drive letter and its UNC
/// path, a symlink, another letter case on a case-insensitive volume. Taking
/// such a pair for two folders opens the live dive log a second time under
/// the other name, which on a Windows network share hung the app in the
/// kernel, past even Task Manager (issue #4834).
///
/// So the folders are compared by what they hold: a uniquely named marker is
/// written through [a] and looked for through [b]. The database files are
/// never touched. When [a] cannot be written or [b] cannot be read the answer
/// is false, the same one the string comparison gave.
Future<bool> isSameFolder(String a, String b) async {
  if (p.equals(a, b)) return true;

  final name = '.submersion-same-folder-${const Uuid().v4()}';
  final marker = File(p.join(a, name));
  try {
    await marker.create(exclusive: true);
  } on FileSystemException {
    return false;
  }
  try {
    return await File(p.join(b, name)).exists();
  } on FileSystemException {
    return false;
  } finally {
    try {
      await marker.delete();
    } on FileSystemException {
      // Best effort: a stray empty marker is harmless, a thrown probe is not.
    }
  }
}
