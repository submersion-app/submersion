import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';

/// A Git object's id, type and raw body (no loose-object header).
final class GitStoredObject {
  const GitStoredObject({
    required this.id,
    required this.type,
    required this.body,
  });

  final GitObjectId id;
  final GitObjectType type;
  final Uint8List body;
}

/// Where fetched and created objects live. Objects are immutable and
/// addressed by content, so a store never needs invalidating, only bounding.
abstract interface class GitObjectStore {
  Future<GitStoredObject?> get(GitObjectId id);

  /// Stores [object]. Never evicts anything, so a caller can read back what
  /// it just fetched; [trim] does that.
  Future<void> put(GitStoredObject object);
  Future<bool> has(GitObjectId id);

  /// Deletes the least recently used objects until the store is within its
  /// bound, never one [keep] returns; [keep] is asked only when something
  /// must go. A no-op for an unbounded store.
  Future<void> trim({Future<Set<GitObjectId>> Function()? keep});
}

/// An unbounded in-memory store, for tests and short-lived sessions.
final class MemoryGitObjectStore implements GitObjectStore {
  final Map<GitObjectId, GitStoredObject> _objects = {};

  @override
  Future<GitStoredObject?> get(GitObjectId id) async => _objects[id];

  @override
  Future<void> put(GitStoredObject object) async =>
      _objects[object.id] = object;

  @override
  Future<bool> has(GitObjectId id) async => _objects.containsKey(id);

  @override
  Future<void> trim({Future<Set<GitObjectId>> Function()? keep}) async {}
}

/// A size-bounded on-disk store: one file per object at
/// `<root>/<first two hex digits>/<other 38>`, holding a 1-byte pack type
/// code followed by the body. [trim] deletes the least recently used
/// objects above [maxBytes]. Recency lives in memory, seeded from file
/// modification times the first time the store is used.
///
/// Stores on one directory share its files but not their bookkeeping: an
/// object another store evicted reads as missing and is fetched again, and
/// one another store wrote is adopted when first asked for. Use
/// [FileGitObjectStore.shared] so that, within an isolate, there is only one.
final class FileGitObjectStore implements GitObjectStore {
  FileGitObjectStore(this.root, {this.maxBytes = _defaultMaxBytes});

  /// The store for [root] in this isolate, made on first use. Each store
  /// scans its whole directory once, which takes seconds on a full cache, and
  /// keeps its own index; sharing one does both once and keeps eviction in
  /// step. Every caller for one directory must ask for the same [maxBytes];
  /// a different one is an [ArgumentError].
  factory FileGitObjectStore.shared(
    Directory root, {
    int maxBytes = _defaultMaxBytes,
  }) {
    final store = _shared.putIfAbsent(
      p.canonicalize(root.path),
      () => FileGitObjectStore(root, maxBytes: maxBytes),
    );
    if (store.maxBytes != maxBytes) {
      throw ArgumentError.value(
        maxBytes,
        'maxBytes',
        'the shared store for ${root.path} is bounded at ${store.maxBytes}',
      );
    }
    return store;
  }

  static final Map<String, FileGitObjectStore> _shared = {};

  static const int _defaultMaxBytes = 256 * 1024 * 1024;
  static const String _tmpSuffix = '.tmp';
  static const Duration _staleTmpAge = Duration(hours: 1);
  static final Random _random = Random();

  final Directory root;
  final int maxBytes;

  /// path -> (size, recency); larger recency is more recently used.
  Future<Map<String, ({int size, int recency})>>? _index;
  int _clock = 0;
  int _total = 0;

  File _fileFor(GitObjectId id) {
    final hex = id.hex;
    return File(p.join(root.path, hex.substring(0, 2), hex.substring(2)));
  }

  /// Scans the directory once, however many callers arrive first.
  Future<Map<String, ({int size, int recency})>> _ensureIndex() =>
      _index ??= _scan();

  Future<Map<String, ({int size, int recency})>> _scan() async {
    final found = <({String path, int size, DateTime modified})>[];
    if (await root.exists()) {
      await for (final entity in root.list(recursive: true)) {
        if (entity is! File) continue;
        final stat = await entity.stat();
        if (entity.path.endsWith(_tmpSuffix)) {
          // An old one is a write cut short by a crash (the object is
          // fetched again); a recent one may be another store's on this
          // directory, still being written.
          final age = DateTime.now().difference(stat.modified);
          if (age > _staleTmpAge) {
            await entity.delete().catchError((_) => entity);
          }
          continue;
        }
        found.add((
          path: entity.path,
          size: stat.size,
          modified: stat.modified,
        ));
      }
    }
    found.sort((a, b) => a.modified.compareTo(b.modified));
    final index = <String, ({int size, int recency})>{};
    for (final f in found) {
      index[f.path] = (size: f.size, recency: ++_clock);
      _total += f.size;
    }
    return index;
  }

  /// [file]'s entry, adopting it when another store on this directory wrote
  /// it after the scan. A miss here is followed by a fetch, so the extra stat
  /// costs nothing next to it.
  Future<({int size, int recency})?> _entryFor(
    Map<String, ({int size, int recency})> index,
    File file,
  ) async {
    final known = index[file.path];
    if (known != null) return known;
    // A missing file stats as notFound rather than throwing.
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file || stat.size == 0) return null;
    // A concurrent caller may have adopted or put it during the stat.
    final raced = index[file.path];
    if (raced != null) return raced;
    final entry = (size: stat.size, recency: ++_clock);
    index[file.path] = entry;
    _total += stat.size;
    return entry;
  }

  /// Drops [path] from the index. A no-op when a concurrent caller already
  /// did, so its size is never subtracted twice.
  void _forget(Map<String, ({int size, int recency})> index, String path) {
    final gone = index.remove(path);
    if (gone != null) _total -= gone.size;
  }

  @override
  Future<GitStoredObject?> get(GitObjectId id) async {
    final index = await _ensureIndex();
    final file = _fileFor(id);
    if (await _entryFor(index, file) == null) return null;
    Uint8List? bytes;
    try {
      bytes = await file.readAsBytes();
    } on FileSystemException {
      bytes = null;
    }
    // Gone, or emptied by a crash: forgotten, so the next read fetches it.
    if (bytes == null || bytes.isEmpty) {
      _forget(index, file.path);
      return null;
    }
    // Unless a trim dropped it during the read: it is gone from disk.
    final current = index[file.path];
    if (current != null) {
      index[file.path] = (size: current.size, recency: ++_clock);
    }
    return GitStoredObject(
      id: id,
      type: GitObjectType.fromPackCode(bytes[0]),
      body: Uint8List.sublistView(bytes, 1),
    );
  }

  @override
  Future<void> put(GitStoredObject object) async {
    final index = await _ensureIndex();
    final file = _fileFor(object.id);
    // Already here, perhaps written by another store on this directory; that
    // store may also have deleted one this index still lists.
    if (await _entryFor(index, file) != null && await file.exists()) return;
    await file.parent.create(recursive: true);
    // A name of its own: two puts of one object may run at once.
    final tmp = File(
      '${file.path}.${_random.nextInt(1 << 32).toRadixString(16)}$_tmpSuffix',
    );
    // Header byte and body as one buffer: a List<int> spread would cost
    // about eight bytes per body byte.
    final bytes = Uint8List(object.body.length + 1)
      ..[0] = object.type.packCode
      ..setRange(1, object.body.length + 1, object.body);
    await tmp.writeAsBytes(bytes, flush: true);
    try {
      await tmp.rename(file.path);
    } on FileSystemException {
      // Another concurrent put may have landed the same object first.
      if (await file.exists()) {
        await tmp.delete().catchError((_) => tmp);
      } else {
        rethrow;
      }
    }
    // A concurrent put of the same object has counted it already.
    if (index.containsKey(file.path)) return;
    final size = object.body.length + 1;
    index[file.path] = (size: size, recency: ++_clock);
    _total += size;
  }

  @override
  Future<void> trim({Future<Set<GitObjectId>> Function()? keep}) async {
    final index = await _ensureIndex();
    if (_total <= maxBytes) return;
    final kept = {
      for (final id in await keep?.call() ?? const <GitObjectId>{})
        _fileFor(id).path,
    };
    final byAge = index.entries.where((e) => !kept.contains(e.key)).toList()
      ..sort((a, b) => a.value.recency.compareTo(b.value.recency));
    for (final victim in byAge) {
      if (_total <= maxBytes) break;
      try {
        await File(victim.key).delete();
      } on FileSystemException {
        // Already gone; only the bookkeeping is left to drop.
      }
      _forget(index, victim.key);
    }
  }

  @override
  Future<bool> has(GitObjectId id) async {
    final index = await _ensureIndex();
    final file = _fileFor(id);
    if (await _entryFor(index, file) == null) return false;
    // Another store on this directory may have evicted it: say so now, so
    // the caller fetches it rather than failing on the read.
    if (await file.exists()) return true;
    _forget(index, file.path);
    return false;
  }
}
