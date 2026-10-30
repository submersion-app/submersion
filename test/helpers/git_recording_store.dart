import 'dart:math';
import 'dart:typed_data';

import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';

import 'git_delegating_store.dart';

/// A [GitObjectStore] that records the largest body that crossed it whole,
/// so a test can show a large object only ever moved in pieces.
final class RecordingGitObjectStore extends DelegatingGitObjectStore {
  RecordingGitObjectStore(super.inner);

  /// The largest body [get] returned or [put] was given.
  int largestWholeBody = 0;

  /// The largest piece handed to a writer from [create].
  int largestWriterChunk = 0;

  /// The largest piece read from a reader from [open].
  int largestReaderChunk = 0;

  /// The length of every object opened, in order.
  final List<int> openedLengths = [];

  /// The declared size of every object created, in order.
  final List<int> createdSizes = [];

  @override
  Future<GitStoredObject?> get(GitObjectId id) async {
    final object = await inner.get(id);
    if (object != null) {
      largestWholeBody = max(largestWholeBody, object.body.length);
    }
    return object;
  }

  @override
  Future<void> put(GitStoredObject object) {
    largestWholeBody = max(largestWholeBody, object.body.length);
    return inner.put(object);
  }

  @override
  Future<GitObjectReader?> open(GitObjectId id) async {
    final reader = await inner.open(id);
    if (reader == null) return null;
    openedLengths.add(reader.length);
    return _RecordingReader(this, reader);
  }

  @override
  GitObjectWriter create(GitObjectType type, int size) {
    createdSizes.add(size);
    return _RecordingWriter(this, inner.create(type, size));
  }
}

final class _RecordingReader implements GitObjectReader {
  _RecordingReader(this._store, this._inner);

  final RecordingGitObjectStore _store;
  final GitObjectReader _inner;

  @override
  GitObjectType get type => _inner.type;

  @override
  int get length => _inner.length;

  @override
  Uint8List readSync(int offset, int count) {
    final bytes = _inner.readSync(offset, count);
    _store.largestReaderChunk = max(_store.largestReaderChunk, bytes.length);
    return bytes;
  }

  @override
  Stream<List<int>> openRead() => _inner.openRead().map((chunk) {
    _store.largestReaderChunk = max(_store.largestReaderChunk, chunk.length);
    return chunk;
  });

  @override
  Future<void> close() => _inner.close();
}

final class _RecordingWriter implements GitObjectWriter {
  _RecordingWriter(this._store, this._inner);

  final RecordingGitObjectStore _store;
  final GitObjectWriter _inner;

  @override
  void add(List<int> chunk) {
    _store.largestWriterChunk = max(_store.largestWriterChunk, chunk.length);
    _inner.add(chunk);
  }

  @override
  Future<GitObjectId> close() => _inner.close();

  @override
  Future<void> abort() => _inner.abort();
}
