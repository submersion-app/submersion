import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// What a base's resumable parts share: their size and how a part is checked.
/// Parts are raw slices (not individually parseable), cut from a temp file by
/// BasePartFileSource and joined into one by BasePartFileSink, which verifies
/// the whole checksum before anything parses it.
class BaseChunker {
  static const int defaultPartSize = 8 * 1024 * 1024;

  /// `sha256:<hex>` -- same convention as the manifest checksum fields.
  static String checksum(Uint8List bytes) => 'sha256:${sha256.convert(bytes)}';
}
