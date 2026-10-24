import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/services/cloud_storage/git/git_object_store.dart';
import 'package:submersion/core/services/cloud_storage/git/pack_delta_stream.dart';
import 'package:submersion/core/services/cloud_storage/git/pack_inflater.dart';

GitException _corrupt(String what) => GitException(
  'The server sent a corrupt pack ($what).',
  code: GitErrorCode.unexpected,
);

const int _ofsDelta = 6;
const int _refDelta = 7;

/// Objects (and deltas) up to this size are inflated and resolved in memory;
/// larger ones go to and from the store in pieces, so a download is never
/// held whole however large the file.
const int kGitInMemoryObjectLimit = 4 * 1024 * 1024;

/// A delta whose base had not turned up when it was read: either a REF_DELTA
/// against an object later in the pack, or a delta against such a delta.
final class _Deferred {
  _Deferred(
    this.start,
    this.dataStart,
    this.size,
    this.data, {
    this.baseOffset,
    this.baseId,
  });

  final int start;
  final int dataStart;
  final int size;

  /// The inflated delta when it was small enough to keep; otherwise it is
  /// inflated again from the pack when its base is ready.
  final Uint8List? data;
  final int? baseOffset;
  final GitObjectId? baseId;
}

/// Parses a version 2 pack held in memory; see [readPackFile].
Future<List<GitObjectId>> readPack(
  Uint8List pack,
  GitObjectStore store, {
  int inMemoryLimit = kGitInMemoryObjectLimit,
}) => _readPack(InputMemoryStream(pack), pack.length, store, inMemoryLimit);

/// Parses the version 2 pack in [pack], resolves OFS_DELTA and REF_DELTA
/// entries, and stores every object in [store] as it is resolved. A
/// REF_DELTA base may be in the pack, before or after the delta, or already
/// in [store] (a thin pack). Returns the ids in pack order.
///
/// An object above [inMemoryLimit] is never held whole: it is inflated
/// straight into the store, and a delta against or producing one is applied
/// a piece at a time.
///
/// Throws [GitException] with [GitErrorCode.unexpected] on any malformed
/// input: a bad header or trailer checksum, a corrupt stream, or a delta
/// that does not fit its base; [GitDeltaBaseMissingException] for a delta
/// whose base is neither in the pack nor in [store].
Future<List<GitObjectId>> readPackFile(
  File pack,
  GitObjectStore store, {
  int inMemoryLimit = kGitInMemoryObjectLimit,
}) async {
  final length = await pack.length();
  final input = InputFileStream(pack.path);
  try {
    return await _readPack(input, length, store, inMemoryLimit);
  } finally {
    await input.close();
  }
}

Future<List<GitObjectId>> _readPack(
  InputStream input,
  int length,
  GitObjectStore store,
  int limit,
) async {
  if (length < 32) throw _corrupt('missing PACK signature');
  input.setPosition(0);
  final head = input.readBytes(12).toUint8List();
  if (head[0] != 0x50 ||
      head[1] != 0x41 ||
      head[2] != 0x43 ||
      head[3] != 0x4b) {
    throw _corrupt('missing PACK signature');
  }
  final header = ByteData.sublistView(head, 4, 12);
  if (header.getUint32(0) != 2) throw _corrupt('unsupported pack version');
  final count = header.getUint32(4);
  _verifyTrailer(input, length);

  final end = length - 20;
  final starts = <int>[];
  final resolved = <int, GitObjectId>{};
  final deferred = <_Deferred>[];
  var pos = 12;

  int next() {
    if (pos >= end) throw _corrupt('truncated entry');
    input.setPosition(pos++);
    return input.readByte();
  }

  for (var n = 0; n < count; n++) {
    final start = pos;
    var byte = next();
    final typeCode = (byte >> 4) & 0x07;
    var size = byte & 0x0f;
    var shift = 4;
    while (byte & 0x80 != 0) {
      byte = next();
      size |= (byte & 0x7f) << shift;
      shift += 7;
    }
    int? baseOffset;
    GitObjectId? baseId;
    if (typeCode == _ofsDelta) {
      var c = next();
      var off = c & 0x7f;
      while (c & 0x80 != 0) {
        c = next();
        off = ((off + 1) << 7) | (c & 0x7f);
      }
      baseOffset = start - off;
      // Only an entry already read can be a base: that rules out itself.
      if (!resolved.containsKey(baseOffset) &&
          !deferred.any((d) => d.start == baseOffset)) {
        throw _corrupt('delta base not in pack');
      }
    } else if (typeCode == _refDelta) {
      if (pos + 20 > end) throw _corrupt('truncated delta base id');
      input.setPosition(pos);
      baseId = GitObjectId(input.readBytes(20).toUint8List());
      pos += 20;
    } else if (typeCode < 1 || typeCode > 4) {
      throw _corrupt('object type $typeCode');
    }

    if (baseOffset == null && baseId == null) {
      final type = GitObjectType.fromPackCode(typeCode);
      final whole = await _readWhole(input, pos, type, size, store, limit);
      resolved[start] = whole.id;
      pos += whole.consumed;
    } else {
      final base = baseOffset != null
          ? resolved[baseOffset]
          : (await store.has(baseId!) ? baseId : null);
      if (base != null) {
        final delta = await _readDelta(
          input,
          pos,
          size,
          null,
          base,
          store,
          limit,
        );
        resolved[start] = delta.id;
        pos += delta.consumed;
      } else {
        final kept = size <= limit
            ? inflateBytesAt(input, pos, expectedSize: size)
            : null;
        final consumed = kept?.consumed ?? _skip(input, pos, size);
        deferred.add(
          _Deferred(
            start,
            pos,
            size,
            kept?.data,
            baseOffset: baseOffset,
            baseId: baseId,
          ),
        );
        pos += consumed;
      }
    }
    starts.add(start);
  }
  if (pos != end) throw _corrupt('trailing bytes after objects');

  // Each round resolves every delta whose base has turned up since.
  while (deferred.isNotEmpty) {
    final ready = <_Deferred>[];
    for (final d in deferred) {
      final base = d.baseOffset != null
          ? resolved[d.baseOffset]
          : (await store.has(d.baseId!) ? d.baseId : null);
      if (base == null) continue;
      final delta = await _readDelta(
        input,
        d.dataStart,
        d.size,
        d.data,
        base,
        store,
        limit,
      );
      resolved[d.start] = delta.id;
      ready.add(d);
    }
    if (ready.isEmpty) {
      for (final d in deferred) {
        if (d.baseId != null) throw GitDeltaBaseMissingException(d.baseId!);
      }
      throw _corrupt('delta base not in pack');
    }
    deferred.removeWhere(ready.contains);
  }
  return [for (final s in starts) resolved[s]!];
}

/// Checks the trailing SHA-1 of everything before it, reading in pieces.
void _verifyTrailer(InputStream input, int length) {
  final digest = DigestCollector();
  final hasher = sha1.startChunkedConversion(digest);
  input.setPosition(0);
  var left = length - 20;
  while (left > 0) {
    final n = min(left, 1024 * 1024);
    hasher.add(input.readBytes(n).toUint8List());
    left -= n;
  }
  hasher.close();
  final trailer = input.readBytes(20).toUint8List();
  final bytes = digest.value!.bytes;
  for (var i = 0; i < 20; i++) {
    if (bytes[i] != trailer[i]) throw _corrupt('checksum mismatch');
  }
}

/// The stream length of an entry too large to keep, inflated to nowhere.
int _skip(InputStream input, int offset, int size) =>
    inflateStreamAt(input, offset, expectedSize: size, onData: (_) {}).consumed;

/// Reads a whole (non-delta) object at [offset] and stores it.
Future<({GitObjectId id, int consumed})> _readWhole(
  InputStream input,
  int offset,
  GitObjectType type,
  int size,
  GitObjectStore store,
  int limit,
) async {
  if (size <= limit) {
    final r = inflateBytesAt(input, offset, expectedSize: size);
    final id = hashGitObject(type, r.data);
    await store.put(GitStoredObject(id: id, type: type, body: r.data));
    return (id: id, consumed: r.consumed);
  }
  final writer = store.create(type, size);
  try {
    final r = inflateStreamAt(
      input,
      offset,
      expectedSize: size,
      onData: writer.add,
    );
    return (id: await writer.close(), consumed: r.consumed);
  } catch (_) {
    await writer.abort();
    rethrow;
  }
}

/// Applies the delta at [offset] (or [data], already inflated) to [baseId]
/// and stores the result.
Future<({GitObjectId id, int consumed})> _readDelta(
  InputStream input,
  int offset,
  int size,
  Uint8List? data,
  GitObjectId baseId,
  GitObjectStore store,
  int limit,
) async {
  final base = await store.open(baseId);
  if (base == null) throw GitDeltaBaseMissingException(baseId);
  try {
    var delta = data;
    var consumed = 0;
    if (delta == null && size <= limit) {
      final r = inflateBytesAt(input, offset, expectedSize: size);
      delta = r.data;
      consumed = r.consumed;
    }
    if (delta != null &&
        base.length <= limit &&
        _deltaHeader(delta).targetSize <= limit) {
      final result = applyGitDelta(base.readSync(0, base.length), delta);
      final id = hashGitObject(base.type, result);
      await store.put(GitStoredObject(id: id, type: base.type, body: result));
      return (id: id, consumed: consumed);
    }
    final stream = GitDeltaStream(base, store.create);
    try {
      if (delta != null) {
        stream.add(delta);
      } else {
        consumed = inflateStreamAt(
          input,
          offset,
          expectedSize: size,
          onData: stream.add,
        ).consumed;
      }
      return (id: await stream.close(), consumed: consumed);
    } catch (_) {
      await stream.abort();
      rethrow;
    }
  } finally {
    await base.close();
  }
}

/// A delta's header: the base size it expects and the result size it
/// declares. [end] is where the commands start.
({int sourceSize, int targetSize, int end}) _deltaHeader(Uint8List delta) {
  var pos = 0;
  int varint() {
    var result = 0;
    var shift = 0;
    while (true) {
      if (pos >= delta.length) throw _corrupt('truncated delta size');
      final b = delta[pos++];
      result |= (b & 0x7f) << shift;
      if (b & 0x80 == 0) return result;
      shift += 7;
    }
  }

  final sourceSize = varint();
  final targetSize = varint();
  return (sourceSize: sourceSize, targetSize: targetSize, end: pos);
}

/// Applies a Git delta to [base]. Throws [GitException] when the delta does
/// not match its base or its declared result size.
Uint8List applyGitDelta(Uint8List base, Uint8List delta) {
  final (:sourceSize, :targetSize, end: start) = _deltaHeader(delta);
  var pos = start;
  if (sourceSize != base.length) throw _corrupt('delta base size mismatch');
  final out = Uint8List(targetSize);
  var written = 0;
  while (pos < delta.length) {
    final cmd = delta[pos++];
    if (cmd & 0x80 != 0) {
      var offset = 0;
      var size = 0;
      for (var i = 0; i < 4; i++) {
        if (cmd & (1 << i) != 0) {
          if (pos >= delta.length) throw _corrupt('truncated copy');
          offset |= delta[pos++] << (8 * i);
        }
      }
      for (var i = 0; i < 3; i++) {
        if (cmd & (0x10 << i) != 0) {
          if (pos >= delta.length) throw _corrupt('truncated copy');
          size |= delta[pos++] << (8 * i);
        }
      }
      if (size == 0) size = 0x10000;
      if (offset + size > base.length || written + size > targetSize) {
        throw _corrupt('copy out of range');
      }
      out.setRange(written, written + size, base, offset);
      written += size;
    } else if (cmd != 0) {
      if (pos + cmd > delta.length || written + cmd > targetSize) {
        throw _corrupt('insert out of range');
      }
      out.setRange(written, written + cmd, delta, pos);
      pos += cmd;
      written += cmd;
    } else {
      throw _corrupt('reserved delta opcode');
    }
  }
  if (written != targetSize) throw _corrupt('delta result size mismatch');
  return out;
}
