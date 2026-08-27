import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A picked file that is guaranteed to exist on local disk.
///
/// [uri] is the picker's original handle. It is the SAF `content://` URI on
/// Android and a `file:` URI elsewhere, which is what the document import
/// service needs to take a persistable permission (issue #1002).
typedef LocalPickedFile = ({String path, String name, Uri uri});

/// Resolves [files] to local paths, copying in any that have none.
///
/// file_picker 12 hands back a handle whose `path` is null unless its Uri
/// scheme is `file`, so an Android SAF `content://` pick has no local path at
/// all. Every ingest path in this app is path-based, so silently skipping
/// those would shrink the user's selection without telling them: the import
/// wizard would report "no importable files" and the document attach would
/// appear to do nothing, both for a selection the user made correctly.
///
/// Handles without a path are streamed into the temp directory rather than
/// read whole, so a large picked archive does not have to fit in memory.
///
/// Throws [PickedFileMaterializationException] if a handle cannot be read, so
/// the caller can surface a real error instead of an empty result.
Future<List<LocalPickedFile>> materializePickedFiles(
  List<PlatformFile> files,
) async {
  if (files.isEmpty) return const [];

  Directory? scratch;
  final out = <LocalPickedFile>[];

  for (final file in files) {
    final local = file.path;
    if (local != null) {
      out.add((path: local, name: file.name, uri: file.uri));
      continue;
    }

    // No local path: this is a content:// (or blob/data) handle.
    scratch ??= Directory(
      p.join((await getTemporaryDirectory()).path, 'picked'),
    );
    await scratch.create(recursive: true);

    // Name collisions are real here: two SAF picks from different folders can
    // share a display name, so give each its own subdirectory.
    final dir = Directory(p.join(scratch.path, '${out.length}'));
    await dir.create(recursive: true);
    final dest = File(p.join(dir.path, file.name));

    try {
      final sink = dest.openWrite();
      try {
        await sink.addStream(file.readAsByteStream());
      } finally {
        await sink.close();
      }
    } on Object catch (e) {
      throw PickedFileMaterializationException(file.name, e);
    }

    out.add((path: dest.path, name: file.name, uri: file.uri));
  }

  return out;
}

/// A picked file could not be copied out of its handle.
class PickedFileMaterializationException implements Exception {
  const PickedFileMaterializationException(this.fileName, this.cause);

  final String fileName;
  final Object cause;

  @override
  String toString() => 'Could not read the selected file "$fileName": $cause';
}
