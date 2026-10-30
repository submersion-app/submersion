import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';
import 'package:submersion/features/dive_log/presentation/helpers/dive_scrubber_slots.dart';
import 'package:submersion/shared/widgets/list_scrubber/scrubber_marker.dart';

typedef DiveScrubberRun = ({int firstSlot, int lastSlot});

/// The runs of consecutive slots on the same trip, as in
/// `buildDiveListSections`.
List<DiveScrubberRun> diveScrubberTripRuns(List<DiveScrubberSlot> slots) => [
  for (final run in _runs(slots, (s) => s.entry.tripId))
    (firstSlot: run.firstSlot, lastSlot: run.lastSlot),
];

/// The dives per calendar month of the sort timestamp, one bin per run of
/// slots in the same month. A collapsed trip slot counts all its dives in
/// its first dive's month.
List<ScrubberDensityBin> diveScrubberMonthBins(
  List<DiveScrubberEntry> entries,
  List<DiveScrubberSlot> slots,
) {
  int end(int lastSlot) => lastSlot + 1 < slots.length
      ? slots[lastSlot + 1].entryIndex
      : entries.length;
  return [
    for (final run in _runs(slots, _monthOf))
      ScrubberDensityBin(
        firstSlot: run.firstSlot,
        lastSlot: run.lastSlot,
        count: end(run.lastSlot) - slots[run.firstSlot].entryIndex,
      ),
  ];
}

int _monthOf(DiveScrubberSlot slot) {
  final time = slot.entry.dateTime;
  return time.year * 12 + time.month - 1;
}

/// The slots standing for a classified dive, each with the richest gas of
/// the dives it stands for, poorest first so the richest paint on top.
List<({int slot, DiveScrubberGas gas})> diveScrubberGasSlots(
  List<DiveScrubberEntry> entries,
  List<DiveScrubberSlot> slots,
) {
  final ticks = <({int slot, DiveScrubberGas gas})>[];
  for (var slot = 0; slot < slots.length; slot++) {
    final end = slot + 1 < slots.length
        ? slots[slot + 1].entryIndex
        : entries.length;
    DiveScrubberGas? gas;
    for (var i = slots[slot].entryIndex; i < end; i++) {
      final other = entries[i].gas;
      if (other != null && (gas == null || other.index > gas.index)) {
        gas = other;
      }
    }
    if (gas != null) ticks.add((slot: slot, gas: gas));
  }
  return [
    for (final gas in DiveScrubberGas.values)
      ...ticks.where((tick) => tick.gas == gas),
  ];
}

/// The slots of dives where the numbering breaks in list order: a number
/// that skips ahead of the previous numbered dive in [direction], or
/// repeats it. Dives with no number are passed over.
List<int> diveScrubberGapSlots(
  List<DiveScrubberEntry> entries,
  List<DiveScrubberSlot> slots, {
  required SortDirection direction,
}) {
  final step = direction == SortDirection.ascending ? 1 : -1;
  final gaps = <int>[];
  var slot = -1;
  int? previous;
  for (var i = 0; i < entries.length; i++) {
    while (slot + 1 < slots.length && slots[slot + 1].entryIndex <= i) {
      slot++;
    }
    final number = entries[i].diveNumber;
    if (number == null) continue;
    if (previous != null &&
        number != previous + step &&
        (gaps.isEmpty || gaps.last != slot)) {
      gaps.add(slot);
    }
    previous = number;
  }
  return gaps;
}

/// The runs of consecutive slots with the same non-null key.
List<({int firstSlot, int lastSlot, K key})> _runs<K extends Object>(
  List<DiveScrubberSlot> slots,
  K? Function(DiveScrubberSlot) keyOf,
) {
  final runs = <({int firstSlot, int lastSlot, K key})>[];
  K? key;
  var first = 0;
  void close(int last) {
    final k = key;
    if (k != null) runs.add((firstSlot: first, lastSlot: last, key: k));
  }

  for (var i = 0; i < slots.length; i++) {
    final next = keyOf(slots[i]);
    if (next == key) continue;
    close(i - 1);
    key = next;
    first = i;
  }
  close(slots.length - 1);
  return runs;
}
