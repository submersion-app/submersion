import 'dart:typed_data';

/// Decompresses the Shearwater dive-computer download stream.
///
/// Shearwater computers can emit a log in compressed form (libdivecomputer
/// calls `shearwater_common_download()` with `compression = 1`). The stream
/// is compressed twice: a 9-bit run-length encoding on the outside, and a
/// 32-byte XOR delta on the inside. Reversing both yields Petrel Native
/// Format - 32-byte records with a record-type byte at offset 0 - which
/// `DiveComputerHostApi.parseRawDiveData` accepts directly.
///
/// MacDive stores exactly these compressed bytes in `ZDIVE.ZRAWDATA`. An
/// earlier investigation fed them to the parser without decompressing and
/// concluded the format was proprietary; see
/// `docs/import-formats/macdive-zsamples.md`.
///
/// This is a Dart port of `shearwater_common_decompress_lre` and
/// `shearwater_common_decompress_xor` in
/// `packages/libdivecomputer_plugin/third_party/libdivecomputer/src/shearwater_common.c`.
/// Those functions are `static`, so the plugin cannot expose them.
class ShearwaterRawDecompressor {
  const ShearwaterRawDecompressor._();

  /// Runs both decompression passes. Returns null when [data] is not a valid
  /// LRE stream (its bit count must be a multiple of 9), which is the signal
  /// that these bytes are not a compressed Shearwater log at all.
  static Uint8List? decompress(Uint8List data) {
    final expanded = decompressLre(data);
    if (expanded == null) return null;
    applyXorDelta(expanded);
    return expanded;
  }

  /// Reverses the 9-bit run-length encoding.
  ///
  /// The payload is a continuous MSB-first stream of 9-bit values. Bit
  /// `0x100` marks a literal byte; a value of zero terminates the stream;
  /// anything else is a run of that many zero bytes.
  static Uint8List? decompressLre(Uint8List data) {
    final nbits = data.length * 8;
    if (nbits == 0 || nbits % 9 != 0) return null;

    final out = BytesBuilder();
    // Reused across zero runs so a long run does not allocate per byte. The
    // builder copies on add, so handing out views of this buffer is safe.
    var zeros = Uint8List(0);

    for (var offset = 0; offset + 9 <= nbits; offset += 9) {
      final byte = offset ~/ 8;
      final bit = offset % 8;
      final shift = 16 - (bit + 9);
      final high = data[byte];
      final low = byte + 1 < data.length ? data[byte + 1] : 0;
      final value = (((high << 8) | low) >> shift) & 0x1FF;

      if (value & 0x100 != 0) {
        out.addByte(value & 0xFF);
      } else if (value == 0) {
        // End of the compressed stream. Everything after this is padding.
        break;
      } else {
        if (zeros.length < value) zeros = Uint8List(value);
        out.add(Uint8List.sublistView(zeros, 0, value));
      }
    }

    return out.takeBytes();
  }

  /// Reverses the 32-byte XOR delta, in place. Each block is XORed with the
  /// preceding block; the first block passes through unchanged.
  static void applyXorDelta(Uint8List data) {
    for (var i = 32; i < data.length; i++) {
      data[i] ^= data[i - 32];
    }
  }
}
