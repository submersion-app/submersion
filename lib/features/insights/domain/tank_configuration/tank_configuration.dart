import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/insights/domain/tank_configuration/tank_configuration_classifier.dart';

/// How a dive's cylinders were carried (issue #3421). Every dive has exactly
/// one; see [classifyTankConfiguration] for the order the rules are checked.
enum TankBaseConfiguration {
  rebreather,
  sidemount,
  twinBackmount,
  singleBackmount,
  other,
  noTanks,
}

/// What a dive carried beyond its base configuration. A dive can have any
/// number of these, so their counts are not shares of a whole.
enum TankConfigurationExtra { stages, decoGas, multiGas }

/// The base configuration and extras of one dive.
typedef TankConfigurationResult = ({
  TankBaseConfiguration base,
  Set<TankConfigurationExtra> extras,
});

/// What the classifier reads from one dive: the cylinders that count (a
/// consolidated dive's primary computer's plus any added by hand), its gas
/// switches in seconds from the dive's start, and whether it has a recorded
/// profile, which decides how much a missing switch says.
class TankConfigurationDive {
  const TankConfigurationDive({
    required this.diveId,
    required this.diveMode,
    required this.tanks,
    this.gasSwitches = const [],
    required this.hasProfile,
  });

  final String diveId;
  final DiveMode diveMode;
  final List<DiveTank> tanks;
  final List<({String tankId, int timestamp})> gasSwitches;
  final bool hasProfile;
}

/// Dive counts per base configuration and per extra, over [totalDives]
/// dives. Both maps hold only non-zero counts.
class TankConfigurationStats extends Equatable {
  const TankConfigurationStats({
    required this.totalDives,
    required this.baseCounts,
    required this.extraCounts,
    this.baseDiveIds = const {},
    this.extraDiveIds = const {},
  });

  factory TankConfigurationStats.fromDives(
    Iterable<TankConfigurationDive> dives,
  ) {
    var total = 0;
    final base = <TankBaseConfiguration, List<String>>{};
    final extras = <TankConfigurationExtra, List<String>>{};
    for (final dive in dives) {
      final result = classifyTankConfiguration(dive);
      total++;
      (base[result.base] ??= []).add(dive.diveId);
      for (final extra in result.extras) {
        (extras[extra] ??= []).add(dive.diveId);
      }
    }
    return TankConfigurationStats(
      totalDives: total,
      baseCounts: Map.unmodifiable({
        for (final e in base.entries) e.key: e.value.length,
      }),
      extraCounts: Map.unmodifiable({
        for (final e in extras.entries) e.key: e.value.length,
      }),
      baseDiveIds: Map.unmodifiable(base),
      extraDiveIds: Map.unmodifiable(extras),
    );
  }

  static const empty = TankConfigurationStats(
    totalDives: 0,
    baseCounts: {},
    extraCounts: {},
  );

  final int totalDives;
  final Map<TankBaseConfiguration, int> baseCounts;
  final Map<TankConfigurationExtra, int> extraCounts;

  /// The dives behind each count (issue #3805).
  final Map<TankBaseConfiguration, List<String>> baseDiveIds;
  final Map<TankConfigurationExtra, List<String>> extraDiveIds;

  @override
  List<Object?> get props => [
    totalDives,
    baseCounts,
    extraCounts,
    baseDiveIds,
    extraDiveIds,
  ];
}
