import 'dart:math' as math;

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/data/repositories/observation_inputs_queries.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';
import 'package:submersion/features/marine_life/data/repositories/seen_species_repository.dart';

/// Builds [ObservationInputs] for one diver over the whole log, reusing the
/// Insights queries wherever one already returns the data (spec 5.2).
class ObservationInputsLoader {
  ObservationInputsLoader({
    ObservationInputsQueries? queries,
    InsightsRepository? insights,
    SeenSpeciesRepository? species,
  }) : _queries = queries ?? ObservationInputsQueries(),
       _insights = insights ?? InsightsRepository(),
       _species = species ?? SeenSpeciesRepository();

  final ObservationInputsQueries _queries;
  final InsightsRepository _insights;
  final SeenSpeciesRepository _species;

  /// [now] is wall-clock UTC; [diverId] scopes the dives (every diver when
  /// null, as the other Insights pages do) and [diver] supplies the prior
  /// experience that career milestones add to the logged count.
  Future<ObservationInputs> load({
    String? diverId,
    Diver? diver,
    required DateTime now,
  }) async {
    final windows = ObservationInputs(now: now);
    final divesFuture = _queries.dives(diverId: diverId);
    final rmvFuture = _insights.getSacVolumePerDive(diverId: diverId);
    final seenFuture = _species.getSeenSpecies(diverId: diverId);
    final dives = await divesFuture;
    // The ascent rate averages exactly the profiled dives the rule counts:
    // inside (recentStart, now], by instant. A calendar-day filter would
    // also take in a dive later today, which the rules treat as future.
    final rates = await _insights.getAscentDescentRatesForDives([
      for (final d in dives)
        if (d.hasProfile && windows.inRecentYear(d.date)) d.id,
    ]);
    final rmv = await rmvFuture;
    final seen = await seenFuture;
    // A dive dated after now (usually a mistyped year) would otherwise
    // become "the last dive" and silence the dive gap, or hold a record and
    // hide a genuine one. Planned dives are already out of stats scope.
    bool past(DateTime d) => !d.isAfter(now);
    return ObservationInputs(
      now: now,
      dives: [
        for (final d in dives)
          if (past(d.date)) d,
      ],
      rmvPerDive: [
        for (final p in rmv)
          if (p.diveId != null && past(p.date))
            ObservationValue(diveId: p.diveId!, date: p.date, value: p.value),
      ],
      species: [
        for (final s in seen)
          if (past(s.firstSeen))
            ObservationSpecies(
              id: s.species.id,
              name: s.species.commonName,
              firstSeen: s.firstSeen,
            ),
      ],
      priorDives: math.max(0, diver?.priorDiveCount ?? 0),
      priorTimeSeconds: math.max(0, diver?.priorDiveTimeSeconds ?? 0),
      recentAscentRate: rates.avgAscent,
    );
  }
}
