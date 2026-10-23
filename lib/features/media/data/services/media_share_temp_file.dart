import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Writes [bytes] to a temp file named after [item].shareFilename, suitable
/// for handing to the OS share sheet.
///
/// getTemporaryDirectory() returns where the OS expects the cache directory
/// to live, but does not guarantee it exists yet. On a long-used install the
/// directory is already present from other cache writes; on a fresh install
/// (or a fresh sandboxed container) it may not exist, and opening a file for
/// write inside a missing directory throws PathNotFoundException. See PR #555
/// for the same failure mode in the sync temp dir.
///
/// [filename] replaces the item's name, for a re-encoded copy (a colour-
/// corrected photo is always a JPEG, issue #3520).
Future<File> writeShareTempFile(
  MediaItem item,
  Uint8List bytes, {
  String? filename,
}) async {
  final tempDir = await getTemporaryDirectory();
  // One folder per item, so two shared items with the same name (photos
  // from two cameras, or a HEIC re-encoded as a .jpg beside a real .jpg)
  // never overwrite each other's file before the share sheet reads it.
  final file = File(
    p.join(tempDir.path, 'share', item.id, filename ?? item.shareFilename),
  );
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
  return file;
}

/// The share temp file [filename] in [item]'s own share folder, for an
/// encoder to write (a colour-corrected video copy, issue #3521). The
/// folder is created; the file is not.
Future<File> shareTempFileFor(
  MediaItem item, {
  required String filename,
}) async {
  final tempDir = await getTemporaryDirectory();
  final file = File(p.join(tempDir.path, 'share', item.id, filename));
  await file.parent.create(recursive: true);
  return file;
}
