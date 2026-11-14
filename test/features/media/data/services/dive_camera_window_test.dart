import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/dive_link_matcher.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';

/// Issue #4539: media is matched to a dive on the clock it is later placed
/// by. A dive whose camera runs six hours ahead is looked for six hours
/// later, or the shift would place what was matched outside the dive and
/// never find the media it was set for.
void main() {
  Dive dive({int shift = 0, DateTime? exit}) => Dive(
    id: 'd1',
    dateTime: DateTime.utc(2026, 5, 6, 9, 4),
    entryTime: DateTime.utc(2026, 5, 6, 9, 4),
    exitTime: exit,
    runtime: const Duration(minutes: 37),
    mediaTimeOffsetSeconds: shift,
  );

  group('TripMediaScanner.diveBounds', () {
    test('is the dive window when the dive has no shift', () {
      final (entry, exit) = TripMediaScanner.diveBounds(
        dive(exit: DateTime.utc(2026, 5, 6, 9, 41)),
      );

      expect(entry, DateTime.utc(2026, 5, 6, 9, 4));
      expect(exit, DateTime.utc(2026, 5, 6, 9, 41));
    });

    test("moves with the dive's shift", () {
      final (entry, exit) = TripMediaScanner.diveBounds(
        dive(shift: -21600, exit: DateTime.utc(2026, 5, 6, 9, 41)),
      );

      expect(entry, DateTime.utc(2026, 5, 6, 15, 4));
      expect(exit, DateTime.utc(2026, 5, 6, 15, 41));
    });

    test('moves an exit worked out from the runtime too', () {
      final (_, exit) = TripMediaScanner.diveBounds(dive(shift: -21600));

      expect(exit, DateTime.utc(2026, 5, 6, 15, 41));
    });
  });

  group('DiveLinkMatcher.boundsFor', () {
    test("moves with the dive's shift", () {
      final bounds = DiveLinkMatcher.boundsFor([
        dive(shift: -21600, exit: DateTime.utc(2026, 5, 6, 9, 41)),
      ]).single;

      expect(bounds.entryTime, DateTime.utc(2026, 5, 6, 15, 4));
      expect(bounds.exitTime, DateTime.utc(2026, 5, 6, 15, 41));
    });
  });
}
