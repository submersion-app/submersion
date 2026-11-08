import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/changeset_log/gzip_size_check.dart';

/// gzip.decoder expands a gzip cut short inside its trailer without an
/// error, so a gzipped base is checked against the trailer's own CRC and
/// size fields (issue #4256).
void main() {
  final document = utf8.encode('{"a":[${List.generate(5000, (i) => i)}]}');
  final whole = gzip.encode(document);

  Future<List<int>> expand(List<int> file) => checkedGzipTrailer(
    Stream.value(file).transform(gzip.decoder),
    gzipTrailer(file.sublist(file.length - 8)),
  ).expand((c) => c).toList();

  test('a whole gzip expands as it is', () async {
    expect(await expand(whole), document);
  });

  test('a gzip missing part of its trailer is refused', () async {
    for (final cut in [1, 4, 8]) {
      final short = whole.sublist(0, whole.length - cut);
      // The decoder alone hands back the whole document.
      expect(
        await Stream.value(
          short,
        ).transform(gzip.decoder).expand((c) => c).toList(),
        document,
        reason: 'cut $cut',
      );
      await expectLater(
        expand(short),
        throwsFormatException,
        reason: 'cut $cut',
      );
    }
  });

  test('a size that matches is not enough without the CRC', () async {
    // What a copy cut inside its trailer can end in by chance: the right
    // size beside a CRC that is not the document's.
    final trailer = gzipTrailer(whole.sublist(whole.length - 8));
    await expectLater(
      checkedGzipTrailer(Stream.value(document), (
        crc: trailer.crc ^ 1,
        isize: trailer.isize,
      )).drain<void>(),
      throwsFormatException,
    );
  });

  test('a trailer needs eight bytes', () {
    expect(() => gzipTrailer([1, 2, 3, 4, 5, 6, 7]), throwsFormatException);
    expect(gzipTrailer([0x04, 0x03, 0x02, 0x01, 0x01, 0x02, 0x00, 0x00]), (
      crc: 0x01020304,
      isize: 0x0201,
    ));
  });
}
