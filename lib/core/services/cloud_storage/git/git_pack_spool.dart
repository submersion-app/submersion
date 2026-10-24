import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';
import 'package:submersion/core/services/cloud_storage/git/pack_reader.dart';

final Random _random = Random();

/// Writes [pack] to a temporary file in [directory] as it arrives, then
/// reads it into [store] with [readPackFile]. A pack is checked against its
/// trailing checksum before any object is stored, so it is never parsed as
/// it streams; on disk, it is never held in memory either. The file is
/// deleted afterwards, whatever happens.
Future<List<GitObjectId>> readSpooledPack(
  Stream<List<int>> pack,
  GitObjectStore store, {
  required Directory directory,
  int inMemoryLimit = kGitInMemoryObjectLimit,
}) async {
  await directory.create(recursive: true);
  final file = File(
    p.join(
      directory.path,
      'submersion-${_random.nextInt(1 << 32).toRadixString(16)}.pack',
    ),
  );
  try {
    final sink = file.openWrite();
    try {
      // Paces the stream to the disk, so nothing piles up in between.
      await sink.addStream(pack);
    } catch (_) {
      try {
        await sink.close();
      } on Object {
        // The stream's own error is the one worth reporting.
      }
      rethrow;
    }
    await sink.close();
    return await readPackFile(file, store, inMemoryLimit: inMemoryLimit);
  } finally {
    try {
      await file.delete();
    } on FileSystemException {
      // Never created, or already gone.
    }
  }
}
