import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/services/merged_media_time_offset.dart';

/// One dive holds one media time shift, and every dive merged into it hands
/// over its media (issue #4539). The shift that carries is the one that
/// leaves media already placed where it is.
void main() {
  int merged(List<(String, int)> dives, Set<String> withMedia) =>
      mergedMediaTimeOffsetSeconds([
        for (final (id, shift) in dives) (diveId: id, offsetSeconds: shift),
      ], diveIdsWithMedia: withMedia);

  test('the first dive that owns media keeps its shift', () {
    expect(merged([('a', 0), ('b', -47)], {'b'}), -47);
    expect(merged([('a', 30), ('b', -47)], {'a', 'b'}), 30);
  });

  // Its media is placed by that zero. Taking the other dive's shift would
  // move items nobody asked to move.
  test('a shift of zero counts for a dive that owns media', () {
    expect(merged([('a', 0), ('b', -47)], {'a', 'b'}), 0);
    expect(merged([('a', -47), ('b', 0)], {'b'}), 0);
  });

  // No media is placed by any of them yet, so a correction the diver set is
  // kept for the media that is linked later.
  test('with no media anywhere, the first shift that is set carries', () {
    expect(merged([('a', 0), ('b', -47), ('c', 12)], {}), -47);
  });

  test('is no shift when none is set', () {
    expect(merged([('a', 0), ('b', 0)], {}), 0);
    expect(merged([], {}), 0);
  });
}
