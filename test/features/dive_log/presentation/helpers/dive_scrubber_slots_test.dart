import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_scrubber_slots.dart';

DiveScrubberEntry e(String id, [String? trip, bool favorite = false]) =>
    DiveScrubberEntry(
      id: id,
      sortTimestamp: 0,
      tripId: trip,
      isFavorite: favorite,
    );

void main() {
  final entries = [e('a'), e('b', 't1'), e('c', 't1'), e('d'), e('f', 't1')];

  test('one slot per dive without grouping', () {
    final slots = buildDiveScrubberSlots(
      entries: entries,
      groupingEnabled: false,
      collapsedTripIds: {'t1'},
    );
    expect(slots.map((s) => s.entry.id), ['a', 'b', 'c', 'd', 'f']);
    expect(slots.every((s) => s.collapsedTripId == null), isTrue);
  });

  test('a collapsed trip run folds into one slot', () {
    final slots = buildDiveScrubberSlots(
      entries: entries,
      groupingEnabled: true,
      collapsedTripIds: {'t1'},
    );
    expect(slots.map((s) => s.entry.id), ['a', 'b', 'd', 'f']);
    expect(slots.map((s) => s.entryIndex), [0, 1, 3, 4]);
    expect(slots[1].collapsedTripId, 't1');
    expect(slots[3].collapsedTripId, 't1');
  });

  test('an expanded trip keeps a slot per dive', () {
    final slots = buildDiveScrubberSlots(
      entries: entries,
      groupingEnabled: true,
      collapsedTripIds: const {},
    );
    expect(slots, hasLength(5));
  });

  group('favourites', () {
    final marked = [
      e('a', null, true),
      e('b', 't1'),
      e('c', 't1', true),
      e('d'),
      e('f', 't2', true),
      e('g', 't2'),
    ];

    test('entries carry the favourite flag', () {
      expect(marked.first.isFavorite, isTrue);
      expect(e('x').isFavorite, isFalse);
      expect(e('x'), isNot(e('x', null, true)));
    });

    test('a slot is a favourite when its dive is', () {
      final slots = buildDiveScrubberSlots(
        entries: marked,
        groupingEnabled: false,
        collapsedTripIds: const {},
      );
      expect(slots.map((s) => s.isFavorite), [
        true,
        false,
        true,
        false,
        true,
        false,
      ]);
      expect(diveScrubberFavoriteSlots(slots), [0, 2, 4]);
    });

    test('a collapsed trip slot is a favourite when any of its dives is', () {
      final slots = buildDiveScrubberSlots(
        entries: marked,
        groupingEnabled: true,
        collapsedTripIds: const {'t1', 't2'},
      );
      expect(slots.map((s) => s.entry.id), ['a', 'b', 'd', 'f']);
      expect(slots.map((s) => s.isFavorite), [true, true, false, true]);
      expect(diveScrubberFavoriteSlots(slots), [0, 1, 3]);
    });

    test('no favourites gives no slots', () {
      final slots = buildDiveScrubberSlots(
        entries: entries,
        groupingEnabled: false,
        collapsedTripIds: const {},
      );
      expect(diveScrubberFavoriteSlots(slots), isEmpty);
    });
  });
}
