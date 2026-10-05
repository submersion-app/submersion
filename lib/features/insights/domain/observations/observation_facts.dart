import 'package:equatable/equatable.dart';

enum TrendDirection { up, down }

/// The numbers an observation's sentence is built from. Metric values only
/// (metres, seconds, kilograms, L/min, m/min); the presentation layer
/// formats them in the diver's units and language.
sealed class ObservationFacts extends Equatable {
  const ObservationFacts();
}

/// A per-dive mean (or, for frequency, a count) over the last 12 months
/// against the 12 months before.
final class TrendFacts extends ObservationFacts {
  final double recent;
  final double previous;
  final int recentDives;
  final int previousDives;

  const TrendFacts({
    required this.recent,
    required this.previous,
    required this.recentDives,
    required this.previousDives,
  });

  TrendDirection get direction =>
      recent >= previous ? TrendDirection.up : TrendDirection.down;

  /// Signed change from [previous] to [recent], in percent. Zero when
  /// [previous] is zero; the percent rules reject that case themselves.
  double get percentChange =>
      previous == 0 ? 0 : (recent - previous) / previous * 100;

  @override
  List<Object?> get props => [recent, previous, recentDives, previousDives];
}

/// A career count or hours milestone and the logged dive that crossed it.
final class MilestoneFacts extends ObservationFacts {
  final int milestone;
  final bool includesPrior;
  final String diveId;
  final DateTime date;

  const MilestoneFacts({
    required this.milestone,
    required this.includesPrior,
    required this.diveId,
    required this.date,
  });

  @override
  List<Object?> get props => [milestone, includesPrior, diveId, date];
}

/// A new personal record: metres for depth, seconds for runtime.
final class DiveRecordFacts extends ObservationFacts {
  final String diveId;
  final DateTime date;
  final double value;
  final double previousBest;

  const DiveRecordFacts({
    required this.diveId,
    required this.date,
    required this.value,
    required this.previousBest,
  });

  @override
  List<Object?> get props => [diveId, date, value, previousBest];
}

final class NewCountryFacts extends ObservationFacts {
  final String country;
  final String diveId;
  final DateTime date;

  const NewCountryFacts({
    required this.country,
    required this.diveId,
    required this.date,
  });

  @override
  List<Object?> get props => [country, diveId, date];
}

final class NewSpeciesFacts extends ObservationFacts {
  final int count;
  final String newestSpeciesId;
  final String newestSpeciesName;
  final DateTime newestDate;

  const NewSpeciesFacts({
    required this.count,
    required this.newestSpeciesId,
    required this.newestSpeciesName,
    required this.newestDate,
  });

  @override
  List<Object?> get props => [
    count,
    newestSpeciesId,
    newestSpeciesName,
    newestDate,
  ];
}

final class DiveGapFacts extends ObservationFacts {
  final int days;
  final String lastDiveId;
  final DateTime lastDiveDate;

  const DiveGapFacts({
    required this.days,
    required this.lastDiveId,
    required this.lastDiveDate,
  });

  @override
  List<Object?> get props => [days, lastDiveId, lastDiveDate];
}

/// One site or buddy's share of the last 12 months' dives.
final class ShareFacts extends ObservationFacts {
  final String subjectId;
  final String subjectName;
  final int dives;
  final int totalDives;

  const ShareFacts({
    required this.subjectId,
    required this.subjectName,
    required this.dives,
    required this.totalDives,
  });

  @override
  List<Object?> get props => [subjectId, subjectName, dives, totalDives];
}

/// A calendar month (1-12) that led in [years] different years.
final class MonthFacts extends ObservationFacts {
  final int month;
  final int years;

  const MonthFacts({required this.month, required this.years});

  @override
  List<Object?> get props => [month, years];
}

final class RateFacts extends ObservationFacts {
  final double metersPerMin;
  final int dives;

  const RateFacts({required this.metersPerMin, required this.dives});

  @override
  List<Object?> get props => [metersPerMin, dives];
}
