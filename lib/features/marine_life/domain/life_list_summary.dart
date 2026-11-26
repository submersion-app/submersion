import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/wall_clock.dart';

/// The figures of the Species page header (issue #5027).
class LifeListSummary {
  const LifeListSummary({
    required this.total,
    required this.newThisYear,
    required this.growth,
  });

  final int total;

  /// Species first seen in the current calendar year.
  final int newThisYear;

  /// Species seen so far, one point per first-seen day, oldest first.
  final List<({DateTime date, int cumulative})> growth;

  LifeListSummary copyWith({
    int? total,
    int? newThisYear,
    List<({DateTime date, int cumulative})>? growth,
  }) => LifeListSummary(
    total: total ?? this.total,
    newThisYear: newThisYear ?? this.newThisYear,
    growth: growth ?? this.growth,
  );
}

/// Summarizes the whole life list [entries] as of [now].
LifeListSummary summarizeLifeList(
  List<SeenSpecies> entries, {
  required DateTime now,
}) {
  final year = now.year;
  final perDay = <DateTime, int>{};
  var newThisYear = 0;
  for (final entry in entries) {
    final first = wallClock(entry.firstSeen);
    if (first.year == year) newThisYear++;
    final day = DateTime.utc(first.year, first.month, first.day);
    perDay[day] = (perDay[day] ?? 0) + 1;
  }
  final days = perDay.keys.toList()..sort();
  var running = 0;
  return LifeListSummary(
    total: entries.length,
    newThisYear: newThisYear,
    growth: [
      for (final day in days) (date: day, cumulative: running += perDay[day]!),
    ],
  );
}
