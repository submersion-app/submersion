import 'package:submersion/features/divers/domain/entities/diver.dart';

/// The active profile on this device is empty while another profile holds
/// the logbook: the usual result of a device creating its own profile before
/// its first sync (issue #3549). From the diver's side it looks like sync
/// lost their dives.
class MisplacedLogbook {
  /// This device's active profile, which has no dives.
  final Diver active;

  /// The profile that most likely holds the diver's logbook.
  final Diver target;

  final int targetDiveCount;

  /// True when [target] is the only other profile holding dives. With
  /// several, [target] may be another person's logbook (a family sharing
  /// the app), so only a switch is offered.
  final bool canMerge;

  const MisplacedLogbook({
    required this.active,
    required this.target,
    required this.targetDiveCount,
    required this.canMerge,
  });
}

/// Identifies one (active, target) pair the user chose to keep apart, so
/// that choice does not hide a different pair later.
String misplacedLogbookPairKey(String activeId, String targetId) =>
    '$activeId>$targetId';

/// Ids of the profiles other than [activeDiverId] that hold at least one
/// dive, from a diver id to dive count map. The one definition of a logbook
/// "holder", shared by detection, the provider's fast path and the merge
/// recheck.
Set<String> otherDiveHolderIds(
  Map<String, int> diveCounts,
  String activeDiverId,
) => {
  for (final e in diveCounts.entries)
    if (e.key != activeDiverId && e.value > 0) e.key,
};

/// Returns the misplaced logbook for [activeDiverId], or null when the active
/// profile has dives, no other profile has any, or the user already chose to
/// keep this pair (a key from [misplacedLogbookPairKey] in [keptBoth]).
///
/// [diveCounts] maps diver id to dive count; a profile missing from it has
/// none. Names are not compared: the two profiles in issue #3549 had
/// different names, which is why the same-name duplicate check missed them.
MisplacedLogbook? findMisplacedLogbook({
  required String? activeDiverId,
  required List<Diver> divers,
  required Map<String, int> diveCounts,
  Set<String> keptBoth = const {},
}) {
  if (activeDiverId == null) return null;
  final active = divers.where((d) => d.id == activeDiverId).firstOrNull;
  if (active == null) return null;
  if ((diveCounts[active.id] ?? 0) > 0) return null;

  int countOf(Diver d) => diveCounts[d.id] ?? 0;
  final holderIds = otherDiveHolderIds(diveCounts, active.id);
  final holders = divers.where((d) => holderIds.contains(d.id)).toList()
    ..sort((a, b) {
      final byCount = countOf(b).compareTo(countOf(a));
      if (byCount != 0) return byCount;
      if (a.isDefault != b.isDefault) return a.isDefault ? -1 : 1;
      return a.createdAt.compareTo(b.createdAt);
    });
  if (holders.isEmpty) return null;

  final target = holders.first;
  if (keptBoth.contains(misplacedLogbookPairKey(active.id, target.id))) {
    return null;
  }
  return MisplacedLogbook(
    active: active,
    target: target,
    targetDiveCount: countOf(target),
    canMerge: holders.length == 1,
  );
}
