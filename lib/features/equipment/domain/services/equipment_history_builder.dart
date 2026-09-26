import 'package:equatable/equatable.dart';

import 'package:submersion/features/equipment/domain/entities/equipment_ownership_event.dart';

/// One dive an item was used on, with the dive's diver (issue #2046).
typedef EquipmentUsageDive = ({String diveId, String? diverId, DateTime date});

/// One line of an item's History card.
sealed class EquipmentHistoryEntry extends Equatable {
  const EquipmentHistoryEntry();

  /// When the entry happened, for ordering: a run's last dive, an event's
  /// time, the item's creation.
  DateTime get at;
}

/// Consecutive dives by one diver.
class EquipmentUsageRun extends EquipmentHistoryEntry {
  final String? diverId;
  final DateTime first;
  final DateTime last;
  final int diveCount;

  const EquipmentUsageRun({
    required this.diverId,
    required this.first,
    required this.last,
    required this.diveCount,
  });

  @override
  DateTime get at => last;

  @override
  List<Object?> get props => [diverId, first, last, diveCount];
}

class EquipmentEventEntry extends EquipmentHistoryEntry {
  final EquipmentOwnershipEvent event;

  const EquipmentEventEntry(this.event);

  @override
  DateTime get at => event.occurredAt;

  @override
  List<Object?> get props => [event];
}

/// The item's creation by its original owner. No event is written for it:
/// the owner is the first transfer's from side, or the current owner.
class EquipmentAddedEntry extends EquipmentHistoryEntry {
  final String? ownerId;
  @override
  final DateTime at;

  const EquipmentAddedEntry({required this.ownerId, required this.at});

  @override
  List<Object?> get props => [ownerId, at];
}

/// An item's history, newest first (issue #2046): usage runs folded from
/// [dives] (any order), the share and ownership [events] (an event naming the
/// same profile on both sides, left by a profile merge, is skipped), and the
/// item's creation when [createdAt] is known. Ties order events, then runs,
/// then the creation.
List<EquipmentHistoryEntry> buildEquipmentHistory({
  required List<EquipmentUsageDive> dives,
  required List<EquipmentOwnershipEvent> events,
  required String? currentOwnerId,
  required DateTime? createdAt,
}) {
  final sorted = [...dives]
    ..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.diveId.compareTo(b.diveId);
    });
  final runs = <EquipmentUsageRun>[];
  for (final dive in sorted) {
    final last = runs.isEmpty ? null : runs.last;
    if (last != null && last.diverId == dive.diverId) {
      runs[runs.length - 1] = EquipmentUsageRun(
        diverId: last.diverId,
        first: last.first,
        last: dive.date,
        diveCount: last.diveCount + 1,
      );
    } else {
      runs.add(
        EquipmentUsageRun(
          diverId: dive.diverId,
          first: dive.date,
          last: dive.date,
          diveCount: 1,
        ),
      );
    }
  }

  final kept = [
    for (final e in events)
      if (e.fromDiverId == null || e.fromDiverId != e.toDiverId) e,
  ];
  final firstTransfer = kept
      .where((e) => e.kind == EquipmentOwnershipEventKind.transferred)
      .fold<EquipmentOwnershipEvent?>(
        null,
        (earliest, e) =>
            earliest == null || e.occurredAt.isBefore(earliest.occurredAt)
            ? e
            : earliest,
      );

  int rank(EquipmentHistoryEntry e) => switch (e) {
    EquipmentEventEntry() => 0,
    EquipmentUsageRun() => 1,
    EquipmentAddedEntry() => 2,
  };

  return [
    for (final e in kept) EquipmentEventEntry(e),
    ...runs,
    if (createdAt != null)
      EquipmentAddedEntry(
        ownerId: firstTransfer?.fromDiverId ?? currentOwnerId,
        at: createdAt,
      ),
  ]..sort((a, b) {
    final byTime = b.at.compareTo(a.at);
    return byTime != 0 ? byTime : rank(a).compareTo(rank(b));
  });
}
