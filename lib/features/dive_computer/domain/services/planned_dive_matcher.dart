import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Pairs downloaded dives with a profile's unfilled planned dives (issue
/// #2002). Pure: takes start times and entities, returns an index-to-id map.
///
/// Rule: same local calendar day, both lists sorted by start time, walked in
/// order so no planned dive is offered twice and the earliest download takes
/// the earliest plan. A day with more downloads than plans leaves the extra
/// downloads unpaired; more plans than downloads leaves plans unfilled.
class PlannedDiveMatcher {
  const PlannedDiveMatcher();

  Map<int, String> pair({
    required List<DateTime> incomingStarts,
    required List<Dive> plannedDives,
  }) {
    final incoming = [
      for (var i = 0; i < incomingStarts.length; i++)
        (index: i, start: incomingStarts[i].toLocal()),
    ]..sort((a, b) => a.start.compareTo(b.start));
    final plans = [
      for (final d in plannedDives)
        (id: d.id, start: (d.entryTime ?? d.dateTime).toLocal()),
    ]..sort((a, b) => a.start.compareTo(b.start));

    final byDay = <DateTime, List<({String id, DateTime start})>>{};
    for (final p in plans) {
      byDay.putIfAbsent(_day(p.start), () => []).add(p);
    }
    final result = <int, String>{};
    for (final inc in incoming) {
      final candidates = byDay[_day(inc.start)];
      if (candidates == null || candidates.isEmpty) continue;
      final taken = candidates.removeAt(0);
      result[inc.index] = taken.id;
    }
    return result;
  }

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);
}
