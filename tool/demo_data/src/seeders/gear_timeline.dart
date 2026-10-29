import 'package:submersion/core/constants/enums.dart';

import '../story/story_plan.dart';
import 'gear_catalog.dart';

/// When each piece of kit arrived and when it stopped being used.
///
/// Kit is bought on a home day in the week before the dive it was bought
/// for, never during a trip. A replacement is bought on the first home day
/// after its predecessor went (lost, retired, swapped), or at that moment
/// when the diver is home. An item stops being used after the dive it left
/// on.
class GearTimeline {
  GearTimeline(this.plan, List<DemoGear> gear)
    : _gear = {for (final g in gear) g.key: g},
      _trips = [
        for (final t in plan.trips)
          (
            DateTime(t.start.year, t.start.month, t.start.day),
            DateTime(t.end.year, t.end.month, t.end.day + 1),
          ),
      ];

  final StoryPlan plan;
  final Map<String, DemoGear> _gear;
  final List<(DateTime, DateTime)> _trips;
  final _bought = <String, DateTime?>{};

  bool _away(DateTime day) =>
      _trips.any((t) => !day.isBefore(t.$1) && day.isBefore(t.$2));

  /// The latest day on or before [when] that is not part of a trip.
  DateTime homeDayOnOrBefore(DateTime when) {
    var day = DateTime(when.year, when.month, when.day);
    while (_away(day)) {
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return day;
  }

  /// The earliest day on or after [when] that is not part of a trip.
  DateTime homeDayOnOrAfter(DateTime when) {
    var day = DateTime(when.year, when.month, when.day);
    while (_away(day)) {
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return day;
  }

  PlannedDive _dive(StoryMilestone at, int offset) {
    final n = (plan.milestones[at]! + offset).clamp(1, plan.dives.length);
    return plan.dives[n - 1];
  }

  /// When [key] was bought; null for an item still on the wish list.
  DateTime? boughtOn(String key) => _bought.putIfAbsent(key, () {
    final g = _gear[key]!;
    if (g.status == EquipmentStatus.wanted) return null;
    if (g.replaces != null) {
      final gone = leftOn(g.replaces!)!;
      final day = homeDayOnOrAfter(gone);
      return day.isBefore(gone) ? gone : day;
    }
    final dive = _dive(g.bought, g.boughtOffset);
    final week = dive.start.subtract(const Duration(days: 7));
    return homeDayOnOrBefore(week);
  });

  /// When [key] stopped being used: the end of the dive it left on, or null
  /// while it is still used.
  DateTime? leftOn(String key) {
    final leaves = _gear[key]!.leaves;
    if (leaves == null) return null;
    final dive = _dive(leaves.at, leaves.offset);
    final end = dive.start.add(dive.plannedDuration);
    // Sold, lent or retired once home; only a loss happens on the trip.
    if (leaves.status == EquipmentStatus.lost || !_away(end)) return end;
    return homeDayOnOrAfter(end);
  }

  /// Whether [key] is the diver's and still in use at [when].
  bool inUseOn(String key, DateTime when) {
    final from = boughtOn(key);
    if (from == null || when.isBefore(from)) return false;
    final until = leftOn(key);
    return until == null || when.isBefore(until);
  }
}
