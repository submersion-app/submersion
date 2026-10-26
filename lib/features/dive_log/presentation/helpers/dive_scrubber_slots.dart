import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';

/// One position on the scrubber track: a dive, or a collapsed trip run.
class DiveScrubberSlot {
  const DiveScrubberSlot({
    required this.entry,
    required this.entryIndex,
    this.collapsedTripId,
    this.isFavorite = false,
  });

  /// The slot's first dive.
  final DiveScrubberEntry entry;

  /// [entry]'s position in list order.
  final int entryIndex;

  /// Set when the slot stands for a collapsed trip's run of dives.
  final String? collapsedTripId;

  /// Whether any dive the slot stands for is a favourite.
  final bool isFavorite;
}

/// Runs of the same trip are consecutive dives, as in `buildDiveListSections`.
List<DiveScrubberSlot> buildDiveScrubberSlots({
  required List<DiveScrubberEntry> entries,
  required bool groupingEnabled,
  required Set<String> collapsedTripIds,
}) {
  final slots = <DiveScrubberSlot>[];
  for (var i = 0; i < entries.length; i++) {
    final trip = entries[i].tripId;
    final folded =
        groupingEnabled && trip != null && collapsedTripIds.contains(trip);
    if (folded && i > 0 && entries[i - 1].tripId == trip) {
      final last = slots.last;
      if (entries[i].isFavorite && !last.isFavorite) {
        slots.last = DiveScrubberSlot(
          entry: last.entry,
          entryIndex: last.entryIndex,
          collapsedTripId: last.collapsedTripId,
          isFavorite: true,
        );
      }
      continue;
    }
    slots.add(
      DiveScrubberSlot(
        entry: entries[i],
        entryIndex: i,
        collapsedTripId: folded ? trip : null,
        isFavorite: entries[i].isFavorite,
      ),
    );
  }
  return slots;
}

/// The indices of the favourite [slots], in slot order.
List<int> diveScrubberFavoriteSlots(List<DiveScrubberSlot> slots) => [
  for (var i = 0; i < slots.length; i++)
    if (slots[i].isFavorite) i,
];
