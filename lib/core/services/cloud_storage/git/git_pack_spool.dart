import 'dart:io';
import 'dart:math';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';
import 'package:submersion/core/services/cloud_storage/git/pack_reader.dart';
import 'package:submersion/core/utils/off_isolate.dart';

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
///
/// Reading a pack is synchronous hashing and pure Dart inflate, so a large one
/// is read on another isolate when [store] is on disk, where that isolate can
/// reach it too; see [FileGitObjectStore.unindexed].
Future<List<GitObjectId>> readSpooledPack(
  Stream<List<int>> pack,
  GitObjectStore store, {
  Directory? directory,
  int inMemoryLimit = kGitInMemoryObjectLimit,
  @visibleForTesting
  int offIsolateMinBytes = kOffIsolateMinBytes ~/ kCompressedCostFactor,
  @visibleForTesting OffIsolateRunner offIsolateRunner = isolateRun,
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
    final length = await file.length();
    if (store is! FileGitObjectStore || length < offIsolateMinBytes) {
      return await readPackFile(file, store, inMemoryLimit: inMemoryLimit);
    }
    final ids = await _readPackOffIsolate(
      file.path,
      store.root.path,
      inMemoryLimit,
      length,
      offIsolateMinBytes,
      offIsolateRunner,
    );
    // Asking is what makes the owning store count an object it did not write.
    // Left until a session wants it, a fetch of a whole branch would sit
    // outside the store's bound until the next launch rescans.
    for (final id in ids) {
      await store.has(id);
    }
    return ids;
  } finally {
    try {
      await file.delete();
    } on FileSystemException {
      // Never created, or already gone.
    }
  }
}

Future<List<GitObjectId>> _readPackOffIsolate(
  String packPath,
  String storeRoot,
  int inMemoryLimit,
  int length,
  int minBytes,
  OffIsolateRunner runner,
) => runOffIsolate(
  () => readPackFile(
    File(packPath),
    FileGitObjectStore.unindexed(Directory(storeRoot)),
    inMemoryLimit: inMemoryLimit,
  ),
  bytes: length,
  minBytes: minBytes,
  // A bad pack is an answer. Anything else reruns on the same spooled file,
  // which is safe: objects are named by their content, so writing one twice
  // leaves one copy.
  isExpected: (e) => e is GitException,
  runner: runner,
);

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
