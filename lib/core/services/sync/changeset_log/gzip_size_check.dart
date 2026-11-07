/// The expanded size a gzip member records in the last four bytes of its
/// trailer (ISIZE, little endian, modulo 2^32), from [lastFour], the file's
/// final four bytes.
int gzipTrailerSize(List<int> lastFour) {
  if (lastFour.length != 4) {
    throw const FormatException('a gzip file ends in a four-byte size');
  }
  return lastFour[0] |
      (lastFour[1] << 8) |
      (lastFour[2] << 16) |
      (lastFour[3] << 24);
}

/// [decoded], a gzip file read through `gzip.decoder`, which throws at its
/// end unless it expanded to [isize] bytes (modulo 2^32), the size the
/// file's trailer records.
///
/// `gzip.decoder` checks the trailer when it is all there, but expands a
/// file cut short inside it without an error. A file missing its last few
/// bytes ends with something else in its final four, so its expanded size
/// does not match them, and a gzipped base is refused before anything is
/// applied from it (issue #4256).
Stream<List<int>> checkedGzipLength(
  Stream<List<int>> decoded,
  int isize,
) async* {
  var length = 0;
  await for (final chunk in decoded) {
    length += chunk.length;
    yield chunk;
  }
  if (length & 0xffffffff != isize) {
    throw FormatException(
      'gzipped file expanded to $length bytes, its trailer says $isize '
      '(incomplete)',
    );
  }
}
