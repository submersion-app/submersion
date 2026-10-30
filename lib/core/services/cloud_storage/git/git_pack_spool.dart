import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';
import 'package:submersion/core/services/cloud_storage/git/pack_reader.dart';

final Random _random = Random();

const String _prefix = 'submersion-';
const String _suffix = '.pack';

/// How old a spooled pack must be before it counts as left by a download
/// the app was killed during, rather than one still running.
const Duration _staleAge = Duration(hours: 1);

/// Where packs are spooled unless told otherwise: a folder of their own, so
/// clearing stale ones never lists the rest of the temp directory.
Directory get defaultGitSpoolDirectory =>
    Directory(p.join(Directory.systemTemp.path, 'submersion_git_packs'));

/// Writes [pack] to a temporary file in [directory] (by default
/// [defaultGitSpoolDirectory]) as it arrives, then
/// reads it into [store] with [readPackFile]. A pack is checked against its
/// trailing checksum before any object is stored, so it is never parsed as
/// it streams; on disk, it is never held in memory either. The file is
/// deleted afterwards, whatever happens short of the app being killed; packs
/// such a kill left behind are cleared on a later download.
Future<List<GitObjectId>> readSpooledPack(
  Stream<List<int>> pack,
  GitObjectStore store, {
  Directory? directory,
  int inMemoryLimit = kGitInMemoryObjectLimit,
}) async {
  final dir = directory ?? defaultGitSpoolDirectory;
  await dir.create(recursive: true);
  await _clearStale(dir);
  final file = File(
    p.join(
      dir.path,
      '$_prefix${_random.nextInt(1 << 32).toRadixString(16)}$_suffix',
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

/// Deletes spooled packs older than [_staleAge] in [directory].
Future<void> _clearStale(Directory directory) async {
  final now = DateTime.now();
  try {
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.startsWith(_prefix) || !name.endsWith(_suffix)) continue;
      try {
        final modified = await entity.lastModified();
        if (now.difference(modified) > _staleAge) await entity.delete();
      } on FileSystemException {
        // Gone already, or another download's; either way not ours to fix.
      }
    }
  } on FileSystemException {
    // An unreadable temp directory only costs the cleanup.
  }
}
