import 'package:equatable/equatable.dart';

class ObservationBuddy extends Equatable {
  final String id;
  final String name;
  const ObservationBuddy({required this.id, required this.name});
  @override
  List<Object?> get props => [id, name];
}

/// One logged dive in stats scope, as the rules see it. Metric units.
class ObservationDive extends Equatable {
  final String id;

  /// Wall-clock UTC, like every stored dive date.
  final DateTime date;
  final double? maxDepthM;

  /// Effective runtime (`effectiveRuntimeSecondsSql`), never bottom time.
  final int? runtimeSeconds;
  final double? weightKg;
  final String? siteId;
  final String? siteName;
  final String? country;

  /// Whether the dive has a primary profile series.
  final bool hasProfile;
  final List<ObservationBuddy> buddies;

  const ObservationDive({
    required this.id,
    required this.date,
    this.maxDepthM,
    this.runtimeSeconds,
    this.weightKg,
    this.siteId,
    this.siteName,
    this.country,
    this.hasProfile = false,
    this.buddies = const [],
  });

  ObservationDive copyWith({
    String? id,
    DateTime? date,
    double? maxDepthM,
    int? runtimeSeconds,
    double? weightKg,
    String? siteId,
    String? siteName,
    String? country,
    bool? hasProfile,
    List<ObservationBuddy>? buddies,
  }) => ObservationDive(
    id: id ?? this.id,
    date: date ?? this.date,
    maxDepthM: maxDepthM ?? this.maxDepthM,
    runtimeSeconds: runtimeSeconds ?? this.runtimeSeconds,
    weightKg: weightKg ?? this.weightKg,
    siteId: siteId ?? this.siteId,
    siteName: siteName ?? this.siteName,
    country: country ?? this.country,
    hasProfile: hasProfile ?? this.hasProfile,
    buddies: buddies ?? this.buddies,
  );

  @override
  List<Object?> get props => [
    id,
    date,
    maxDepthM,
    runtimeSeconds,
    weightKg,
    siteId,
    siteName,
    country,
    hasProfile,
    buddies,
  ];
}

/// A per-dive value from an existing Insights query (RMV in L/min).
class ObservationValue extends Equatable {
  final String diveId;
  final DateTime date;
  final double value;
  const ObservationValue({
    required this.diveId,
    required this.date,
    required this.value,
  });
  @override
  List<Object?> get props => [diveId, date, value];
}

class ObservationSpecies extends Equatable {
  final String id;
  final String name;
  final DateTime firstSeen;
  const ObservationSpecies({
    required this.id,
    required this.name,
    required this.firstSeen,
  });
  @override
  List<Object?> get props => [id, name, firstSeen];
}

/// Everything the rules read, for the whole log of one diver. Lists are
/// oldest first. Immutable, so rules are pure functions of it.
class ObservationInputs extends Equatable {
  /// Wall-clock UTC.
  final DateTime now;
  final List<ObservationDive> dives;
  final List<ObservationValue> rmvPerDive;
  final List<ObservationSpecies> species;
  final int priorDives;
  final int priorTimeSeconds;

  /// Sustained-transit average ascent rate over the last 12 months, m/min;
  /// null when no dive in the window has a profile.
  final double? recentAscentRate;

  const ObservationInputs({
    required this.now,
    this.dives = const [],
    this.rmvPerDive = const [],
    this.species = const [],
    this.priorDives = 0,
    this.priorTimeSeconds = 0,
    this.recentAscentRate,
  });

  ObservationInputs copyWith({
    DateTime? now,
    List<ObservationDive>? dives,
    List<ObservationValue>? rmvPerDive,
    List<ObservationSpecies>? species,
    int? priorDives,
    int? priorTimeSeconds,
    double? recentAscentRate,
  }) => ObservationInputs(
    now: now ?? this.now,
    dives: dives ?? this.dives,
    rmvPerDive: rmvPerDive ?? this.rmvPerDive,
    species: species ?? this.species,
    priorDives: priorDives ?? this.priorDives,
    priorTimeSeconds: priorTimeSeconds ?? this.priorTimeSeconds,
    recentAscentRate: recentAscentRate ?? this.recentAscentRate,
  );

  /// Start (exclusive) of "the last 12 months".
  DateTime get recentStart => DateTime.utc(
    now.year - 1,
    now.month,
    now.day,
    now.hour,
    now.minute,
    now.second,
  );

  /// Start (exclusive) of "the year before".
  DateTime get previousStart => DateTime.utc(
    now.year - 2,
    now.month,
    now.day,
    now.hour,
    now.minute,
    now.second,
  );

  /// Start (exclusive) of "recently", the last 90 days.
  DateTime get recentWindowStart => now.subtract(const Duration(days: 90));

  bool inRecentYear(DateTime d) => d.isAfter(recentStart) && !d.isAfter(now);

  bool inPreviousYear(DateTime d) =>
      d.isAfter(previousStart) && !d.isAfter(recentStart);

  bool isRecent(DateTime d) => d.isAfter(recentWindowStart) && !d.isAfter(now);

  /// 1 for now, falling to 0 at the edge of the 90-day window.
  double recencyScore(DateTime d) =>
      1 - now.difference(d).inMinutes / const Duration(days: 90).inMinutes;

  @override
  List<Object?> get props => [
    now,
    dives,
    rmvPerDive,
    species,
    priorDives,
    priorTimeSeconds,
    recentAscentRate,
  ];
}
