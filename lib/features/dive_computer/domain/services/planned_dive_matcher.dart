import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Pairs downloaded dives with a profile's unfilled planned dives (issue
/// #2002). Pure: takes start times and entities, returns an index-to-id map.
///
/// Rule: a download fits a plan on its own calendar day or the day before, so
/// a dive pushed back a day, or a night dive logged after midnight, still
/// fills (issue #4003). Fits are taken smallest start-time gap first, each
/// download and each plan once, so a download just after midnight goes to the
/// previous night's plan rather than the next morning's. Ties go to the
/// earlier download, then the earlier plan. Both start times are the dive's
/// wall clock flagged UTC, so the day is their own date, compared as is:
/// converting them to the device's zone would move the day boundary by its
/// UTC offset and pair dives from different days near midnight. Downloads
/// with no fit stay unpaired; plans with no fit stay unfilled.
class PlannedDiveMatcher {
  const PlannedDiveMatcher();

  Map<int, String> pair({
    required List<DateTime> incomingStarts,
    required List<Dive> plannedDives,
  }) {
    final plans = [
      for (final d in plannedDives)
        (id: d.id, start: d.entryTime ?? d.dateTime),
    ];
    final fits =
        <({int index, DateTime incoming, String plan, DateTime planned})>[
          for (var i = 0; i < incomingStarts.length; i++)
            for (final p in plans)
              if (_fits(incomingStarts[i], p.start))
                (
                  index: i,
                  incoming: incomingStarts[i],
                  plan: p.id,
                  planned: p.start,
                ),
        ]..sort((a, b) {
          final gap = a.incoming
              .difference(a.planned)
              .abs()
              .compareTo(b.incoming.difference(b.planned).abs());
          if (gap != 0) return gap;
          final byIncoming = a.incoming.compareTo(b.incoming);
          if (byIncoming != 0) return byIncoming;
          return a.planned.compareTo(b.planned);
        });

    final result = <int, String>{};
    final taken = <String>{};
    for (final fit in fits) {
      if (result.containsKey(fit.index) || taken.contains(fit.plan)) continue;
      result[fit.index] = fit.plan;
      taken.add(fit.plan);
    }
    return result;
  }

  static bool _fits(DateTime incoming, DateTime planned) {
    final day = _day(planned);
    return day == _day(incoming) ||
        day == DateTime(incoming.year, incoming.month, incoming.day - 1);
  }

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);
}
