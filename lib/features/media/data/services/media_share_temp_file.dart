import 'dart:io';
import 'dart:typed_data';

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
Future<File> writeShareTempFile(MediaItem item, Uint8List bytes) async {
  final tempDir = await getTemporaryDirectory();
  final file = File('${tempDir.path}/${item.shareFilename}');
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
  return file;
}
