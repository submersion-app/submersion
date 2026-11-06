import 'dart:typed_data';

import 'package:submersion/core/platform/zlib/platform_zlib.dart';
import 'package:submersion/core/utils/bounded_inflate.dart';

/// Thrown when a stored source file cannot be decoded, or a file is too
/// large to store. One declared type, like `NavTrackCodecException` for the
/// points blob.
class NavTrackSourceFileCodecException implements Exception {
  const NavTrackSourceFileCodecException(this.message);

  final String message;

  @override
  String toString() => 'NavTrackSourceFileCodecException: $message';
}

/// The largest original file this codec stores or restores, in bytes.
///
/// A Seacraft ENC row is under 100 bytes, so the points codec's own cap of
/// 131,072 samples comes to roughly 13 MB of CSV: this leaves headroom over
/// any file the parser would accept while still bounding what a sync peer
/// can make this device inflate.
const int kMaxNavTrackSourceFileBytes = 16 * 1024 * 1024;

/// [file], the route's original file, gzipped for `nav_tracks.source_file`
/// (issue #4231). The bytes are stored exactly as they arrived: line
/// endings, byte order mark and a missing final newline included, so an
/// export hands back the same file.
///
/// Throws [NavTrackSourceFileCodecException] for a file over
/// [kMaxNavTrackSourceFileBytes], which [decodeNavTrackSourceFile] would
/// refuse to read back.
Uint8List encodeNavTrackSourceFile(Uint8List file) {
  if (file.length > kMaxNavTrackSourceFileBytes) {
    throw NavTrackSourceFileCodecException(
      'file of ${file.length} byte(s) exceeds the '
      '$kMaxNavTrackSourceFileBytes this codec stores',
    );
  }
  return PlatformZlib.gzip(file);
}

/// The original file stored by [encodeNavTrackSourceFile].
///
/// The blob is peer-supplied (the column syncs as base64), so it is bounded
/// before it is inflated. Throws [NavTrackSourceFileCodecException] for a
/// blob that is not gzip or inflates past [kMaxNavTrackSourceFileBytes].
Uint8List decodeNavTrackSourceFile(Uint8List blob) {
  try {
    return inflateBounded(
      blob,
      framing: ZlibFraming.gzip,
      maxBytes: kMaxNavTrackSourceFileBytes,
      // gzip can emit slightly more than it was given, so the compressed
      // cap matches the body cap rather than sitting under it.
      maxBlobBytes: kMaxNavTrackSourceFileBytes,
    );
  } on BoundedInflateException catch (e) {
    throw NavTrackSourceFileCodecException(e.message);
  }
}
