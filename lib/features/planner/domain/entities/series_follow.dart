import 'package:equatable/equatable.dart';

import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A logged dive shown before the planned dives of a series (issue #3565).
class SeriesLoggedDive extends Equatable {
  final String id;
  final int? diveNumber;
  final String? name;
  final DateTime start;
  final DateTime end;

  /// [end] as a true instant, for measuring elapsed time against now. [start]
  /// and [end] are clock digits, like the rest of the dive log.
  final DateTime endInstant;

  /// The OTU of this dive alone, for the rolling daily total: 0 for a dive
  /// that ended too long before the followed one to count.
  final double otu;

  const SeriesLoggedDive({
    required this.id,
    this.diveNumber,
    this.name,
    required this.start,
    required this.end,
    required this.endInstant,
    this.otu = 0,
  });

  SeriesLoggedDive copyWith({
    String? id,
    int? diveNumber,
    String? name,
    DateTime? start,
    DateTime? end,
    DateTime? endInstant,
    double? otu,
  }) {
    return SeriesLoggedDive(
      id: id ?? this.id,
      diveNumber: diveNumber ?? this.diveNumber,
      name: name ?? this.name,
      start: start ?? this.start,
      end: end ?? this.end,
      endInstant: endInstant ?? this.endInstant,
      otu: otu ?? this.otu,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diveNumber,
    name,
    start,
    end,
    endInstant,
    otu,
  ];
}

/// The logged dives a series follows (issue #3565): the followed dive, last,
/// and the dives before it back to the first gap of
/// [followLookback] or more, with what the followed dive leaves behind for
/// the first planned dive.
///
/// Held in memory with the series. A replan of a logged dive keeps its own
/// `sourceDiveId` and never sets this.
class SeriesFollow extends Equatable {
  /// Oldest first; the last is the followed dive.
  final List<SeriesLoggedDive> loggedDives;

  /// The followed dive's end-of-dive compartments; null when it has no
  /// profile to analyse.
  final List<TissueCompartment>? endTissues;

  /// The followed dive's end CNS%, residual from the dives before it included.
  final double endCns;

  /// The followed dive's tanks as logged, end pressures included.
  final List<DiveTank> endTanks;

  /// The first planned dive's own tank start pressures from before it
  /// followed a dive, keyed by tank id: what Fill fills to, and what the
  /// tanks go back to when the dive is no longer followed. A tank added
  /// since, or one that had no pressure, has no entry.
  final Map<String, double> ownStartPressures;

  SeriesFollow({
    required this.loggedDives,
    this.endTissues,
    this.endCns = 0,
    this.endTanks = const [],
    this.ownStartPressures = const {},
  }) : assert(loggedDives.isNotEmpty);

  SeriesLoggedDive get followed => loggedDives.last;

  SeriesFollow copyWith({
    List<SeriesLoggedDive>? loggedDives,
    List<TissueCompartment>? endTissues,
    bool clearEndTissues = false,
    double? endCns,
    List<DiveTank>? endTanks,
    Map<String, double>? ownStartPressures,
  }) {
    return SeriesFollow(
      loggedDives: loggedDives ?? this.loggedDives,
      endTissues: clearEndTissues ? null : (endTissues ?? this.endTissues),
      endCns: endCns ?? this.endCns,
      endTanks: endTanks ?? this.endTanks,
      ownStartPressures: ownStartPressures ?? this.ownStartPressures,
    );
  }

  @override
  List<Object?> get props => [
    loggedDives,
    endTissues,
    endCns,
    endTanks,
    ownStartPressures,
  ];
}

/// How far back a followed dive's earlier dives are shown: back to the first
/// gap this long, the window the dive log uses for residual tissue.
const followLookback = Duration(hours: 48);
