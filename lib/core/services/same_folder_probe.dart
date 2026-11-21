import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// What [compareFolders] could establish about two folder paths.
enum FolderIdentity {
  /// The two paths name one folder.
  same,

  /// The two paths name different folders.
  different,

  /// The comparison could not be made: the marker could not be written or
  /// looked up, or the file system did not answer in time. The two paths may
  /// still be one folder, so nothing may open or copy a live database
  /// through the second path on this answer.
  unknown,
}

/// How long one file-system step of the probe may take before the answer is
/// [FolderIdentity.unknown]. A network share that has stopped answering is
/// the case this exists for (issue #4834).
const Duration folderProbeTimeout = Duration(seconds: 10);

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
/// written through [a] and opened through [b]. An open rather than an
/// existence query, because a Windows SMB client may answer the query from a
/// directory listing it cached seconds earlier (the folder picker has just
/// listed [b]), and that listing cannot hold a marker this new. The database
/// files are never touched. Each step is bounded by [timeout]. [create] and
/// [exists] are seams for tests.
Future<FolderIdentity> compareFolders(
  String a,
  String b, {
  Duration timeout = folderProbeTimeout,
  @visibleForTesting Future<void> Function(File marker)? create,
  @visibleForTesting Future<bool> Function(String path)? exists,
}) async {
  if (p.equals(a, b)) return FolderIdentity.same;

  final name = '.submersion-same-folder-${const Uuid().v4()}';
  final marker = File(p.join(a, name));
  final creating = create != null
      ? create(marker)
      : marker.create(exclusive: true);
  try {
    await creating.timeout(timeout);
  } on TimeoutException {
    // A create that lands after the deadline must not leave its marker.
    unawaited(
      creating.then((_) => _deleteQuietly(marker, timeout), onError: (_) {}),
    );
    return FolderIdentity.unknown;
  } on FileSystemException {
    return FolderIdentity.unknown;
  }

  try {
    final lookUp = exists ?? _opens;
    final found = await lookUp(p.join(b, name)).timeout(timeout);
    return found ? FolderIdentity.same : FolderIdentity.different;
  } on TimeoutException {
    return FolderIdentity.unknown;
  } on FileSystemException {
    return FolderIdentity.unknown;
  } finally {
    await _deleteQuietly(marker, timeout);
  }
}

/// Whether the file at [path] can be opened: false when it is not there,
/// and a [FileSystemException] for any other failure, such as a folder that
/// cannot be read, since that says nothing about which folder it is.
Future<bool> _opens(String path) async {
  try {
    await (await File(path).open()).close();
    return true;
  } on PathNotFoundException {
    return false;
  }
}

/// Best effort: a stray empty marker is harmless, a probe that throws or
/// hangs is not.
Future<void> _deleteQuietly(File marker, Duration timeout) async {
  try {
    await marker.delete().timeout(timeout);
  } on Exception {
    // Left behind; see above.
  }
}
