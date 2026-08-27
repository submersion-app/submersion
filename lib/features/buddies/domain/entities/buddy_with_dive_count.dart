import 'package:equatable/equatable.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';

/// A [Buddy] paired with the aggregates the buddy list renders.
///
/// [usualRoleId] is the `dive_buddies.role` id this buddy most often holds
/// (see [usualRoleFor]); null when the buddy has no dives. It is a raw id,
/// resolved to a display name through `diveRoleMapProvider` at render time.
class BuddyWithDiveCount extends Equatable {
  final Buddy buddy;
  final int diveCount;
  final DateTime? lastDiveAt;
  final String? usualRoleId;

  const BuddyWithDiveCount({
    required this.buddy,
    required this.diveCount,
    this.lastDiveAt,
    this.usualRoleId,
  });

  @override
  List<Object?> get props => [buddy, diveCount, lastDiveAt, usualRoleId];
}

/// The role a buddy most often holds, from `{roleId: count}`.
///
/// Higher count wins. Ties break on role id ascending so two devices with
/// the same data agree on the answer. Null when the map is empty.
String? usualRoleFor(Map<String, int> countsByRole) {
  String? best;
  var bestCount = 0;
  final ids = countsByRole.keys.toList()..sort();
  for (final id in ids) {
    final count = countsByRole[id]!;
    if (count > bestCount) {
      best = id;
      bestCount = count;
    }
  }
  return best;
}
