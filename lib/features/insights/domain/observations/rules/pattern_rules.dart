import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';
import 'package:submersion/features/insights/domain/observations/observation_thresholds.dart';

typedef _Subject = ({String id, String name});

List<Observation> diveGapRule(ObservationInputs inputs) {
  if (inputs.dives.isEmpty) return const [];
  final last = inputs.dives.last;
  final days = inputs.now.difference(last.date).inDays;
  if (days < ObservationThresholds.diveGapDays) return const [];
  return [
    Observation(
      ruleId: ObservationRuleId.diveGap,
      fingerprint: last.id,
      score: days / 365,
      facts: DiveGapFacts(
        days: days,
        lastDiveId: last.id,
        lastDiveDate: last.date,
      ),
      target: const DiveLogTarget(),
    ),
  ];
}

/// The subject on the most of [subjects]; ties go to the smaller id so the
/// result is deterministic.
({String id, String name, int count})? _top(Iterable<_Subject> subjects) {
  final counts = <String, int>{};
  final names = <String, String>{};
  for (final s in subjects) {
    counts.update(s.id, (n) => n + 1, ifAbsent: () => 1);
    names[s.id] = s.name;
  }
  if (counts.isEmpty) return null;
  final best = counts.entries.reduce((a, b) {
    if (a.value != b.value) return a.value > b.value ? a : b;
    return a.key.compareTo(b.key) <= 0 ? a : b;
  });
  return (id: best.key, name: names[best.key]!, count: best.value);
}

/// One subject's share of the last 12 months' dives (spec section 4.2).
Observation? _share({
  required ObservationRuleId rule,
  required ObservationInputs inputs,
  required Iterable<_Subject> Function(ObservationDive d) subjectsOf,
  required double minShare,
  required ObservationTarget Function(String id) target,
}) {
  final recent = [
    for (final d in inputs.dives)
      if (inputs.inRecentYear(d.date)) d,
  ];
  if (recent.isEmpty) return null;
  final top = _top(recent.expand(subjectsOf));
  if (top == null || top.count < ObservationThresholds.shareMinDives) {
    return null;
  }
  final share = top.count / recent.length;
  if (share < minShare) return null;
  return Observation(
    ruleId: rule,
    fingerprint: top.id,
    score: share,
    facts: ShareFacts(
      subjectId: top.id,
      subjectName: top.name,
      dives: top.count,
      totalDives: recent.length,
    ),
    target: target(top.id),
  );
}

List<Observation> favouriteSiteRule(ObservationInputs inputs) {
  final o = _share(
    rule: ObservationRuleId.favouriteSite,
    inputs: inputs,
    subjectsOf: (d) => [
      if (d.siteId != null) (id: d.siteId!, name: d.siteName ?? ''),
    ],
    minShare: ObservationThresholds.favouriteSiteMinShare,
    target: SiteTarget.new,
  );
  return o == null ? const [] : [o];
}

/// A buddy linked twice to one dive (two roles) counts once for it.
List<Observation> regularBuddyRule(ObservationInputs inputs) {
  final o = _share(
    rule: ObservationRuleId.regularBuddy,
    inputs: inputs,
    subjectsOf: (d) =>
        {for (final b in d.buddies) b.id: (id: b.id, name: b.name)}.values,
    minShare: ObservationThresholds.regularBuddyMinShare,
    target: BuddyTarget.new,
  );
  return o == null ? const [] : [o];
}

/// A calendar month that is the single busiest month in at least two
/// calendar years (each with at least 4 dives). Ties go to the earlier
/// month.
List<Observation> busiestMonthRule(ObservationInputs inputs) {
  final byYear = <int, Map<int, int>>{};
  for (final d in inputs.dives) {
    if (d.date.isAfter(inputs.now)) continue;
    byYear
        .putIfAbsent(d.date.year, () => <int, int>{})
        .update(d.date.month, (n) => n + 1, ifAbsent: () => 1);
  }
  final leads = <int, int>{};
  var yearsConsidered = 0;
  for (final months in byYear.values) {
    final total = months.values.fold<int>(0, (a, b) => a + b);
    if (total < ObservationThresholds.busiestMonthMinDivesPerYear) continue;
    yearsConsidered++;
    final max = months.values.reduce((a, b) => a > b ? a : b);
    final leaders = [
      for (final e in months.entries)
        if (e.value == max) e.key,
    ];
    if (leaders.length != 1) continue;
    leads.update(leaders.single, (n) => n + 1, ifAbsent: () => 1);
  }
  if (leads.isEmpty) return const [];
  final best = leads.entries.reduce((a, b) {
    if (a.value != b.value) return a.value > b.value ? a : b;
    return a.key <= b.key ? a : b;
  });
  if (best.value < ObservationThresholds.busiestMonthMinYears) {
    return const [];
  }
  return [
    Observation(
      ruleId: ObservationRuleId.busiestMonth,
      fingerprint: '${best.key}',
      score: best.value / yearsConsidered,
      facts: MonthFacts(month: best.key, years: best.value),
      target: const InsightsCategoryTarget('time-patterns'),
    ),
  ];
}
