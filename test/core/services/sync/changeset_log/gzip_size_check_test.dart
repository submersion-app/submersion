import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/changeset_log/gzip_size_check.dart';

/// gzip.decoder expands a gzip cut short inside its trailer without an
/// error, so a gzipped base is checked against the trailer's own size
/// field (issue #4256).
void main() {
  final document = utf8.encode('{"a":[${List.generate(5000, (i) => i)}]}');
  final whole = gzip.encode(document);

  Future<List<int>> expand(List<int> file) => checkedGzipLength(
    Stream.value(file).transform(gzip.decoder),
    gzipTrailerSize(file.sublist(file.length - 4)),
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

  test('a trailer needs four bytes', () {
    expect(() => gzipTrailerSize([1, 2, 3]), throwsFormatException);
    expect(gzipTrailerSize([0x01, 0x02, 0x00, 0x00]), 0x0201);
  });
}
