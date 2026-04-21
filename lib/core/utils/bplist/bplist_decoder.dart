import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/core/utils/bplist/bplist_object.dart';

/// Decoder for Apple binary property list v00 ("bplist00"). Supports
/// the subset of types observed in MacDive Core Data BLOBs: null,
/// bool, int (1/2/4/8-byte; 16-byte ints decoded as best-effort from
/// their low 64 bits with a warning in a comment — MacDive hasn't been
/// seen to emit them), real (4/8-byte IEEE754), string (ASCII + UTF-16BE),
/// data, date, dict, array. Sets and CFKeyedArchiver UID refs throw
/// FormatException.
class BPlistDecoder {
  final Uint8List _bytes;
  final int _offsetIntSize;
  final int _objectRefSize;
  final int _offsetTableOffset;

  BPlistDecoder._(
    this._bytes, {
    required int offsetIntSize,
    required int objectRefSize,
    required int offsetTableOffset,
  }) : _offsetIntSize = offsetIntSize,
       _objectRefSize = objectRefSize,
       _offsetTableOffset = offsetTableOffset;

  /// Entry point: decode [bytes] into the root [BPlistObject].
  /// Throws [FormatException] if [bytes] is not a valid bplist00 stream
  /// or uses unsupported type markers (sets, UIDs).
  static BPlistObject decode(Uint8List bytes) {
    if (bytes.length < 8 + 32) {
      throw const FormatException('bplist00 stream too short');
    }
    // Magic: bytes 0..7 must equal "bplist00".
    const magic = [0x62, 0x70, 0x6C, 0x69, 0x73, 0x74, 0x30, 0x30];
    for (var i = 0; i < 8; i++) {
      if (bytes[i] != magic[i]) {
        throw const FormatException('not a bplist00 stream');
      }
    }

    final trailer = bytes.length - 32;
    final offsetIntSize = bytes[trailer + 6];
    final objectRefSize = bytes[trailer + 7];
    final topObjectIndex = _readBigEndianInt(bytes, trailer + 16, 8);
    final offsetTableOffset = _readBigEndianInt(bytes, trailer + 24, 8);

    final decoder = BPlistDecoder._(
      bytes,
      offsetIntSize: offsetIntSize,
      objectRefSize: objectRefSize,
      offsetTableOffset: offsetTableOffset,
    );
    return decoder._readObject(topObjectIndex);
  }

  int _offsetOfObject(int index) {
    final pos = _offsetTableOffset + index * _offsetIntSize;
    return _readBigEndianInt(_bytes, pos, _offsetIntSize);
  }

  BPlistObject _readObject(int index) {
    final offset = _offsetOfObject(index);
    final marker = _bytes[offset];
    final type = marker >> 4;
    final info = marker & 0x0F;

    switch (type) {
      case 0x0: // singletons
        return switch (info) {
          0x0 => const BPlistNull(),
          0x8 => const BPlistBool(false),
          0x9 => const BPlistBool(true),
          _ => throw FormatException(
            'unknown bplist singleton marker 0x${marker.toRadixString(16)}',
          ),
        };

      case 0x1: // int
        // info bits 0..3 encode log2(byteCount): 0->1, 1->2, 2->4, 3->8, 4->16.
        final byteCount = 1 << info;
        return BPlistInt(_readBigEndianInt(_bytes, offset + 1, byteCount));

      case 0x2: // real
        final byteCount = 1 << info;
        return BPlistReal(_readBigEndianReal(_bytes, offset + 1, byteCount));

      case 0x3: // date — always 8-byte big-endian IEEE754
        return BPlistDate(_readBigEndianReal(_bytes, offset + 1, 8));

      case 0x4: // data
        final li = _readLenAndStart(offset, info);
        return BPlistData(
          Uint8List.sublistView(_bytes, li.start, li.start + li.length),
        );

      case 0x5: // ASCII string
        final li = _readLenAndStart(offset, info);
        return BPlistString(
          ascii.decode(
            _bytes.sublist(li.start, li.start + li.length),
            allowInvalid: true,
          ),
        );

      case 0x6: // UTF-16BE string; length is char count
        final li = _readLenAndStart(offset, info);
        return BPlistString(_decodeUtf16Be(_bytes, li.start, li.length));

      case 0xA: // array
        final li = _readLenAndStart(offset, info);
        final refs = <int>[];
        for (var i = 0; i < li.length; i++) {
          refs.add(
            _readBigEndianInt(
              _bytes,
              li.start + i * _objectRefSize,
              _objectRefSize,
            ),
          );
        }
        return BPlistArray(refs.map(_readObject).toList(growable: false));

      case 0xD: // dict
        final li = _readLenAndStart(offset, info);
        final keys = <int>[];
        final values = <int>[];
        for (var i = 0; i < li.length; i++) {
          keys.add(
            _readBigEndianInt(
              _bytes,
              li.start + i * _objectRefSize,
              _objectRefSize,
            ),
          );
        }
        for (var i = 0; i < li.length; i++) {
          values.add(
            _readBigEndianInt(
              _bytes,
              li.start + (li.length + i) * _objectRefSize,
              _objectRefSize,
            ),
          );
        }
        final map = <String, BPlistObject>{};
        for (var i = 0; i < li.length; i++) {
          final key = _readObject(keys[i]);
          if (key is! BPlistString) {
            throw FormatException(
              'bplist dict key at index $i is not a string',
            );
          }
          map[key.value] = _readObject(values[i]);
        }
        return BPlistDict(map);

      default:
        throw FormatException(
          'unsupported bplist marker 0x${marker.toRadixString(16)}',
        );
    }
  }

  /// Decodes a length field that appears inline in a marker byte or, for
  /// info == 0x0F, as a trailing integer marker followed by the int bytes.
  /// Returns the length and the start offset of the payload data.
  _LenAndStart _readLenAndStart(int markerOffset, int info) {
    if (info != 0x0F) {
      return _LenAndStart(info, markerOffset + 1);
    }
    final intMarker = _bytes[markerOffset + 1];
    if ((intMarker >> 4) != 0x1) {
      throw FormatException(
        'expected int marker after 0x0F length, got 0x${intMarker.toRadixString(16)}',
      );
    }
    final intByteCount = 1 << (intMarker & 0x0F);
    final length = _readBigEndianInt(_bytes, markerOffset + 2, intByteCount);
    return _LenAndStart(length, markerOffset + 2 + intByteCount);
  }

  static int _readBigEndianInt(Uint8List bytes, int offset, int size) {
    var value = 0;
    for (var i = 0; i < size; i++) {
      value = (value << 8) | bytes[offset + i];
    }
    return value;
  }

  static double _readBigEndianReal(Uint8List bytes, int offset, int size) {
    final bd = ByteData.sublistView(bytes, offset, offset + size);
    if (size == 4) return bd.getFloat32(0, Endian.big);
    if (size == 8) return bd.getFloat64(0, Endian.big);
    throw FormatException('unsupported bplist real size: $size');
  }

  static String _decodeUtf16Be(Uint8List bytes, int start, int charCount) {
    final units = <int>[];
    for (var i = 0; i < charCount; i++) {
      final offset = start + i * 2;
      units.add((bytes[offset] << 8) | bytes[offset + 1]);
    }
    return String.fromCharCodes(units);
  }
}

class _LenAndStart {
  final int length;
  final int start;
  const _LenAndStart(this.length, this.start);
}
