import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart'
    show GasMix;
import 'package:submersion/features/gas_calculators/domain/icd_calculator.dart'
    show IcdSeverity;

/// What a [CounterdiffusionRange] marks (issue #4530).
enum CounterdiffusionKind {
  /// Nitrogen and helium move in opposite directions in at least one
  /// compartment. Normal and intended on a trimix deco; shown only on request.
  opposing,

  /// Isobaric counterdiffusion proper: in at least one compartment the gases
  /// move in opposite directions, the tissue already holds at least as much
  /// inert gas as is breathed, and still takes gas up net, because one gas
  /// enters faster than the other leaves.
  netOngassing,
}

/// A span of the dive, in seconds from dive start, in which [kind] holds.
class CounterdiffusionRange extends Equatable {
  final int startSeconds;
  final int endSeconds;
  final CounterdiffusionKind kind;

  /// Compartment numbers (1-16, ascending) that met [kind] somewhere in the
  /// span.
  final List<int> compartmentNumbers;

  const CounterdiffusionRange({
    required this.startSeconds,
    required this.endSeconds,
    required this.kind,
    required this.compartmentNumbers,
  });

  /// Whether [timestamp] lies inside the span, edges included.
  bool contains(int timestamp) =>
      timestamp >= startSeconds && timestamp <= endSeconds;

  CounterdiffusionRange copyWith({
    int? startSeconds,
    int? endSeconds,
    CounterdiffusionKind? kind,
    List<int>? compartmentNumbers,
  }) => CounterdiffusionRange(
    startSeconds: startSeconds ?? this.startSeconds,
    endSeconds: endSeconds ?? this.endSeconds,
    kind: kind ?? this.kind,
    compartmentNumbers: compartmentNumbers ?? this.compartmentNumbers,
  );

  @override
  List<Object?> get props => [
    startSeconds,
    endSeconds,
    kind,
    compartmentNumbers,
  ];
}

/// A gas switch that reads [IcdSeverity.caution] or [IcdSeverity.violation]
/// against the rule of fifths.
class IcdSwitchMarker extends Equatable {
  /// Seconds from dive start at which the new gas becomes active.
  final int timestamp;
  final IcdSeverity severity;

  /// The gas breathed before the switch; on a rebreather the loop's mix at
  /// the switch depth.
  final GasMix from;
  final GasMix to;

  const IcdSwitchMarker({
    required this.timestamp,
    required this.severity,
    required this.from,
    required this.to,
  });

  IcdSwitchMarker copyWith({
    int? timestamp,
    IcdSeverity? severity,
    GasMix? from,
    GasMix? to,
  }) => IcdSwitchMarker(
    timestamp: timestamp ?? this.timestamp,
    severity: severity ?? this.severity,
    from: from ?? this.from,
    to: to ?? this.to,
  );

  @override
  List<Object?> get props => [timestamp, severity, from, to];
}

/// Everything the profile and the safety review show about counterdiffusion
/// on one dive.
class CounterdiffusionAnalysis extends Equatable {
  /// [CounterdiffusionKind.netOngassing] spans, sorted by start.
  final List<CounterdiffusionRange> icdRanges;

  /// [CounterdiffusionKind.opposing] spans, sorted by start. They cover the
  /// ICD spans too, since those also move in opposite directions.
  final List<CounterdiffusionRange> opposingRanges;

  /// Rule-of-fifths cautions and violations at gas switches, by time.
  final List<IcdSwitchMarker> switchMarkers;

  /// Whether helium is breathed or held in any compartment at any sample.
  /// Without it no counterdiffusion can happen, and the chart option is not
  /// offered.
  final bool heliumPresent;

  const CounterdiffusionAnalysis({
    this.icdRanges = const [],
    this.opposingRanges = const [],
    this.switchMarkers = const [],
    this.heliumPresent = false,
  });

  static const CounterdiffusionAnalysis none = CounterdiffusionAnalysis();

  CounterdiffusionAnalysis copyWith({
    List<CounterdiffusionRange>? icdRanges,
    List<CounterdiffusionRange>? opposingRanges,
    List<IcdSwitchMarker>? switchMarkers,
    bool? heliumPresent,
  }) => CounterdiffusionAnalysis(
    icdRanges: icdRanges ?? this.icdRanges,
    opposingRanges: opposingRanges ?? this.opposingRanges,
    switchMarkers: switchMarkers ?? this.switchMarkers,
    heliumPresent: heliumPresent ?? this.heliumPresent,
  );

  @override
  List<Object?> get props => [
    icdRanges,
    opposingRanges,
    switchMarkers,
    heliumPresent,
  ];
}
