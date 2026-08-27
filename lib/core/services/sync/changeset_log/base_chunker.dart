import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Byte-slices a serialized base snapshot into resumable parts and verifies
/// integrity. Parts are raw slices (not individually parseable): download all,
/// reassemble, verify the whole checksum, then parse once.
class BaseChunker {
  static const int defaultPartSize = 8 * 1024 * 1024;

  static List<Uint8List> slice(
    Uint8List data, {
    int partSize = defaultPartSize,
  }) {
    if (data.isEmpty) return [Uint8List(0)];
    final parts = <Uint8List>[];
    for (var off = 0; off < data.length; off += partSize) {
      final end = (off + partSize < data.length) ? off + partSize : data.length;
      parts.add(Uint8List.sublistView(data, off, end));
    }
    return parts;
  }

  static Uint8List reassemble(List<Uint8List> parts) {
    final total = parts.fold<int>(0, (a, p) => a + p.length);
    final out = Uint8List(total);
    var off = 0;
    for (final p in parts) {
      out.setAll(off, p);
      off += p.length;
    }
    return out;
  }

  /// `sha256:<hex>` -- same convention as the manifest checksum fields.
  static String checksum(Uint8List bytes) => 'sha256:${sha256.convert(bytes)}';
}
