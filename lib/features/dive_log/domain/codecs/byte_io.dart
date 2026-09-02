import 'dart:typed_data';

import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec_exception.dart';

/// Presence mode for a column block: every value is null, no payload.
const int kPresenceAbsent = 0;

/// Presence mode for a column block: every value is present, no bitmap.
const int kPresenceAll = 1;

/// Presence mode for a column block: a bitmap of `ceil(n / 8)` bytes
/// (LSB-first within each byte) precedes the present values.
const int kPresenceBitmap = 2;

/// The most negative value [ByteWriter.writeVarInt] can zigzag-map.
const int minVarInt = -(1 << 62);

/// The most positive value [ByteWriter.writeVarInt] can zigzag-map.
const int maxVarInt = (1 << 62) - 1;

/// Append-only little-endian byte sink for the series codecs.
class ByteWriter {
  // copy: true (the default) matters: writeFloat64 hands the builder a view
  // of a reused scratch buffer, and a non-copying builder would alias every
  // float written to the same eight bytes.
  final BytesBuilder _builder = BytesBuilder();
  final ByteData _scratch = ByteData(8);

  /// Throws [ArgumentError] outside 0 .. 255. Like [writeVarUint], this is
  /// not an assert: `addByte` keeps the low eight bits, so a release build
  /// would silently write 44 for 300 and the blob would decode under the
  /// wrong version.
  void writeByte(int value) {
    if (value < 0 || value > 0xFF) {
      throw ArgumentError.value(value, 'value', 'not a byte');
    }
    _builder.addByte(value);
  }

  /// Unsigned LEB128 varint: seven bits per byte, high bit set on all but
  /// the last byte.
  ///
  /// Throws [ArgumentError] on a negative value. The check is not an assert
  /// because a release build would otherwise emit one truncated byte for it
  /// and produce a blob no reader can make sense of.
  void writeVarUint(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'varuint cannot encode');
    }
    var remaining = value;
    while (remaining >= 0x80) {
      _builder.addByte((remaining & 0x7F) | 0x80);
      remaining >>= 7;
    }
    _builder.addByte(remaining);
  }

  /// Zigzag-mapped signed varint, so small negatives stay small: 0, -1, 1,
  /// -2, 2 map to 0, 1, 2, 3, 4.
  ///
  /// Dart's int is 64-bit two's complement, so `value << 1` wraps into the
  /// sign bit outside [minVarInt] .. [maxVarInt] and the mapping would hand
  /// [writeVarUint] a negative. Throws [ArgumentError] rather than encode a
  /// value the reader, which refuses a payload reaching bit 63, could not
  /// read back.
  void writeVarInt(int value) {
    if (value < minVarInt || value > maxVarInt) {
      throw ArgumentError.value(value, 'value', 'varint out of zigzag range');
    }
    writeVarUint((value << 1) ^ (value >> 63));
  }

  /// IEEE-754 binary64, little-endian, bit-exact.
  void writeFloat64(double value) {
    _scratch.setFloat64(0, value, Endian.little);
    _builder.add(_scratch.buffer.asUint8List(0, 8));
  }

  void writeBytes(List<int> bytes) => _builder.add(bytes);

  /// Returns everything written and resets the writer.
  Uint8List takeBytes() => _builder.takeBytes();
}

/// Strict forward-only reader over a byte buffer. Every read that would run
/// past the end throws [ProfileSeriesCodecException].
class ByteReader {
  ByteReader(Uint8List bytes)
    : _bytes = bytes,
      _data = ByteData.sublistView(bytes);

  final Uint8List _bytes;
  final ByteData _data;
  int _offset = 0;

  int get offset => _offset;
  int get remaining => _bytes.length - _offset;
  bool get isAtEnd => _offset >= _bytes.length;

  int readByte() {
    _ensure(1);
    return _bytes[_offset++];
  }

  /// Accepts only the minimal encoding of a value. LEB128 lets any value be
  /// padded with continuation bytes carrying no payload, so `0x80 0x00` and
  /// `0x00` would otherwise both decode to zero and one series would have
  /// several valid byte forms. A terminating byte of zero is canonical only
  /// as the whole varint, which is what `shift > 0` tests. That also refuses
  /// the ten-byte form the bit-63 guard below cannot reach, since its tenth
  /// byte must carry a zero payload to get that far.
  int readVarUint() {
    var result = 0;
    var shift = 0;
    while (true) {
      final byte = readByte();
      if (shift == 63 && (byte & 0x7F) != 0) {
        throw const ProfileSeriesCodecException('varint overflows 63 bits');
      }
      result |= (byte & 0x7F) << shift;
      if ((byte & 0x80) == 0) {
        if (shift > 0 && (byte & 0x7F) == 0) {
          throw const ProfileSeriesCodecException(
            'non-canonical varint: padded with an empty terminating byte',
          );
        }
        return result;
      }
      shift += 7;
      if (shift > 63) {
        throw const ProfileSeriesCodecException('varint longer than 64 bits');
      }
    }
  }

  int readVarInt() {
    final zigzag = readVarUint();
    return (zigzag >>> 1) ^ -(zigzag & 1);
  }

  double readFloat64() {
    _ensure(8);
    final value = _data.getFloat64(_offset, Endian.little);
    _offset += 8;
    return value;
  }

  Uint8List readBytes(int count) {
    _ensure(count);
    final view = Uint8List.sublistView(_bytes, _offset, _offset + count);
    _offset += count;
    return view;
  }

  void _ensure(int count) {
    // Subtract rather than add: `_offset + count` overflows into a negative
    // for a count near 2^63, which a crafted length varint can reach, and
    // the guard would pass it straight to a RangeError.
    if (count < 0 || count > _bytes.length - _offset) {
      throw ProfileSeriesCodecException(
        'unexpected end of data: needed $count byte(s) at offset $_offset '
        'of ${_bytes.length}',
      );
    }
  }
}

/// Column blocks: a presence mode byte, an optional bitmap, then only the
/// present values in order.
extension ColumnWriter on ByteWriter {
  /// Writes the presence mode and, when needed, the bitmap. Returns whether
  /// any value is present, so the caller knows whether to write payload.
  bool writePresence(List<Object?> values) {
    var presentCount = 0;
    for (final value in values) {
      if (value != null) presentCount++;
    }
    if (presentCount == 0) {
      writeByte(kPresenceAbsent);
      return false;
    }
    if (presentCount == values.length) {
      writeByte(kPresenceAll);
      return true;
    }
    writeByte(kPresenceBitmap);
    final bitmap = Uint8List((values.length + 7) >> 3);
    for (var i = 0; i < values.length; i++) {
      if (values[i] != null) bitmap[i >> 3] |= 1 << (i & 7);
    }
    writeBytes(bitmap);
    return true;
  }

  /// Writes one column: presence, then [writeValue] for each present value
  /// in order. [writeValue] may keep state between calls (delta encoding).
  void writeColumn<T extends Object>(
    List<T?> values,
    void Function(T value) writeValue,
  ) {
    if (!writePresence(values)) return;
    for (final value in values) {
      if (value != null) writeValue(value);
    }
  }
}

extension ColumnReader on ByteReader {
  /// Reads a presence block for [count] values.
  List<bool> readPresence(int count) {
    final mode = readByte();
    switch (mode) {
      case kPresenceAbsent:
        return List<bool>.filled(count, false);
      case kPresenceAll:
        return List<bool>.filled(count, true);
      case kPresenceBitmap:
        final bitmap = readBytes((count + 7) >> 3);
        return [
          for (var i = 0; i < count; i++)
            ((bitmap[i >> 3] >> (i & 7)) & 1) == 1,
        ];
      default:
        throw ProfileSeriesCodecException('unknown presence mode $mode');
    }
  }

  /// Reads one column of [count] values, calling [readValue] once per
  /// present value in order. [readValue] may keep state between calls.
  List<T?> readColumn<T extends Object>(int count, T Function() readValue) {
    final present = readPresence(count);
    return [for (final isPresent in present) isPresent ? readValue() : null];
  }
}
