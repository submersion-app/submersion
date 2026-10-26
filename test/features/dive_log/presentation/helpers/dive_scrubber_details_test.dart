import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_scrubber_details.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_scrubber_slots.dart';
import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';

void main() {
  DiveScrubberEntry dive(
    String id, {
    String? trip,
    int? number,
    DiveScrubberGas? gas,
  }) => DiveScrubberEntry(
    id: id,
    sortTimestamp: 0,
    tripId: trip,
    diveNumber: number,
    gas: gas,
  );

  List<DiveScrubberSlot> slotsOf(
    List<DiveScrubberEntry> entries, {
    Set<String> collapsed = const {},
  }) => buildDiveScrubberSlots(
    entries: entries,
    groupingEnabled: collapsed.isNotEmpty,
    collapsedTripIds: collapsed,
  );

  group('trip runs', () {
    final entries = [
      dive('a'),
      dive('b', trip: 't1'),
      dive('c', trip: 't1'),
      dive('d'),
      dive('f', trip: 't1'),
      dive('g', trip: 't2'),
      dive('h', trip: 't2'),
      dive('i', trip: 't3'),
    ];

    test('one run per stretch of the same trip, interrupted or touching', () {
      expect(diveScrubberTripRuns(slotsOf(entries)), [
        (firstSlot: 1, lastSlot: 2),
        (firstSlot: 4, lastSlot: 4),
        (firstSlot: 5, lastSlot: 6),
        (firstSlot: 7, lastSlot: 7),
      ]);
    });

    test('a collapsed trip run is its single slot', () {
      expect(diveScrubberTripRuns(slotsOf(entries, collapsed: {'t1'})), [
        (firstSlot: 1, lastSlot: 1),
        (firstSlot: 3, lastSlot: 3),
        (firstSlot: 4, lastSlot: 5),
        (firstSlot: 6, lastSlot: 6),
      ]);
    });

    test('no trips, no runs', () {
      expect(diveScrubberTripRuns(slotsOf([dive('a'), dive('b')])), isEmpty);
    });
  });

  group('gas ticks', () {
    const air = DiveScrubberGas.air;
    const nitrox = DiveScrubberGas.nitrox;
    const trimix = DiveScrubberGas.trimix;

    test('a tick per classified dive, poorest first, none without tanks', () {
      final entries = [
        dive('a', gas: air),
        dive('b', gas: nitrox),
        dive('c', gas: trimix),
        dive('d'),
        dive('e', gas: nitrox),
        dive('f', gas: air),
      ];
      expect(diveScrubberGasSlots(entries, slotsOf(entries)), [
        (slot: 0, gas: air),
        (slot: 5, gas: air),
        (slot: 1, gas: nitrox),
        (slot: 4, gas: nitrox),
        (slot: 2, gas: trimix),
      ]);
    });

    test('a collapsed trip takes the richest gas of its dives', () {
      final entries = [
        dive('a', gas: nitrox),
        dive('b', trip: 't1', gas: nitrox),
        dive('c', trip: 't1', gas: trimix),
        dive('d', trip: 't1'),
        dive('e', trip: 't2', gas: air),
        dive('f', trip: 't2', gas: air),
        dive('g', trip: 't3', gas: air),
        dive('h', trip: 't3', gas: nitrox),
        dive('i', trip: 't4'),
        dive('j', trip: 't4'),
        dive('k', gas: trimix),
      ];
      final slots = slotsOf(entries, collapsed: {'t1', 't2', 't3', 't4'});
      expect(diveScrubberGasSlots(entries, slots), [
        (slot: 2, gas: air),
        (slot: 0, gas: nitrox),
        (slot: 3, gas: nitrox),
        (slot: 1, gas: trimix),
        (slot: 5, gas: trimix),
      ]);
    });

    test('no tanks anywhere, or no dives, gives no ticks', () {
      final entries = [dive('a'), dive('b')];
      expect(diveScrubberGasSlots(entries, slotsOf(entries)), isEmpty);
      expect(diveScrubberGasSlots(const [], const []), isEmpty);
    });
  });

  group('number gaps', () {
    List<DiveScrubberEntry> numbered(List<int?> numbers) => [
      for (final (i, n) in numbers.indexed) dive('d$i', number: n),
    ];

    List<int> gaps(
      List<DiveScrubberEntry> entries,
      SortDirection direction, {
      Set<String> collapsed = const {},
    }) => diveScrubberGapSlots(
      entries,
      slotsOf(entries, collapsed: collapsed),
      direction: direction,
    );

    test('skips and repeats ascending, past a dive with no number', () {
      expect(
        gaps(numbered([1, 2, 4, 4, null, 5, 8]), SortDirection.ascending),
        [2, 3, 6],
      );
    });

    test('skips and repeats descending', () {
      expect(
        gaps(numbered([9, 8, 6, 6, null, 5, 2]), SortDirection.descending),
        [2, 3, 6],
      );
    });

    test('an unbroken run and unnumbered dives give no ticks', () {
      expect(gaps(numbered([3, 4, 5, 6]), SortDirection.ascending), isEmpty);
      expect(gaps(numbered([6, 5, 4]), SortDirection.descending), isEmpty);
      expect(gaps(numbered([null, null]), SortDirection.ascending), isEmpty);
    });

    test('a break inside a collapsed trip ticks the trip slot once', () {
      final entries = [
        dive('a', number: 1),
        dive('b', number: 2, trip: 't1'),
        dive('c', number: 5, trip: 't1'),
        dive('d', number: 5, trip: 't1'),
        dive('e', number: 6),
      ];
      expect(gaps(entries, SortDirection.ascending, collapsed: {'t1'}), [1]);
    });
  });

  group('month bins', () {
    DiveScrubberEntry at(String id, DateTime time, {String? trip}) =>
        DiveScrubberEntry(
          id: id,
          sortTimestamp: time.millisecondsSinceEpoch,
          tripId: trip,
        );

    List<ScrubberDensityBin> bins(
      List<DiveScrubberEntry> entries, {
      Set<String> collapsed = const {},
    }) =>
        diveScrubberMonthBins(entries, slotsOf(entries, collapsed: collapsed));

    const bin = ScrubberDensityBin.new;

    final newestFirst = [
      at('a', DateTime.utc(2024, 3, 31, 23, 59)),
      at('b', DateTime.utc(2024, 3, 1)),
      at('c', DateTime.utc(2024, 2, 29, 23, 59)),
      at('d', DateTime.utc(2024, 2, 1)),
      at('e', DateTime.utc(2024, 1, 31, 23, 59)),
      at('f', DateTime.utc(2023, 12, 31, 23, 59)),
      at('g', DateTime.utc(2023, 1, 15)),
    ];

    test('one bin per calendar month, newest first', () {
      expect(bins(newestFirst), [
        bin(firstSlot: 0, lastSlot: 1, count: 2),
        bin(firstSlot: 2, lastSlot: 3, count: 2),
        bin(firstSlot: 4, lastSlot: 4, count: 1),
        bin(firstSlot: 5, lastSlot: 5, count: 1),
        bin(firstSlot: 6, lastSlot: 6, count: 1),
      ]);
    });

    test('one bin per calendar month, oldest first', () {
      expect(bins(newestFirst.reversed.toList()), [
        bin(firstSlot: 0, lastSlot: 0, count: 1),
        bin(firstSlot: 1, lastSlot: 1, count: 1),
        bin(firstSlot: 2, lastSlot: 2, count: 1),
        bin(firstSlot: 3, lastSlot: 4, count: 2),
        bin(firstSlot: 5, lastSlot: 6, count: 2),
      ]);
    });

    test("a collapsed trip counts all its dives in its first dive's month", () {
      final entries = [
        at('a', DateTime.utc(2024, 4, 2)),
        at('b', DateTime.utc(2024, 3, 2), trip: 't1'),
        at('c', DateTime.utc(2024, 3, 1), trip: 't1'),
        at('d', DateTime.utc(2024, 2, 28), trip: 't1'),
        at('e', DateTime.utc(2024, 2, 10)),
        at('f', DateTime.utc(2024, 1, 5), trip: 't2'),
        at('g', DateTime.utc(2024, 1, 4), trip: 't2'),
      ];
      expect(bins(entries, collapsed: {'t1', 't2'}), [
        bin(firstSlot: 0, lastSlot: 0, count: 1),
        bin(firstSlot: 1, lastSlot: 1, count: 3),
        bin(firstSlot: 2, lastSlot: 2, count: 1),
        bin(firstSlot: 3, lastSlot: 3, count: 2),
      ]);
      expect(bins(entries), [
        bin(firstSlot: 0, lastSlot: 0, count: 1),
        bin(firstSlot: 1, lastSlot: 2, count: 2),
        bin(firstSlot: 3, lastSlot: 4, count: 2),
        bin(firstSlot: 5, lastSlot: 6, count: 2),
      ]);
    });

    test('no dives, no bins', () {
      expect(bins(const []), isEmpty);
    });
  });
}
