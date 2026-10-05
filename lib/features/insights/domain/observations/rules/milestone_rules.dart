import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';
import 'package:submersion/features/insights/domain/observations/observation_thresholds.dart';

const _countLadder = {50, 100, 150, 200, 250, 300, 400, 500};

/// 50, 100, 150, 200, 250, 300, 400, 500, then every 250.
bool isDiveCountMilestone(int n) =>
    _countLadder.contains(n) || (n > 500 && n % 250 == 0);

/// 25, 50, 100, then every 100.
bool isDiveHoursMilestone(int hours) =>
    hours == 25 || hours == 50 || (hours >= 100 && hours % 100 == 0);

/// The largest career dive-count milestone a recent logged dive crossed.
/// Career = prior dives + logged dives, so a milestone the prior count
/// alone reached has no crossing dive and never fires.
List<Observation> diveCountMilestoneRule(ObservationInputs inputs) {
  Observation? latest;
  for (var i = 0; i < inputs.dives.length; i++) {
    final career = inputs.priorDives + i + 1;
    final d = inputs.dives[i];
    if (!isDiveCountMilestone(career) || !inputs.isRecent(d.date)) continue;
    latest = Observation(
      ruleId: ObservationRuleId.diveCountMilestone,
      fingerprint: '$career',
      score: inputs.recencyScore(d.date),
      facts: MilestoneFacts(
        milestone: career,
        includesPrior: inputs.priorDives > 0,
        diveId: d.id,
        date: d.date,
      ),
      target: DiveTarget(d.id),
    );
  }
  return latest == null ? const [] : [latest];
}

/// The largest career-hours milestone a recent logged dive crossed.
List<Observation> diveHoursMilestoneRule(ObservationInputs inputs) {
  Observation? latest;
  var seconds = inputs.priorTimeSeconds;
  var hours = seconds ~/ 3600;
  for (final d in inputs.dives) {
    seconds += d.runtimeSeconds ?? 0;
    final reached = seconds ~/ 3600;
    for (var h = hours + 1; h <= reached; h++) {
      if (!isDiveHoursMilestone(h) || !inputs.isRecent(d.date)) continue;
      latest = Observation(
        ruleId: ObservationRuleId.diveHoursMilestone,
        fingerprint: '$h',
        score: inputs.recencyScore(d.date),
        facts: MilestoneFacts(
          milestone: h,
          includesPrior: inputs.priorTimeSeconds > 0,
          diveId: d.id,
          date: d.date,
        ),
        target: DiveTarget(d.id),
      );
    }
    hours = reached;
  }
  return latest == null ? const [] : [latest];
}

/// The most recent record-setting dive, if it is recent and has at least
/// [ObservationThresholds.recordMinLoggedDives] - 1 measured dives before
/// it, so a new diver's first dives are not each "a new deepest dive".
List<Observation> _record(
  ObservationInputs inputs,
  ObservationRuleId rule,
  double? Function(ObservationDive d) valueOf,
) {
  final measured = [
    for (final d in inputs.dives)
      if ((valueOf(d) ?? 0) > 0) d,
  ];
  if (measured.length < ObservationThresholds.recordMinLoggedDives) {
    return const [];
  }
  var best = valueOf(measured.first)!;
  int? holderIndex;
  var previousBest = 0.0;
  for (var i = 1; i < measured.length; i++) {
    final v = valueOf(measured[i])!;
    if (v > best) {
      holderIndex = i;
      previousBest = best;
      best = v;
    }
  }
  if (holderIndex == null ||
      holderIndex < ObservationThresholds.recordMinLoggedDives - 1) {
    return const [];
  }
  final holder = measured[holderIndex];
  if (!inputs.isRecent(holder.date)) return const [];
  return [
    Observation(
      ruleId: rule,
      fingerprint: holder.id,
      score: inputs.recencyScore(holder.date),
      facts: DiveRecordFacts(
        diveId: holder.id,
        date: holder.date,
        value: best,
        previousBest: previousBest,
      ),
      target: DiveTarget(holder.id),
    ),
  ];
}

List<Observation> deepestDiveRule(ObservationInputs inputs) =>
    _record(inputs, ObservationRuleId.deepestDive, (d) => d.maxDepthM);

List<Observation> longestDiveRule(ObservationInputs inputs) => _record(
  inputs,
  ObservationRuleId.longestDive,
  (d) => d.runtimeSeconds?.toDouble(),
);

/// "New" needs a log that predates the recent window.
bool _logPredatesWindow(ObservationInputs inputs) =>
    inputs.dives.isNotEmpty &&
    !inputs.dives.first.date.isAfter(inputs.recentWindowStart);

List<Observation> newCountryRule(ObservationInputs inputs) {
  if (!_logPredatesWindow(inputs)) return const [];
  final seen = <String>{};
  final out = <Observation>[];
  for (final d in inputs.dives) {
    final country = d.country?.trim();
    if (country == null || country.isEmpty) continue;
    final key = country.toLowerCase();
    if (!seen.add(key) || !inputs.isRecent(d.date)) continue;
    out.add(
      Observation(
        ruleId: ObservationRuleId.newCountry,
        fingerprint: key,
        score: inputs.recencyScore(d.date),
        facts: NewCountryFacts(country: country, diveId: d.id, date: d.date),
        target: const InsightsCategoryTarget('geographic'),
      ),
    );
  }
  return out;
}

List<Observation> newSpeciesRule(ObservationInputs inputs) {
  if (!_logPredatesWindow(inputs)) return const [];
  final fresh =
      [
        for (final s in inputs.species)
          if (inputs.isRecent(s.firstSeen)) s,
      ]..sort((a, b) {
        final byDate = b.firstSeen.compareTo(a.firstSeen);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });
  if (fresh.isEmpty) return const [];
  final newest = fresh.first;
  return [
    Observation(
      ruleId: ObservationRuleId.newSpecies,
      fingerprint: '${fresh.length}:${newest.id}',
      score: inputs.recencyScore(newest.firstSeen),
      facts: NewSpeciesFacts(
        count: fresh.length,
        newestSpeciesId: newest.id,
        newestSpeciesName: newest.name,
        newestDate: newest.firstSeen,
      ),
      target: const InsightsCategoryTarget('marine-life'),
    ),
  ];
}
