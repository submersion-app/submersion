import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:meta/meta.dart';
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

/// A stored object's body read in pieces, for one too large to hold whole.
/// The caller closes it. One read at a time: [readSync] and a stream from
/// [openRead] share a file position, so they must not be interleaved.
abstract interface class GitObjectReader {
  GitObjectType get type;

  /// The body length.
  int get length;

  /// Up to [count] bytes from [offset]: fewer only at the end of the body.
  /// Synchronous, for the synchronous delta loop that copies from a base.
  Uint8List readSync(int offset, int count);

  /// The whole body, read as it is consumed.
  Stream<List<int>> openRead();

  Future<void> close();
}

/// Writes one object in pieces. Its id is the hash of what was written, so
/// it is known only once [close] has it all.
abstract interface class GitObjectWriter {
  /// Synchronous, so it can sit inside the synchronous inflate loop without
  /// bytes piling up in a buffer behind it.
  void add(List<int> chunk);

  /// Stores the object and returns its id. Throws [FormatException], and
  /// stores nothing, when the bytes added are not the size declared.
  Future<GitObjectId> close();

  /// Drops what was written.
  Future<void> abort();
}

/// Where fetched and created objects live. Objects are immutable and
/// addressed by content, so a store never needs invalidating, only bounding.
abstract interface class GitObjectStore {
  Future<GitStoredObject?> get(GitObjectId id);

  /// Stores [object]. Never evicts anything, so a caller can read back what
  /// it just fetched; [trim] does that.
  Future<void> put(GitStoredObject object);
  Future<bool> has(GitObjectId id);

  /// [id]'s body to read in pieces, or null when it is not here.
  Future<GitObjectReader?> open(GitObjectId id);

  /// A writer for an object of [type] whose body is [size] bytes. Like
  /// [put], what it stores is never evicted until [trim].
  GitObjectWriter create(GitObjectType type, int size);

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
  Future<GitObjectReader?> open(GitObjectId id) async {
    final object = _objects[id];
    return object == null ? null : _MemoryObjectReader(object);
  }

  @override
  GitObjectWriter create(GitObjectType type, int size) =>
      _MemoryObjectWriter(this, type, size);

  @override
  Future<void> trim({Future<Set<GitObjectId>> Function()? keep}) async {}
}

final class _MemoryObjectReader implements GitObjectReader {
  _MemoryObjectReader(this._object);

  final GitStoredObject _object;

  @override
  GitObjectType get type => _object.type;

  @override
  int get length => _object.body.length;

  @override
  Uint8List readSync(int offset, int count) => Uint8List.sublistView(
    _object.body,
    offset,
    min(offset + count, _object.body.length),
  );

  @override
  Stream<List<int>> openRead() => Stream.value(_object.body);

  @override
  Future<void> close() async {}
}

final class _MemoryObjectWriter implements GitObjectWriter {
  _MemoryObjectWriter(this._store, this._type, int size)
    : _hasher = GitObjectHasher(_type, size);

  final MemoryGitObjectStore _store;
  final GitObjectType _type;
  final GitObjectHasher _hasher;
  // Copies: a caller may reuse the buffer it hands to add.
  final BytesBuilder _body = BytesBuilder();

  @override
  void add(List<int> chunk) {
    _hasher.add(chunk);
    _body.add(chunk);
  }

  @override
  Future<GitObjectId> close() async {
    final id = _hasher.close();
    await _store.put(
      GitStoredObject(id: id, type: _type, body: _body.takeBytes()),
    );
    return id;
  }

  @override
  Future<void> abort() async => _body.clear();
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

  /// Test seam: replaces [File.rename] when an object file moves into place,
  /// so a test can lose the race to a concurrent put on purpose. Production
  /// leaves this null.
  @visibleForTesting
  static Future<File> Function(File source, String path)? debugRename;

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

  /// Whether [file] is here already, perhaps written by another store on this
  /// directory; that store may also have deleted one this index still lists.
  Future<bool> _present(
    Map<String, ({int size, int recency})> index,
    File file,
  ) async => await _entryFor(index, file) != null && await file.exists();

  /// Counts [file], just renamed into place, unless a concurrent put of the
  /// same object has counted it already.
  void _record(
    Map<String, ({int size, int recency})> index,
    File file,
    int size,
  ) {
    if (index.containsKey(file.path)) return;
    index[file.path] = (size: size, recency: ++_clock);
    _total += size;
  }

  /// A temp file name of its own: two writes of one object may run at once.
  String _tmpName(String stem) =>
      '$stem.${_random.nextInt(1 << 32).toRadixString(16)}$_tmpSuffix';

  @override
  Future<void> put(GitStoredObject object) async {
    final index = await _ensureIndex();
    final file = _fileFor(object.id);
    if (await _present(index, file)) return;
    await file.parent.create(recursive: true);
    final tmp = File(_tmpName(file.path));
    // Header byte and body as one buffer: a List<int> spread would cost
    // about eight bytes per body byte.
    final bytes = Uint8List(object.body.length + 1)
      ..[0] = object.type.packCode
      ..setRange(1, object.body.length + 1, object.body);
    await tmp.writeAsBytes(bytes, flush: true);
    await _moveIntoPlace(tmp, file);
    _record(index, file, bytes.length);
  }

  /// Renames [tmp] onto [file]. A failed rename is a lost race, not an error,
  /// when [file] is there afterwards: another put of the same object landed
  /// first, and objects are named by their content, so its copy is ours.
  Future<void> _moveIntoPlace(File tmp, File file) async {
    try {
      await (debugRename ?? (source, path) => source.rename(path))(
        tmp,
        file.path,
      );
    } on FileSystemException {
      if (!await file.exists()) rethrow;
      // Best effort: a stray temp file is swept by the next scan.
      await tmp.delete().catchError((_) => tmp);
    }
  }

  /// Moves [tmp], a finished object file for [id] of [size] bytes, into
  /// place, or deletes it when the object is already here.
  Future<void> _adopt(GitObjectId id, File tmp, int size) async {
    final index = await _ensureIndex();
    final file = _fileFor(id);
    if (await _present(index, file)) {
      await tmp.delete();
      return;
    }
    await file.parent.create(recursive: true);
    await _moveIntoPlace(tmp, file);
    _record(index, file, size);
  }

  @override
  GitObjectWriter create(GitObjectType type, int size) {
    root.createSync(recursive: true);
    // In the root, so it is on the same disk as where it ends up and the
    // move into place is a rename; the id, and so the folder, comes last.
    final tmp = File(_tmpName(p.join(root.path, 'incoming')));
    return _FileObjectWriter(this, tmp, type, size);
  }

  @override
  Future<GitObjectReader?> open(GitObjectId id) async {
    final index = await _ensureIndex();
    final file = _fileFor(id);
    if (await _entryFor(index, file) == null) return null;
    final RandomAccessFile raf;
    try {
      raf = await file.open();
    } on FileSystemException {
      _forget(index, file.path);
      return null;
    }
    final int length;
    final GitObjectType type;
    try {
      length = await raf.length();
      // Emptied by a crash: forgotten, so the next read fetches it.
      if (length == 0) {
        await raf.close();
        _forget(index, file.path);
        return null;
      }
      type = GitObjectType.fromPackCode((await raf.read(1))[0]);
    } catch (_) {
      await raf.close();
      rethrow;
    }
    final current = index[file.path];
    if (current != null) {
      index[file.path] = (size: current.size, recency: ++_clock);
    }
    return _FileObjectReader(raf, type, length - 1);
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

/// Reads through one open handle, so an object trimmed while it is read
/// stays readable where the platform allows deleting an open file.
final class _FileObjectReader implements GitObjectReader {
  _FileObjectReader(this._raf, this.type, this.length);

  static const int _chunk = 256 * 1024;

  final RandomAccessFile _raf;

  @override
  final GitObjectType type;

  @override
  final int length;

  @override
  Uint8List readSync(int offset, int count) {
    // The body starts after the 1-byte type code.
    if (offset >= length) return Uint8List(0);
    _raf.setPositionSync(offset + 1);
    return _raf.readSync(min(count, length - offset));
  }

  @override
  Stream<List<int>> openRead() async* {
    var pos = 0;
    await _raf.setPosition(1);
    while (pos < length) {
      final chunk = await _raf.read(min(_chunk, length - pos));
      if (chunk.isEmpty) {
        throw FileSystemException('Object file ended early', _raf.path);
      }
      pos += chunk.length;
      yield chunk;
    }
  }

  @override
  Future<void> close() => _raf.close();
}

/// Writes straight to a temp file, synchronously so nothing queues in
/// memory, and renames it into place once the id is known.
final class _FileObjectWriter implements GitObjectWriter {
  _FileObjectWriter(this._store, this._tmp, GitObjectType type, int size)
    : _hasher = GitObjectHasher(type, size),
      _raf = _tmp.openSync(mode: FileMode.writeOnly)
        ..writeByteSync(type.packCode);

  final FileGitObjectStore _store;
  final File _tmp;
  final GitObjectHasher _hasher;
  final RandomAccessFile _raf;
  bool _open = true;

  @override
  void add(List<int> chunk) {
    _hasher.add(chunk);
    _raf.writeFromSync(chunk);
  }

  Future<void> _closeFile() async {
    if (!_open) return;
    _open = false;
    await _raf.close();
  }

  @override
  Future<GitObjectId> close() async {
    final GitObjectId id;
    try {
      id = _hasher.close();
      await _raf.flush();
      await _closeFile();
      await _store._adopt(id, _tmp, _hasher.size + 1);
    } catch (_) {
      await abort();
      rethrow;
    }
    return id;
  }

  @override
  Future<void> abort() async {
    await _closeFile();
    try {
      await _tmp.delete();
    } on FileSystemException {
      // Never created, or already gone.
    }
  }
}
