import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';

/// Whether two dives' gear use overlaps by more than
/// [QualityThresholds.sharedGearOverlapTolerance], which absorbs
/// unsynchronised dive computer clocks (issue #2853).
bool gearUseOverlaps({
  required DateTime aStart,
  required DateTime aEnd,
  required DateTime bStart,
  required DateTime bEnd,
}) {
  final start = aStart.isAfter(bStart) ? aStart : bStart;
  final end = aEnd.isBefore(bEnd) ? aEnd : bEnd;
  return end.difference(start) > QualityThresholds.sharedGearOverlapTolerance;
}

/// A dive's end for the shared gear check (issue #2853), the same rule for
/// both dives of a pair whichever side is scanned: the recorded exit, else
/// entry plus runtime, else entry plus bottom time; null with none of them.
/// Deliberately not `Dive.effectiveRuntime`, which also derives a runtime
/// from the profile the other side never reads.
DateTime? sharedGearExit({
  required DateTime entry,
  DateTime? exit,
  Duration? runtime,
  Duration? bottomTime,
}) {
  if (exit != null) return exit;
  final duration = runtime ?? bottomTime;
  return duration == null ? null : entry.add(duration);
}

/// Folds matched items into their topmost matched host or assembly parent,
/// so one physical setup gives one finding. [hostsOf] maps each matched
/// item to its host and assembly-parent ids; ids outside its keys are not
/// matched and are ignored. Returns each top to the ids folded under it.
Map<String, Set<String>> foldToTopmost(Map<String, Set<String>> hostsOf) {
  String topOf(String id) {
    final path = <String>[id];
    var current = id;
    while (true) {
      final next = [
        for (final h in hostsOf[current] ?? const <String>{})
          if (hostsOf.containsKey(h)) h,
      ]..sort();
      if (next.isEmpty) return current;
      final step = next.first;
      final loopStart = path.indexOf(step);
      if (loopStart >= 0) {
        // A loop in the links (corrupt data): its smallest member is the
        // top, never an item that only leads into it.
        return (path.sublist(loopStart)..sort()).first;
      }
      path.add(step);
      current = step;
    }
  }

  final out = <String, Set<String>>{};
  for (final id in hostsOf.keys) {
    final top = topOf(id);
    final folded = out.putIfAbsent(top, () => <String>{});
    if (id != top) folded.add(id);
  }
  return out;
}
