import 'schedule.dart';
import 'story_plan.dart';

/// Near the first dive of the technical phase, the deco course's first dive.
const techStartDive = 250;

/// The nitrox card is issued a few days before this dive.
const nitroxDive = 50;

/// Where each course is aimed (its first dive) and how many dives it has.
const _courses = <CertLevel, (int target, int dives)>{
  CertLevel.openWater: (1, 4),
  CertLevel.advanced: (25, 5),
  CertLevel.rescue: (90, 2),
  CertLevel.deep: (150, 4),
  CertLevel.decoProcedures: (techStartDive, 4),
  CertLevel.trimix: (380, 4),
};

/// The dive numbers of each course's training dives, for [slots] in time
/// order ending in [ccrCount] rebreather dives.
///
/// A course is taught in one place: each is the run of dives nearest its
/// target that is all at one destination (home, or one trip), dived within
/// 14 days, somewhere deep enough for it, and after the course before. The
/// rebreather course opens the rebreather phase.
Map<CertLevel, (int, int)> placeCourses(List<Slot> slots, int ccrCount) {
  final ccrStart = slots.length - ccrCount + 1;
  final placed = <CertLevel, (int, int)>{};
  var after = 0;
  for (final MapEntry(key: level, value: (target, count)) in _courses.entries) {
    bool fits(int first) {
      if (first <= after || first + count - 1 >= ccrStart) return false;
      final run = slots.sublist(first - 1, first - 1 + count);
      final where = run.first;
      if (run.any(
        (s) =>
            s.destination.key != where.destination.key ||
            s.tripId != where.tripId,
      )) {
        return false;
      }
      if (run.last.start.difference(where.start).inDays > 14) return false;
      // The home wrecks end at about 46 m; trimix training goes deeper.
      if (level == CertLevel.trimix && where.destination.key == 'home') {
        return false;
      }
      final shallow = where.destination.maxDepthM;
      return level == CertLevel.openWater || shallow == null;
    }

    int? first;
    for (var step = 0; step < 200 && first == null; step++) {
      for (final candidate in [target + step, target - step]) {
        if (candidate >= 1 && fits(candidate)) {
          first = candidate;
          break;
        }
      }
    }
    if (first == null) throw StateError('no place to teach ${level.name}');
    placed[level] = (first, first + count - 1);
    after = first + count - 1;
  }
  placed[CertLevel.ccr] = (ccrStart, ccrStart + 4);
  return placed;
}
