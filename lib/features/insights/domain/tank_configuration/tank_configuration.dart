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
    required this.diveMode,
    required this.tanks,
    this.gasSwitches = const [],
    required this.hasProfile,
  });

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
  });

  factory TankConfigurationStats.fromDives(
    Iterable<TankConfigurationDive> dives,
  ) {
    var total = 0;
    final base = <TankBaseConfiguration, int>{};
    final extras = <TankConfigurationExtra, int>{};
    for (final dive in dives) {
      final result = classifyTankConfiguration(dive);
      total++;
      base.update(result.base, (n) => n + 1, ifAbsent: () => 1);
      for (final extra in result.extras) {
        extras.update(extra, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    return TankConfigurationStats(
      totalDives: total,
      baseCounts: Map.unmodifiable(base),
      extraCounts: Map.unmodifiable(extras),
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

  @override
  List<Object?> get props => [totalDives, baseCounts, extraCounts];
}
