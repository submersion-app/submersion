import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'package:submersion/core/services/cloud_storage/git/git_errors.dart';

GitException _corrupt(String what) => GitException(
  'The server sent a corrupt pack ($what).',
  code: GitErrorCode.unexpected,
);

/// Inflates the zlib stream that starts at [offset] in [buf].
///
/// Returns the inflated bytes and [consumed], the exact length of the zlib
/// stream: its 2-byte header, the deflate data, and the 4-byte Adler-32
/// trailer. A packfile stores objects back to back with no lengths, so this
/// count is the only way to find where the next object starts.
///
/// The deflate decoder buffers bits ahead of what it has used, so the input
/// position it stops at can sit a few bytes past the real end of the data.
/// The trailer pins the end exactly: it is the big-endian Adler-32 of the
/// inflated bytes, found in a small window around where decoding stopped.
({Uint8List data, int consumed}) inflateAt(
  Uint8List buf,
  int offset, {
  int? expectedSize,
}) =>
    inflateBytesAt(InputMemoryStream(buf), offset, expectedSize: expectedSize);

/// [inflateAt] reading from [input], which may be a whole pack on disk.
({Uint8List data, int consumed}) inflateBytesAt(
  InputStream input,
  int offset, {
  int? expectedSize,
}) {
  final output = OutputMemoryStream(size: expectedSize);
  final stoppedAt = _inflate(input, offset, output);
  final data = output.getBytes();
  final consumed = _consumed(input, offset, stoppedAt, data.length, () {
    return getAdler32(data);
  }, expectedSize);
  return (data: data, consumed: consumed);
}

/// [inflateAt] for an object too large to hold whole: the inflated bytes go
/// to [onData] in pieces of at most about a megabyte as they are produced,
/// and only the last 32 KB (the furthest a deflate back-reference reaches)
/// is kept. [input] may be a whole pack on disk.
///
/// Returns the inflated size and the stream length. An exception [onData]
/// throws comes out as itself, so a full disk is not reported as a corrupt
/// pack.
({int size, int consumed}) inflateStreamAt(
  InputStream input,
  int offset, {
  int? expectedSize,
  required void Function(Uint8List chunk) onData,
}) {
  final output = _WindowedOutput(onData);
  final int stoppedAt;
  try {
    stoppedAt = _inflate(input, offset, output);
    output.flush();
  } on Object {
    final error = output.receiverError;
    if (error != null) Error.throwWithStackTrace(error, output.receiverStack!);
    rethrow;
  }
  final consumed = _consumed(
    input,
    offset,
    stoppedAt,
    output.length,
    () => output.adler,
    expectedSize,
  );
  return (size: output.length, consumed: consumed);
}

/// Checks the zlib header at [offset] and inflates what follows into
/// [output]. Returns the input position decoding stopped at.
int _inflate(InputStream input, int offset, OutputStream output) {
  final total = input.position + input.length;
  if (offset + 2 > total) throw _corrupt('truncated zlib header');
  input.setPosition(offset);
  final cmf = input.readByte();
  final flg = input.readByte();
  if ((cmf & 0x0f) != 8 || ((cmf << 8) | flg) % 31 != 0 || (flg & 0x20) != 0) {
    throw _corrupt('bad zlib header');
  }
  try {
    Inflate.stream(input, output: output);
  } on _ReceiverFailed {
    rethrow;
  } catch (e) {
    throw _corrupt('deflate error: $e');
  }
  return input.position;
}

/// The stream length, from the Adler-32 trailer near [stoppedAt].
int _consumed(
  InputStream input,
  int offset,
  int stoppedAt,
  int size,
  int Function() adlerOf,
  int? expectedSize,
) {
  if (expectedSize != null && size != expectedSize) {
    throw _corrupt('size $size, expected $expectedSize');
  }
  final adler = adlerOf();
  final total = input.position + input.length;
  final from = max(offset + 2, stoppedAt - 8);
  final to = min(stoppedAt + 8, total);
  if (to <= from) throw _corrupt('Adler-32 trailer not found');
  input.setPosition(from);
  final window = input.readBytes(to - from).toUint8List();
  for (var i = 0; i + 4 <= window.length; i++) {
    final trailer =
        (window[i] << 24) |
        (window[i + 1] << 16) |
        (window[i + 2] << 8) |
        window[i + 3];
    if (trailer == adler) return from + i + 4 - offset;
  }
  throw _corrupt('Adler-32 trailer not found');
}

/// Thrown through the decoder when the receiver of inflated bytes fails, so
/// that failure is not mistaken for a corrupt stream.
final class _ReceiverFailed implements Exception {
  const _ReceiverFailed();
}

/// Inflate output that hands bytes on in pieces and keeps only the window a
/// back-reference can reach.
final class _WindowedOutput extends OutputStream {
  _WindowedOutput(this._onData) : super(byteOrder: ByteOrder.littleEndian);

  /// The furthest back a deflate distance code reaches.
  static const int _window = 32 * 1024;
  static const int _capacity = 1024 * 1024;

  final void Function(Uint8List chunk) _onData;
  Uint8List _buf = Uint8List(_capacity);
  int _used = 0;

  /// Bytes already handed on; [_buf] starts at this output position.
  int _emitted = 0;

  /// The running Adler-32 of every byte handed on.
  int adler = 1;

  Object? receiverError;
  StackTrace? receiverStack;

  @override
  int get length => _emitted + _used;

  @override
  void clear() {
    _used = 0;
    _emitted = 0;
    adler = 1;
  }

  @override
  void flush() => _emit(_used);

  /// Hands on the first [n] buffered bytes and shifts the rest down.
  void _emit(int n) {
    if (n <= 0) return;
    final chunk = Uint8List.fromList(Uint8List.sublistView(_buf, 0, n));
    adler = getAdler32(chunk, adler);
    try {
      _onData(chunk);
    } catch (e, s) {
      receiverError = e;
      receiverStack = s;
      throw const _ReceiverFailed();
    }
    _buf.setRange(0, _used - n, _buf, n);
    _used -= n;
    _emitted += n;
  }

  /// Makes room for [n] more bytes, keeping the back-reference window.
  void _reserve(int n) {
    if (_used + n <= _buf.length) return;
    _emit(_used - _window);
    if (_used + n > _buf.length) {
      _buf = Uint8List(_used + n + _capacity)..setRange(0, _used, _buf);
    }
  }

  @override
  void writeByte(int value) {
    _reserve(1);
    _buf[_used++] = value;
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final n = length ?? bytes.length;
    _reserve(n);
    _buf.setRange(_used, _used + n, bytes);
    _used += n;
  }

  @override
  void writeStream(InputStream stream) => writeBytes(stream.toUint8List());

  @override
  Uint8List subset(int start, [int? end]) {
    final s = start < 0 ? length + start : start;
    final e = end == null ? length : (end < 0 ? length + end : end);
    if (s < _emitted) {
      throw StateError('A back-reference reached past the inflate window');
    }
    return Uint8List.fromList(
      Uint8List.sublistView(_buf, s - _emitted, e - _emitted),
    );
  }
}
