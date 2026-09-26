import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/utils/dive_service_status.dart';

/// A dive's gear carries today's service state only while the dive is still
/// actionable. A logged past dive is a record of what happened, and a mark
/// about today beside it would read as a claim about that dive (#2260).
void main() {
  final now = DateTime(2026, 6, 15, 12);

  Dive dive({required DateTime at, bool planned = false}) =>
      Dive(id: 'd1', dateTime: at, isPlanned: planned);

  test('a logged dive in the past stays clean', () {
    expect(
      diveGearShowsLiveServiceStatus(dive(at: DateTime(2026, 6, 1)), now),
      isFalse,
    );
  });

  test('a dive scheduled in the future shows it', () {
    expect(
      diveGearShowsLiveServiceStatus(dive(at: DateTime(2026, 7, 1)), now),
      isTrue,
    );
  });

  test('a planned dive whose date has passed still shows it', () {
    // Not yet executed, so still actionable: the diver may be about to do
    // it late, and the gear on it has not been used yet.
    expect(
      diveGearShowsLiveServiceStatus(
        dive(at: DateTime(2026, 6, 1), planned: true),
        now,
      ),
      isTrue,
    );
  });

  test('a recorded entry time outranks the header date', () {
    // effectiveEntryTime prefers entryTime over the legacy dateTime field,
    // so a dive the diver actually entered in the past reads as past even
    // if its header carries a later date.
    final logged = Dive(
      id: 'd1',
      dateTime: DateTime(2026, 7, 1),
      entryTime: DateTime(2026, 6, 1),
    );
    expect(diveGearShowsLiveServiceStatus(logged, now), isFalse);
  });

  test('the exact current instant counts as past', () {
    // Strict isAfter, so a dive starting this very instant is not "future".
    expect(diveGearShowsLiveServiceStatus(dive(at: now), now), isFalse);
  });
}
