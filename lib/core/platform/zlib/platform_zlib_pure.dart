import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'package:submersion/core/platform/zlib/zlib_exceptions.dart';
import 'package:submersion/core/platform/zlib/zlib_framing.dart';

/// Pure Dart deflate, for the browser.
///
/// `package:archive` supplies the encoders and the block-level inflater. The
/// framing is parsed here rather than through archive's zlib and gzip
/// decoders, because those inflate the whole body into memory before writing
/// a byte to their output, which is exactly what a bounded inflate must not
/// do, and because they report a bad header by returning nothing rather than
/// by throwing.
///
/// Trailers are verified when present: a wrong Adler-32 or CRC-32 is a
/// [ZlibFormatException], as it is on the native path. A stream cut short
/// inside the body hands back what was inflated, which is also what the
/// native decoder does; callers frame their own payloads. The unbounded
/// entries cap at [pureInflateCeilingBytes].

/// The cap the "unbounded" pure functions still apply: 256 MiB, well above
/// any blob the app stores or any sync payload, and far below the point
/// where a page dies. archive's inflater can produce output without
/// consuming input on one malformed dynamic block, so a pure inflate with no
/// cap at all could run until memory is exhausted on ten corrupt bytes.
const int pureInflateCeilingBytes = 256 << 20;

/// Compresses [bytes] into a zlib stream at [level].
Uint8List pureDeflate(List<int> bytes, {int level = 6}) =>
    const ZLibEncoderWeb().encodeBytes(bytes, level: level);

/// Inflates a zlib stream with no cap on the body.
Uint8List pureInflate(List<int> bytes) =>
    pureInflateBounded(bytes, maxBytes: pureInflateCeilingBytes);

/// Compresses [bytes] into a gzip stream at [level].
Uint8List pureGzip(List<int> bytes, {int level = 6}) =>
    const GZipEncoderWeb().encodeBytes(bytes, level: level);

/// Inflates a gzip stream with no cap on the body.
Uint8List pureGunzip(List<int> bytes) => pureInflateBounded(
  bytes,
  maxBytes: pureInflateCeilingBytes,
  framing: ZlibFraming.gzip,
);

/// Inflates a stream in [framing], throwing [ZlibBoundExceeded] as soon as
/// the body would pass [maxBytes] and [ZlibFormatException] for bytes that
/// are not such a stream.
Uint8List pureInflateBounded(
  List<int> bytes, {
  required int maxBytes,
  ZlibFraming framing = ZlibFraming.zlib,
}) {
  RangeError.checkNotNegative(maxBytes, 'maxBytes');
  final input = _GuardedInput(bytes);
  final output = _BoundedOutput(maxBytes);
  try {
    switch (framing) {
      case ZlibFraming.zlib:
        _readZlibHeader(input);
      case ZlibFraming.gzip:
        _readGzipHeader(input);
    }
  } on _TruncatedInput {
    throw ZlibFormatException('not a ${framing.name} stream: truncated header');
  }
  // archive reports most bad data by ending the block parse early, so a
  // stream cut short inside the body returns what was inflated, as native
  // does. What it does throw for corrupt data is a RangeError: a
  // back-reference before the start of the output, or a code-length table
  // overrun. Neither is a bug here, so both become the format error every
  // caller already handles.
  try {
    Inflate.stream(input, output: output);
  } on ZlibBoundExceeded {
    rethrow;
  } on ArchiveException catch (e) {
    throw ZlibFormatException(e.message);
  } on RangeError catch (e) {
    throw ZlibFormatException('corrupt deflate stream: ${e.message}');
  } on ArgumentError catch (e) {
    throw ZlibFormatException('corrupt deflate stream: ${e.message}');
  }
  _verifyTrailer(framing, input, output.getBytes());
  return output.getBytes();
}

void _readZlibHeader(_GuardedInput input) {
  final cmf = input.readByte();
  final flg = input.readByte();
  if (cmf & 0x0f != 8) {
    throw ZlibFormatException(
      'not a zlib stream: compression method ${cmf & 0x0f}',
    );
  }
  if ((cmf >> 4) > 7) {
    throw const ZlibFormatException('not a zlib stream: window too large');
  }
  if ((cmf * 256 + flg) % 31 != 0) {
    throw const ZlibFormatException('not a zlib stream: header check failed');
  }
  if (flg & 0x20 != 0) {
    throw const ZlibFormatException(
      'zlib streams with a preset dictionary are not supported',
    );
  }
}

void _readGzipHeader(_GuardedInput input) {
  if (input.readByte() != 0x1f || input.readByte() != 0x8b) {
    throw const ZlibFormatException('not a gzip stream: bad signature');
  }
  final method = input.readByte();
  if (method != 8) {
    throw ZlibFormatException('not a gzip stream: compression method $method');
  }
  final flags = input.readByte();
  // Modification time, extra flags and the operating system byte.
  for (var i = 0; i < 6; i++) {
    input.readByte();
  }
  if (flags & 0x04 != 0) {
    final extraLength = input.readByte() | (input.readByte() << 8);
    for (var i = 0; i < extraLength; i++) {
      input.readByte();
    }
  }
  if (flags & 0x08 != 0) _skipZeroTerminated(input);
  if (flags & 0x10 != 0) _skipZeroTerminated(input);
  if (flags & 0x02 != 0) {
    input.readByte();
    input.readByte();
  }
}

void _skipZeroTerminated(_GuardedInput input) {
  while (input.readByte() != 0) {}
}

void _verifyTrailer(ZlibFraming framing, _GuardedInput input, Uint8List body) {
  switch (framing) {
    case ZlibFraming.zlib:
      if (input.length < 4) return;
      final expected = _readUint32(input, bigEndian: true);
      if (expected != getAdler32(body)) {
        throw const ZlibFormatException('incorrect data check');
      }
    case ZlibFraming.gzip:
      if (input.length < 8) return;
      final crc = _readUint32(input, bigEndian: false);
      final size = _readUint32(input, bigEndian: false);
      if (crc != getCrc32(body) || size != (body.length & 0xffffffff)) {
        throw const ZlibFormatException('incorrect data check');
      }
  }
}

int _readUint32(_GuardedInput input, {required bool bigEndian}) {
  final b0 = input.readByte();
  final b1 = input.readByte();
  final b2 = input.readByte();
  final b3 = input.readByte();
  return bigEndian
      ? (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
      : (b3 << 24) | (b2 << 16) | (b1 << 8) | b0;
}

/// Signals that the stream ended inside a header or trailer.
///
/// archive's own block parser checks for the end of input before every
/// read; the framing reads here do not, and reading past a JavaScript typed
/// array yields `undefined` rather than throwing, so the guard lives on the
/// input side.
class _TruncatedInput implements Exception {
  const _TruncatedInput();
}

class _GuardedInput extends InputMemoryStream {
  _GuardedInput(super.bytes);

  @override
  int readByte() {
    if (isEOS) throw const _TruncatedInput();
    return super.readByte();
  }
}

/// Grows like archive's own memory stream but refuses to pass [_maxBytes].
///
/// The inflater writes literals one byte at a time and back-references as
/// slices of its own earlier output, so every write path is checked and a
/// bomb is abandoned on the write that would cross the cap.
class _BoundedOutput extends OutputMemoryStream {
  _BoundedOutput(this._maxBytes);

  final int _maxBytes;

  void _reserve(int count) {
    if (length + count > _maxBytes) throw ZlibBoundExceeded(_maxBytes);
  }

  @override
  void writeByte(int value) {
    _reserve(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _reserve(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _reserve(stream.length);
    super.writeStream(stream);
  }
}
