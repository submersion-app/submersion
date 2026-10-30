import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:submersion/core/services/cloud_storage/git/git_object_id.dart';
import 'package:submersion/core/utils/off_isolate.dart';

/// One object to write into a pack, from memory or streamed from a file.
final class PackEntrySource {
  PackEntrySource.bytes(this.type, Uint8List body)
    : size = body.length,
      _body = body,
      _file = null;

  PackEntrySource.file(this.type, File file, this.size)
    : _body = null,
      _file = file;

  final GitObjectType type;
  final int size;
  final Uint8List? _body;
  final File? _file;

  /// The raw object body.
  Stream<List<int>> open() {
    final body = _body;
    return body != null ? Stream.value(body) : _file!.openRead();
  }
}

/// The type and size header of a pack entry: 3 type bits and a
/// little-endian base-128 size, with 4 bits in the first byte.
Uint8List _entryHeader(GitObjectType type, int size) {
  final out = <int>[];
  var rest = size >> 4;
  var byte = (type.packCode << 4) | (size & 0x0f);
  while (rest > 0) {
    out.add(byte | 0x80);
    byte = rest & 0x7f;
    rest >>= 7;
  }
  out.add(byte);
  return Uint8List.fromList(out);
}

Uint8List _u32(int value) =>
    (ByteData(4)..setUint32(0, value)).buffer.asUint8List();

/// Writes a version 2 pack of [entries], each stored whole (no deltas).
///
/// Bodies are streamed through deflate, so a file-backed entry is never held
/// in memory at once. The stream ends with the SHA-1 of everything before
/// it, as Git requires.
Stream<List<int>> writePack(List<PackEntrySource> entries) async* {
  final digest = DigestCollector();
  final hasher = sha1.startChunkedConversion(digest);

  List<int> emit(List<int> chunk) {
    hasher.add(chunk);
    return chunk;
  }

  yield emit([...ascii.encode('PACK'), ..._u32(2), ..._u32(entries.length)]);
  for (final entry in entries) {
    yield emit(_entryHeader(entry.type, entry.size));
    var written = 0;
    await for (final chunk
        in entry
            .open()
            .map((c) {
              written += c.length;
              return c;
            })
            .transform(ZLibEncoder())) {
      yield emit(chunk);
    }
    if (written != entry.size) {
      throw StateError(
        'Pack entry declared ${entry.size} bytes but produced $written',
      );
    }
  }
  hasher.close();
  yield digest.value!.bytes;
}

/// The pack for [entries], ready to send.
///
/// [writePack] deflates and hashes as it is read, on the isolate that reads it,
/// and a base part is one 8 MiB chunk to that loop. So when every entry is in
/// memory anyway and the total is large, the whole pack is built on another
/// isolate, which costs one compressed part of memory. A file-backed entry
/// streams as ever, however large: it arrives in small chunks, and it may be
/// too big to hold.
Future<Stream<List<int>>> preparePack(
  List<PackEntrySource> entries, {
  int minBytes = kOffIsolateMinBytes,
  OffIsolateRunner runner = isolateRun,
}) async {
  final total = entries.fold(0, (sum, entry) => sum + entry.size);
  if (entries.any((entry) => entry._file != null) || total < minBytes) {
    return writePack(entries);
  }
  return Stream.value(await _packOffIsolate(entries, total, minBytes, runner));
}

Future<Uint8List> _packOffIsolate(
  List<PackEntrySource> entries,
  int total,
  int minBytes,
  OffIsolateRunner runner,
) => runOffIsolate(
  () => _collectPack(entries),
  bytes: total,
  minBytes: minBytes,
  runner: runner,
);

Future<Uint8List> _collectPack(List<PackEntrySource> entries) async {
  final out = BytesBuilder(copy: false);
  await for (final chunk in writePack(entries)) {
    out.add(chunk);
  }
  return out.takeBytes();
}

/// The blob id of [file]'s contents, read as a stream.
Future<GitObjectId> hashFileBlob(File file) async {
  final length = await file.length();
  final digest = DigestCollector();
  final hasher = sha1.startChunkedConversion(digest)
    ..add(ascii.encode('blob $length'))
    ..add(const [0]);
  await for (final chunk in file.openRead()) {
    hasher.add(chunk);
  }
  hasher.close();
  return GitObjectId(Uint8List.fromList(digest.value!.bytes));
}
