import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;
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

/// The largest stored blob [decodeNavTrackSourceFile] accepts: the file cap
/// plus headroom, because gzip can emit more than it was given for input
/// that does not compress (about 5 bytes per 32 KiB block plus its header
/// and trailer), and a file this codec stored must always read back.
const int kMaxNavTrackSourceFileBlobBytes =
    kMaxNavTrackSourceFileBytes + 64 * 1024;

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
/// blob that is not gzip, inflates past [kMaxNavTrackSourceFileBytes], or
/// does not match its own trailer.
///
/// The trailer is checked here because [inflateBounded] is not a
/// completeness check: the native decoder returns whatever it managed to
/// inflate from a truncated stream. Without this, a blob cut short in sync
/// or storage would be exported, and parsed for markers, as if it were the
/// whole file.
Uint8List decodeNavTrackSourceFile(Uint8List blob) {
  // A gzip member is at least a 10-byte header and an 8-byte trailer.
  if (blob.length < 18) {
    throw NavTrackSourceFileCodecException(
      'blob of ${blob.length} byte(s) is too short to be gzip',
    );
  }
  final Uint8List file;
  try {
    file = inflateBounded(
      blob,
      framing: ZlibFraming.gzip,
      maxBytes: kMaxNavTrackSourceFileBytes,
      maxBlobBytes: kMaxNavTrackSourceFileBlobBytes,
    );
  } on BoundedInflateException catch (e) {
    throw NavTrackSourceFileCodecException(e.message);
  }
  // The encoder writes a single member, so its trailer is the blob's last
  // 8 bytes: CRC-32 of the file, then its length mod 2^32, little-endian.
  final trailer = ByteData.sublistView(blob, blob.length - 8);
  final crc = trailer.getUint32(0, Endian.little);
  final size = trailer.getUint32(4, Endian.little);
  if (size != (file.length & 0xffffffff) || crc != getCrc32(file)) {
    throw const NavTrackSourceFileCodecException(
      'blob is truncated or corrupted: its trailer does not match',
    );
  }
  return file;
}
