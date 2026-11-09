import 'package:archive/archive.dart' show getCrc32;

/// The two fields of a gzip member's eight-byte trailer: the CRC-32 of the
/// expanded bytes, and their count modulo 2^32 (ISIZE).
typedef GzipTrailer = ({int crc, int isize});

/// The trailer read from [lastEight], the file's final eight bytes, both
/// fields little endian.
GzipTrailer gzipTrailer(List<int> lastEight) {
  if (lastEight.length != 8) {
    throw const FormatException('a gzip file ends in an eight-byte trailer');
  }
  int uint32At(int i) =>
      lastEight[i] |
      (lastEight[i + 1] << 8) |
      (lastEight[i + 2] << 16) |
      (lastEight[i + 3] << 24);
  return (crc: uint32At(0), isize: uint32At(4));
}

/// [decoded], a gzip file read through `gzip.decoder`, which throws at its
/// end unless the expanded bytes match [trailer], the CRC and size the
/// file's last eight bytes record.
///
/// `gzip.decoder` checks the trailer when it is all there, but expands a
/// file cut short inside it without an error. A file missing its last few
/// bytes ends with something else in its final eight: a size alone could
/// match by chance (a CRC moved into its place), but the CRC and size
/// together do not, and a gzipped base is refused before anything is
/// applied from it (issue #4256).
Stream<List<int>> checkedGzipTrailer(
  Stream<List<int>> decoded,
  GzipTrailer trailer,
) async* {
  var length = 0;
  var crc = 0;
  await for (final chunk in decoded) {
    length += chunk.length;
    crc = getCrc32(chunk, crc);
    yield chunk;
  }
  if (length & 0xffffffff != trailer.isize || crc != trailer.crc) {
    throw FormatException(
      'gzipped file expanded to $length bytes with CRC $crc, its trailer '
      'says ${trailer.isize} bytes with CRC ${trailer.crc} (incomplete)',
    );
  }
}
