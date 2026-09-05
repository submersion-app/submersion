import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Largest raw dive blob this app will encode into, or accept out of, a UDDF
/// `<dcdump>` element.
///
/// Issue #227 defines the same ceiling in
/// `lib/core/database/raw_dive_data_codec.dart` for the at-rest codec.
/// Whichever of the two changes lands second deletes its duplicate and
/// imports the other's, so there is exactly one definition of this number.
const int kMaxRawDiveBlobBytes = 8 * 1024 * 1024;

/// A dump exceeded [kMaxRawDiveBlobBytes], encoding or decoding.
///
/// Decompression bombs are the reason this exists: a `<dcdump>` in a file from
/// anywhere else is untrusted input, and bzip2 expands far more aggressively
/// than zlib, so a small element can decode to a great deal.
class UddfDumpTooLargeException implements Exception {
  const UddfDumpTooLargeException();

  @override
  String toString() =>
      'UddfDumpTooLargeException: raw dive dump exceeds '
      '$kMaxRawDiveBlobBytes bytes';
}

/// Encodes and decodes the payload of a UDDF `<dcdump>` element.
///
/// UDDF 3.2.1 requires that "the memory dump data shall be compressed with
/// bzip2 algorithm and encoded into ASCII using Base64 encoder". bzip2 is
/// therefore not a choice this class makes; gzip would be faster and would
/// produce a file no other UDDF reader can open.
///
/// This is NOT the codec issue #227 uses to compress the same bytes at rest.
/// That one is zlib behind an `SRD1` header, chosen for space. Bytes read
/// through Drift arrive already decoded by #227's `TypeConverter`, so the
/// export always decodes and then recompresses. Copying the stored blob
/// through would be faster and would produce a spec-violating file.
class UddfDumpCodec {
  const UddfDumpCodec._();

  /// bzip2 then base64.
  ///
  /// Throws [UddfDumpTooLargeException] rather than mint a dump its own
  /// decoder would refuse.
  static String encodeOne(Uint8List raw) {
    if (raw.length > kMaxRawDiveBlobBytes) {
      throw const UddfDumpTooLargeException();
    }
    return base64.encode(BZip2Encoder().encodeBytes(raw));
  }

  /// base64 then bzip2, bounded at [kMaxRawDiveBlobBytes] and CRC checked.
  ///
  /// Decoding runs into a bounded [OutputStream] rather than
  /// `BZip2Decoder.decodeBytes`, so a bomb is abandoned partway instead of
  /// being fully allocated and only then measured.
  ///
  /// `verify: true` is not optional here. The decoder compares bzip2's block
  /// and stream CRCs only when it is set, and these bytes are the sole
  /// recoverable copy of a download: a damaged `<dcdump>` whose framing still
  /// parses would otherwise restore silently wrong bytes that surface much
  /// later as a wrong re-parse. Failing instead hands the dump to the
  /// caller's skip-and-count path, which reports the loss.
  static Uint8List decodeOne(String base64Text) {
    final compressed = base64.decode(base64Text.trim());
    final output = _BoundedOutputStream(kMaxRawDiveBlobBytes);
    final ok = BZip2Decoder().decodeStream(
      InputMemoryStream(compressed),
      output,
      verify: true,
    );
    if (!ok) {
      throw const FormatException('Malformed bzip2 payload in <dcdump>');
    }
    return Uint8List.fromList(output.getBytes());
  }

  /// Encode many blobs on a worker isolate.
  ///
  /// Returns a list positionally matching [raws], carrying `null` wherever
  /// that blob could not be encoded. A single bad blob must not cost the user
  /// the whole export: this is a backup path, and a file missing one dump
  /// beats no file at all.
  ///
  /// bzip2 is a block sorting compressor and is markedly slower in pure Dart
  /// than zlib, which is why a whole logbook's worth of it does not run on the
  /// calling isolate.
  static Future<List<String?>> encodeAll(List<Uint8List> raws) {
    if (raws.isEmpty) return Future.value(const []);
    return _encodeOnWorker(raws);
  }

  /// Minimal-scope hop to the worker isolate.
  ///
  /// Kept as its own method so the [Isolate.run] closure's enclosing scope
  /// holds only sendable values: Dart closures capture the whole enclosing
  /// scope, not only what they reference. This mirrors `backup_crypto.dart`,
  /// which documents the same hazard.
  static Future<List<String?>> _encodeOnWorker(List<Uint8List> raws) {
    return Isolate.run(() => _encodeAllImpl(raws), debugName: 'uddf-dcdump');
  }

  static List<String?> _encodeAllImpl(List<Uint8List> raws) {
    return raws
        .map((raw) {
          try {
            return encodeOne(raw);
          } catch (_) {
            return null;
          }
        })
        .toList(growable: false);
  }
}

/// An [OutputStream] that refuses to grow past [maxBytes].
///
/// Delegates to an [OutputMemoryStream] rather than reimplementing its buffer,
/// and checks the bound before each write, so an oversized stream is abandoned
/// partway rather than after it is fully materialised.
class _BoundedOutputStream extends OutputStream {
  _BoundedOutputStream(this.maxBytes)
    : _inner = OutputMemoryStream(),
      super(byteOrder: ByteOrder.littleEndian);

  final int maxBytes;
  final OutputMemoryStream _inner;

  void _guard(int adding) {
    if (_inner.length + adding > maxBytes) {
      throw const UddfDumpTooLargeException();
    }
  }

  @override
  int get length => _inner.length;

  @override
  void writeByte(int value) {
    _guard(1);
    _inner.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _guard(length ?? bytes.length);
    _inner.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _guard(stream.length);
    _inner.writeStream(stream);
  }

  @override
  void clear() => _inner.clear();

  @override
  void flush() => _inner.flush();

  @override
  Uint8List subset(int start, [int? end]) => _inner.subset(start, end);
}
