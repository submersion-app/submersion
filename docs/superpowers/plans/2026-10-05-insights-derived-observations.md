# Insights Derived Observations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (the maintainer chose inline execution). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the diver's whole log into short, ranked, dismissible sentences shown at the top of Insights and on a new Observations page.

**Architecture:** Pure rule functions evaluate an immutable inputs snapshot loaded from existing and new read-only queries; an engine runs the rules, drops muted rules and dismissed fingerprints, and ranks the result. Only dismissals (a synced table with deterministic ids) and mutes (a JSON column on `diver_settings`) persist, in one schema rung, 261.

**Tech Stack:** Flutter, Riverpod 3 (`package:submersion/core/providers/provider.dart`), Drift, `package:clock`, `package:crypto`, ARB l10n (11 locales).

**Spec:** `docs/superpowers/specs/2026-10-05-insights-derived-observations-design.md`

## Global Constraints

- Every rule reads the WHOLE log of the active diver: never watch or apply `insightsFilterProvider`; always apply `DiveStatsScope`.
- Dates of dives are wall-clock UTC (`wallClockUtcFromMillis`); "now" is `asWallClockUtc(clock.now())`. Rules take `now` from the inputs, never call the clock.
- Rule ids are stored values: `ObservationRuleId.dbValue == name`; never rename one. Unknown ids are ignored on read and preserved on write.
- Dismissal row id: `od_` + SHA-1 hex of `'$diverId|${rule.dbValue}|$fingerprint'`. Undo sets `dismissed_at` to null; the feature never deletes rows.
- Schema 261 is additive: `minimumCompatibleSchemaVersion` stays 240; no existing settings row is rewritten.
- The litres-per-minute lane is "RMV" in user-facing text; "SAC" is the pressure lane. Format with `UnitFormatter.formatRmv`, `formatDepth`, `formatWeight`, `formatDepthRate`, `formatDate`; never write "/min" into a string (`test/architecture/rate_unit_single_source_test.dart`).
- Every new string exists in all 11 ARB files (`lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`); Arabic plurals carry zero/one/two/few/many/other; fr and pt `=1{}` branches interpolate `{count}`. Regenerate with `flutter gen-l10n` and commit the generated files.
- No em-dashes or en-dashes as punctuation anywhere; no emojis; files 200-400 lines typical, 800 max (`test/core/database/database_table_libraries_test.dart` enforces 800 under `lib/core/database/tables/` and `migrations/`).
- A bare `build` token in a Bash command is refused here: run codegen through `scratchpad/init.sh`-style scripts (`dart run build_runner build --delete-conflicting-outputs`).
- Before each commit: `dart format .`, `flutter analyze` (zero issues, infos included), the task's tests; after adding any `lib/` file also `flutter test test/architecture/`.

## Review Focus

1. **A log that starts inside the previous 12-month window** must not produce "you logged N% more dives": the frequency trend requires the first logged dive to predate the previous window (test in Task 3).
2. **Dives dated after now** (a future-dated, unplanned dive) must not count in the "last 12 months" window and must not produce a negative dive gap (tests in Tasks 3 and 5).
3. **A diver with only prior experience and no logged dives, or no current diver at all,** gets an empty list, no crash, no milestone (test in Task 4; provider test in Task 12).
4. **Unknown rule ids from a newer build,** in a dismissal row or in the muted list, are ignored when reading and preserved when writing (tests in Tasks 10 and 11).
5. **Imperial units and comma-decimal locales** render every sentence in the diver's units with no hard-coded unit text (test in Task 13).

---

## File Structure

| Path | Responsibility |
| --- | --- |
| `lib/features/insights/domain/observations/observation_rule_id.dart` | `ObservationKind`, `ObservationRuleId` (stored ids, kind mapping) |
| `lib/features/insights/domain/observations/observation_facts.dart` | Sealed facts per observation shape, numbers only |
| `lib/features/insights/domain/observations/observation_target.dart` | Sealed tap targets |
| `lib/features/insights/domain/observations/observation.dart` | Entity, `observationKey`, `observationDismissalId` |
| `lib/features/insights/domain/observations/observation_inputs.dart` | Inputs snapshot and window helpers |
| `lib/features/insights/domain/observations/observation_thresholds.dart` | Every threshold from spec section 4 |
| `lib/features/insights/domain/observations/effect_size.dart` | Mean and pooled-SD effect size |
| `lib/features/insights/domain/observations/rules/trend_rules.dart` | Five trend rules |
| `lib/features/insights/domain/observations/rules/milestone_rules.dart` | Six milestone rules |
| `lib/features/insights/domain/observations/rules/pattern_rules.dart` | Four pattern rules |
| `lib/features/insights/domain/observations/rules/safety_rules.dart` | Ascent rate rule |
| `lib/features/insights/domain/observations/observation_engine.dart` | Rule registry, run, ranking, strip selection |
| `lib/core/database/tables/insight_tables.dart` | `InsightObservationDismissals` table |
| `lib/core/database/migrations/helpers/insight_migrations.dart` | Rung 261 schema asserts |
| `lib/features/insights/data/repositories/observation_inputs_queries.dart` | New SQL: per-dive rows and buddies |
| `lib/features/insights/data/observation_inputs_loader.dart` | Builds `ObservationInputs` |
| `lib/features/insights/data/repositories/observation_dismissals_repository.dart` | Dismiss, undismiss, watch keys, sync marks |
| `lib/features/insights/presentation/providers/observations_providers.dart` | Inputs, dismissed keys, observations, strip, actions |
| `lib/features/insights/presentation/formatters/observation_sentence.dart` | Facts to localized sentence, rule labels, month names |
| `lib/features/insights/presentation/widgets/observation_card.dart` | One observation with actions |
| `lib/features/insights/presentation/widgets/observations_strip.dart` | Top-3 strip |
| `lib/features/insights/presentation/widgets/muted_observation_kinds_sheet.dart` | Muted kinds sheet |
| `lib/features/insights/presentation/pages/insights_observations_page.dart` | Full page |

Modified: `database.dart`, `tables/diver_tables.dart`, `migrations/app_database_migrations.dart`, `migrations/helpers/diver_migrations.dart` (or the new helper), `migrations/ladder/rungs_v231_onward.dart`, `migrations/before_open.dart`, `sync_data_serializer.dart`, `sync_service.dart`, `sync_repository.dart`, `diver_delete_steps.dart`, `settings_providers.dart`, `diver_settings_repository.dart`, `app_router.dart`, `insights_page.dart`, `insights_overview_page.dart`, the 11 ARB files, test mocks.

---

### Task 1: Observation domain types

**Files:**
- Create: `lib/features/insights/domain/observations/observation_rule_id.dart`
- Create: `lib/features/insights/domain/observations/observation_facts.dart`
- Create: `lib/features/insights/domain/observations/observation_target.dart`
- Create: `lib/features/insights/domain/observations/observation.dart`
- Test: `test/features/insights/domain/observations/observation_test.dart`

**Interfaces:**
- Produces: `enum ObservationKind { safety, milestone, trend, pattern }`; `enum ObservationRuleId` with `dbValue`, `static ObservationRuleId? fromDbValue(String)`, `ObservationKind get kind`; facts classes `TrendFacts`, `MilestoneFacts`, `DiveRecordFacts`, `NewCountryFacts`, `NewSpeciesFacts`, `DiveGapFacts`, `ShareFacts`, `MonthFacts`, `RateFacts`; `enum TrendDirection { up, down }`; targets `InsightsCategoryTarget(categoryId)`, `DiveTarget(diveId)`, `SiteTarget(siteId)`, `BuddyTarget(buddyId)`, `DiveLogTarget()`; `class Observation { ruleId, fingerprint, score, facts, target; kind; key; copyWith }`; `String observationKey(ObservationRuleId, String)`; `String observationDismissalId(String diverId, ObservationRuleId rule, String fingerprint)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';

void main() {
  group('ObservationRuleId', () {
    test('dbValue round-trips and unknown ids are null', () {
      for (final rule in ObservationRuleId.values) {
        expect(ObservationRuleId.fromDbValue(rule.dbValue), rule);
      }
      expect(ObservationRuleId.fromDbValue('fromANewerBuild'), isNull);
    });

    test('kinds follow the spec catalog', () {
      expect(ObservationRuleId.ascentRate.kind, ObservationKind.safety);
      expect(ObservationRuleId.rmvTrend.kind, ObservationKind.trend);
      expect(ObservationRuleId.frequencyTrend.kind, ObservationKind.trend);
      expect(ObservationRuleId.newSpecies.kind, ObservationKind.milestone);
      expect(ObservationRuleId.busiestMonth.kind, ObservationKind.pattern);
      final byKind = <ObservationKind, int>{};
      for (final r in ObservationRuleId.values) {
        byKind.update(r.kind, (n) => n + 1, ifAbsent: () => 1);
      }
      expect(byKind, {
        ObservationKind.safety: 1,
        ObservationKind.milestone: 6,
        ObservationKind.trend: 5,
        ObservationKind.pattern: 4,
      });
    });
  });

  group('TrendFacts', () {
    test('direction and signed percent change', () {
      const down = TrendFacts(
        recent: 15, previous: 20, recentDives: 9, previousDives: 9);
      expect(down.direction, TrendDirection.down);
      expect(down.percentChange, closeTo(-25, 1e-9));
      const flatZero = TrendFacts(
        recent: 3, previous: 0, recentDives: 9, previousDives: 9);
      expect(flatZero.percentChange, 0);
    });
  });

  group('identity', () {
    test('key and dismissal id are deterministic', () {
      final o = Observation(
        ruleId: ObservationRuleId.rmvTrend,
        fingerprint: 'down:1',
        score: 0.8,
        facts: const TrendFacts(
            recent: 15, previous: 20, recentDives: 9, previousDives: 9),
        target: const InsightsCategoryTarget('gas'),
      );
      expect(o.key, 'rmvTrend:down:1');
      expect(o.kind, ObservationKind.trend);
      final a = observationDismissalId('diver-1', o.ruleId, o.fingerprint);
      final b = observationDismissalId('diver-1', o.ruleId, o.fingerprint);
      expect(a, b);
      expect(a, startsWith('od_'));
      expect(a.length, 3 + 40);
      expect(observationDismissalId('diver-2', o.ruleId, o.fingerprint),
          isNot(a));
      expect(o.copyWith(score: 2).score, 2);
      expect(o.copyWith(score: 2).key, o.key);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/insights/domain/observations/observation_test.dart`
Expected: FAIL, the imported files do not exist.

- [ ] **Step 3: Write the implementation**

`observation_rule_id.dart`:

```dart
/// What an observation is about. The declaration order is the ranking tier
/// order (spec section 4.4): safety first, patterns last.
enum ObservationKind { safety, milestone, trend, pattern }

/// The rule that produced an observation. Names are the stored values (the
/// dismissal rows and the muted-rules setting), so a rule is never renamed.
enum ObservationRuleId {
  rmvTrend,
  maxDepthTrend,
  diveTimeTrend,
  weightTrend,
  frequencyTrend,
  diveCountMilestone,
  diveHoursMilestone,
  deepestDive,
  longestDive,
  newCountry,
  newSpecies,
  diveGap,
  favouriteSite,
  regularBuddy,
  busiestMonth,
  ascentRate;

  String get dbValue => name;

  /// Null for a rule this build does not know (written by a newer peer), so
  /// the caller skips it rather than mislabel it.
  static ObservationRuleId? fromDbValue(String value) {
    for (final rule in values) {
      if (rule.name == value) return rule;
    }
    return null;
  }

  ObservationKind get kind => switch (this) {
    ObservationRuleId.ascentRate => ObservationKind.safety,
    ObservationRuleId.diveCountMilestone ||
    ObservationRuleId.diveHoursMilestone ||
    ObservationRuleId.deepestDive ||
    ObservationRuleId.longestDive ||
    ObservationRuleId.newCountry ||
    ObservationRuleId.newSpecies => ObservationKind.milestone,
    ObservationRuleId.rmvTrend ||
    ObservationRuleId.maxDepthTrend ||
    ObservationRuleId.diveTimeTrend ||
    ObservationRuleId.weightTrend ||
    ObservationRuleId.frequencyTrend => ObservationKind.trend,
    ObservationRuleId.diveGap ||
    ObservationRuleId.favouriteSite ||
    ObservationRuleId.regularBuddy ||
    ObservationRuleId.busiestMonth => ObservationKind.pattern,
  };
}
```

`observation_facts.dart`:

```dart
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
  List<Object?> get props =>
      [count, newestSpeciesId, newestSpeciesName, newestDate];
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
```

`observation_target.dart`:

```dart
import 'package:equatable/equatable.dart';

/// Where tapping an observation goes.
sealed class ObservationTarget extends Equatable {
  const ObservationTarget();
}

/// An Insights category page, by its category id ('gas', 'progression').
final class InsightsCategoryTarget extends ObservationTarget {
  final String categoryId;
  const InsightsCategoryTarget(this.categoryId);
  @override
  List<Object?> get props => [categoryId];
}

final class DiveTarget extends ObservationTarget {
  final String diveId;
  const DiveTarget(this.diveId);
  @override
  List<Object?> get props => [diveId];
}

final class SiteTarget extends ObservationTarget {
  final String siteId;
  const SiteTarget(this.siteId);
  @override
  List<Object?> get props => [siteId];
}

final class BuddyTarget extends ObservationTarget {
  final String buddyId;
  const BuddyTarget(this.buddyId);
  @override
  List<Object?> get props => [buddyId];
}

final class DiveLogTarget extends ObservationTarget {
  const DiveLogTarget();
  @override
  List<Object?> get props => const [];
}
```

`observation.dart`:

```dart
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';

import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';

/// One derived observation. [fingerprint] holds only the facts that matter
/// for dismissal (spec section 4.2): a dismissed observation returns when
/// its fingerprint changes. [score] orders observations within a kind.
class Observation extends Equatable {
  final ObservationRuleId ruleId;
  final String fingerprint;
  final double score;
  final ObservationFacts facts;
  final ObservationTarget target;

  const Observation({
    required this.ruleId,
    required this.fingerprint,
    required this.score,
    required this.facts,
    required this.target,
  });

  ObservationKind get kind => ruleId.kind;

  String get key => observationKey(ruleId, fingerprint);

  Observation copyWith({
    ObservationRuleId? ruleId,
    String? fingerprint,
    double? score,
    ObservationFacts? facts,
    ObservationTarget? target,
  }) => Observation(
    ruleId: ruleId ?? this.ruleId,
    fingerprint: fingerprint ?? this.fingerprint,
    score: score ?? this.score,
    facts: facts ?? this.facts,
    target: target ?? this.target,
  );

  @override
  List<Object?> get props => [ruleId, fingerprint, score, facts, target];
}

/// The identity a dismissal matches on.
String observationKey(ObservationRuleId rule, String fingerprint) =>
    '${rule.dbValue}:$fingerprint';

/// The deterministic dismissal row id. Two devices that dismiss the same
/// observation write the same row, so sync merges it with a plain upsert.
String observationDismissalId(
  String diverId,
  ObservationRuleId rule,
  String fingerprint,
) =>
    'od_${sha1.convert(utf8.encode('$diverId|${rule.dbValue}|$fingerprint'))}';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/insights/domain/observations/observation_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/insights/domain/observations test/features/insights/domain/observations
git add lib/features/insights/domain/observations test/features/insights/domain/observations
git commit -m "feat(insights): observation domain types"
```

---

### Task 2: Inputs snapshot, thresholds and effect size

**Files:**
- Create: `lib/features/insights/domain/observations/observation_inputs.dart`
- Create: `lib/features/insights/domain/observations/observation_thresholds.dart`
- Create: `lib/features/insights/domain/observations/effect_size.dart`
- Test: `test/features/insights/domain/observations/observation_inputs_test.dart`
- Create: `test/features/insights/domain/observations/observation_fixtures.dart` (shared test builders)

**Interfaces:**
- Consumes: nothing.
- Produces: `ObservationBuddy({id, name})`; `ObservationDive({id, date, maxDepthM, runtimeSeconds, weightKg, siteId, siteName, country, hasProfile = false, buddies = const []})`; `ObservationValue({diveId, date, value})`; `ObservationSpecies({id, name, firstSeen})`; `ObservationInputs({now, dives, rmvPerDive, species, priorDives = 0, priorTimeSeconds = 0, recentAscentRate})` with `recentStart`, `previousStart`, `recentWindowStart`, `inRecentYear(DateTime)`, `inPreviousYear(DateTime)`, `isRecent(DateTime)`, `recencyScore(DateTime)`; `abstract final class ObservationThresholds` constants; `double meanOf(List<double>)`, `double? effectSize(List<double>, List<double>)`. Test fixtures: `ObservationDive dive(String id, DateTime date, {...})`, `final now = DateTime.utc(2026, 10, 5, 12)`.

- [ ] **Step 1: Write the failing test and fixtures**

`observation_fixtures.dart`:

```dart
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';

/// "Now" for every rule test: wall-clock UTC, a Monday.
final now = DateTime.utc(2026, 10, 5, 12);

DateTime daysAgo(int days) => now.subtract(Duration(days: days));

ObservationDive dive(
  String id,
  DateTime date, {
  double? maxDepthM,
  int? runtimeSeconds,
  double? weightKg,
  String? siteId,
  String? siteName,
  String? country,
  bool hasProfile = false,
  List<ObservationBuddy> buddies = const [],
}) => ObservationDive(
  id: id,
  date: date,
  maxDepthM: maxDepthM,
  runtimeSeconds: runtimeSeconds,
  weightKg: weightKg,
  siteId: siteId,
  siteName: siteName,
  country: country,
  hasProfile: hasProfile,
  buddies: buddies,
);

/// [count] dives spread evenly through the window that ends [endDaysAgo]
/// days ago and spans [spanDays] days, oldest first.
List<ObservationDive> divesIn({
  required String prefix,
  required int count,
  required int endDaysAgo,
  int spanDays = 300,
  ObservationDive Function(String id, DateTime date)? build,
}) => [
  for (var k = count - 1; k >= 0; k--)
    (build ?? (id, date) => dive(id, date))(
      '$prefix-$k',
      daysAgo(endDaysAgo + (spanDays * k) ~/ count),
    ),
];
```

`observation_inputs_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/observations/effect_size.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';

import 'observation_fixtures.dart';

void main() {
  final inputs = ObservationInputs(now: now);

  test('windows are calendar years back from now', () {
    expect(inputs.recentStart, DateTime.utc(2025, 10, 5, 12));
    expect(inputs.previousStart, DateTime.utc(2024, 10, 5, 12));
    expect(inputs.recentWindowStart, DateTime.utc(2026, 7, 7, 12));
  });

  test('membership excludes the future and is half-open', () {
    expect(inputs.inRecentYear(daysAgo(1)), isTrue);
    expect(inputs.inRecentYear(now.add(const Duration(days: 1))), isFalse);
    expect(inputs.inRecentYear(inputs.recentStart), isFalse);
    expect(inputs.inPreviousYear(inputs.recentStart), isTrue);
    expect(inputs.isRecent(daysAgo(89)), isTrue);
    expect(inputs.isRecent(daysAgo(91)), isFalse);
    expect(inputs.isRecent(now.add(const Duration(hours: 1))), isFalse);
  });

  test('recency score is 1 now and 0 at the window edge', () {
    expect(inputs.recencyScore(now), closeTo(1, 1e-9));
    expect(inputs.recencyScore(daysAgo(90)), closeTo(0, 1e-9));
  });

  group('effectSize', () {
    test('null below two samples per side', () {
      expect(effectSize([1], [1, 2]), isNull);
    });
    test('pooled standard deviation', () {
      // means 2 and 4, each sample variance 1, pooled sd 1 => d = 2
      expect(effectSize([1, 2, 3], [3, 4, 5]), closeTo(2, 1e-9));
    });
    test('zero spread: infinite unless equal', () {
      expect(effectSize([2, 2], [3, 3]), double.infinity);
      expect(effectSize([2, 2], [2, 2]), 0);
    });
    test('meanOf', () => expect(meanOf([1, 2, 3, 6]), 3));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/insights/domain/observations/observation_inputs_test.dart`
Expected: FAIL, missing imports.

- [ ] **Step 3: Write the implementation**

`observation_inputs.dart`:

```dart
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

  @override
  List<Object?> get props => [
    id, date, maxDepthM, runtimeSeconds, weightKg, siteId, siteName,
    country, hasProfile, buddies,
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

  /// Start (exclusive) of "the last 12 months".
  DateTime get recentStart => DateTime.utc(
    now.year - 1, now.month, now.day, now.hour, now.minute, now.second,
  );

  /// Start (exclusive) of "the year before".
  DateTime get previousStart => DateTime.utc(
    now.year - 2, now.month, now.day, now.hour, now.minute, now.second,
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
    now, dives, rmvPerDive, species, priorDives, priorTimeSeconds,
    recentAscentRate,
  ];
}
```

`observation_thresholds.dart`:

```dart
/// Every threshold in the observations spec (section 4), in one place.
abstract final class ObservationThresholds {
  static const trendMinDivesPerPeriod = 8;
  static const trendMinEffectSize = 0.5;
  static const rmvMinPercent = 8.0;
  static const maxDepthMinPercent = 15.0;
  static const diveTimeMinPercent = 15.0;
  static const weightMinKg = 1.0;
  static const frequencyMinPercent = 30.0;
  static const frequencyMinDives = 6;
  static const percentBandWidth = 10.0;
  static const weightBandKg = 1.0;
  static const recordMinLoggedDives = 10;
  static const diveGapDays = 90;
  static const favouriteSiteMinShare = 0.25;
  static const regularBuddyMinShare = 0.40;
  static const shareMinDives = 5;
  static const busiestMonthMinYears = 2;
  static const busiestMonthMinDivesPerYear = 4;
  static const ascentRateGuidanceLowMPerMin = 9.0;
  static const ascentRateGuidanceHighMPerMin = 10.0;
  static const ascentRateMinDives = 5;
  static const stripSize = 3;
  static const stripMaxPerKind = 2;
}
```

`effect_size.dart`:

```dart
import 'dart:math' as math;

double meanOf(List<double> values) =>
    values.fold<double>(0, (sum, v) => sum + v) / values.length;

/// |mean(a) - mean(b)| over the pooled sample standard deviation (Cohen's
/// d). Null with fewer than two samples on either side. Infinite when
/// neither side varies but the means differ.
double? effectSize(List<double> a, List<double> b) {
  if (a.length < 2 || b.length < 2) return null;
  final ma = meanOf(a);
  final mb = meanOf(b);
  double squares(List<double> v, double m) =>
      v.fold<double>(0, (s, x) => s + (x - m) * (x - m));
  final pooled = math.sqrt(
    (squares(a, ma) + squares(b, mb)) / (a.length + b.length - 2),
  );
  final diff = (ma - mb).abs();
  if (pooled == 0) return diff == 0 ? 0 : double.infinity;
  return diff / pooled;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/insights/domain/observations/observation_inputs_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/insights/domain/observations test/features/insights/domain/observations
git add lib/features/insights/domain/observations test/features/insights/domain/observations
git commit -m "feat(insights): observation inputs, thresholds and effect size"
```

---

### Task 3: Trend rules

**Files:**
- Create: `lib/features/insights/domain/observations/rules/trend_rules.dart`
- Test: `test/features/insights/domain/observations/rules/trend_rules_test.dart`

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces: `List<Observation> rmvTrendRule(ObservationInputs)`, `maxDepthTrendRule`, `diveTimeTrendRule`, `weightTrendRule`, `frequencyTrendRule` (all `List<Observation> Function(ObservationInputs)`).

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';
import 'package:submersion/features/insights/domain/observations/rules/trend_rules.dart';

import '../observation_fixtures.dart';

/// [n] values per period with mean [recent]/[previous] and spread +-[jitter].
List<ObservationValue> rmvSeries({
  required int n,
  required double recent,
  required double previous,
  double jitter = 1,
  int? previousN,
}) => [
  for (var k = 0; k < (previousN ?? n); k++)
    ObservationValue(
      diveId: 'p$k',
      date: daysAgo(400 + k * 30),
      value: previous + (k.isEven ? jitter : -jitter),
    ),
  for (var k = 0; k < n; k++)
    ObservationValue(
      diveId: 'r$k',
      date: daysAgo(10 + k * 30),
      value: recent + (k.isEven ? jitter : -jitter),
    ),
]..sort((a, b) => a.date.compareTo(b.date));

void main() {
  group('rmvTrendRule', () {
    test('fires on a clear 25% drop with a stable fingerprint', () {
      final out = rmvTrendRule(ObservationInputs(
        now: now, rmvPerDive: rmvSeries(n: 8, recent: 15, previous: 20)));
      expect(out, hasLength(1));
      final facts = out.single.facts as TrendFacts;
      expect(facts.direction, TrendDirection.down);
      expect(facts.percentChange, closeTo(-25, 1e-9));
      expect(out.single.fingerprint, 'down:2');
      expect(out.single.target, const InsightsCategoryTarget('gas'));
    });

    test('silent below 8 dives in a period', () {
      expect(
        rmvTrendRule(ObservationInputs(now: now,
            rmvPerDive: rmvSeries(n: 8, previousN: 7, recent: 15, previous: 20))),
        isEmpty,
      );
    });

    test('silent below the 8% minimum', () {
      // 18.7 vs 20 is 6.5% lower
      expect(
        rmvTrendRule(ObservationInputs(now: now,
            rmvPerDive: rmvSeries(n: 8, recent: 18.7, previous: 20, jitter: 0.1))),
        isEmpty,
      );
    });

    test('silent when noise swamps the change (effect size < 0.5)', () {
      // 10% change, spread 10 => d about 0.2
      expect(
        rmvTrendRule(ObservationInputs(now: now,
            rmvPerDive: rmvSeries(n: 8, recent: 18, previous: 20, jitter: 10))),
        isEmpty,
      );
    });

    test('future-dated values are not in the last 12 months', () {
      final series = rmvSeries(n: 8, recent: 15, previous: 20)
        ..removeWhere((v) => v.diveId == 'r0');
      final withFuture = [
        ...series,
        ObservationValue(diveId: 'future', date: now.add(const Duration(days: 3)), value: 1),
      ];
      // 7 real recent values + 1 future one: below the 8-dive minimum.
      expect(rmvTrendRule(ObservationInputs(now: now, rmvPerDive: withFuture)), isEmpty);
    });
  });

  test('maxDepthTrendRule: 20% deeper fires, band 2', () {
    final dives = [
      for (var k = 0; k < 8; k++)
        dive('p$k', daysAgo(400 + k * 30), maxDepthM: k.isEven ? 21 : 19),
      for (var k = 0; k < 8; k++)
        dive('r$k', daysAgo(10 + k * 30), maxDepthM: k.isEven ? 25 : 23),
    ]..sort((a, b) => a.date.compareTo(b.date));
    final out = maxDepthTrendRule(ObservationInputs(now: now, dives: dives));
    expect(out.single.fingerprint, 'up:2');
    expect(out.single.target, const InsightsCategoryTarget('progression'));
  });

  test('diveTimeTrendRule uses runtime minutes and ignores null runtime', () {
    final dives = [
      for (var k = 0; k < 8; k++)
        dive('p$k', daysAgo(400 + k * 30), runtimeSeconds: (k.isEven ? 41 : 39) * 60),
      for (var k = 0; k < 8; k++)
        dive('r$k', daysAgo(10 + k * 30), runtimeSeconds: (k.isEven ? 51 : 49) * 60),
      dive('none', daysAgo(5)),
    ]..sort((a, b) => a.date.compareTo(b.date));
    final out = diveTimeTrendRule(ObservationInputs(now: now, dives: dives));
    final facts = out.single.facts as TrendFacts;
    expect(facts.recent, closeTo(50, 1e-9));
    expect(facts.recentDives, 8);
  });

  test('weightTrendRule needs 1 kg and bands by kilogram', () {
    List<ObservationDive> make(double recent) => [
      for (var k = 0; k < 8; k++)
        dive('p$k', daysAgo(400 + k * 30), weightKg: k.isEven ? 8.1 : 7.9),
      for (var k = 0; k < 8; k++)
        dive('r$k', daysAgo(10 + k * 30), weightKg: recent + (k.isEven ? 0.1 : -0.1)),
    ]..sort((a, b) => a.date.compareTo(b.date));
    expect(weightTrendRule(ObservationInputs(now: now, dives: make(7.2))), isEmpty);
    final out = weightTrendRule(ObservationInputs(now: now, dives: make(5.5)));
    expect(out.single.fingerprint, 'down:2');
    expect(out.single.target, const InsightsCategoryTarget('equipment'));
  });

  group('frequencyTrendRule', () {
    List<ObservationDive> log({required int previous, required int recent}) => [
      dive('first', daysAgo(800)),
      ...divesIn(prefix: 'p', count: previous, endDaysAgo: 400),
      ...divesIn(prefix: 'r', count: recent, endDaysAgo: 5),
    ]..sort((a, b) => a.date.compareTo(b.date));

    test('fires on 30% and 6 more dives', () {
      final out = frequencyTrendRule(ObservationInputs(now: now, dives: log(previous: 20, recent: 26)));
      expect((out.single.facts as TrendFacts).recentDives, 26);
      expect(out.single.fingerprint, 'up:3');
      expect(out.single.target, const InsightsCategoryTarget('time-patterns'));
    });

    test('silent under 6 dives of change even at 50%', () {
      expect(frequencyTrendRule(ObservationInputs(now: now, dives: log(previous: 10, recent: 15))), isEmpty);
    });

    test('silent when the log starts inside the previous window', () {
      final dives = [
        ...divesIn(prefix: 'p', count: 4, endDaysAgo: 400, spanDays: 100),
        ...divesIn(prefix: 'r', count: 20, endDaysAgo: 5),
      ]..sort((a, b) => a.date.compareTo(b.date));
      expect(frequencyTrendRule(ObservationInputs(now: now, dives: dives)), isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/insights/domain/observations/rules/trend_rules_test.dart`
Expected: FAIL, `trend_rules.dart` missing.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:submersion/features/insights/domain/observations/effect_size.dart';
import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';
import 'package:submersion/features/insights/domain/observations/observation_thresholds.dart';

typedef _Sample = ({DateTime date, double value});

List<Observation> _one(Observation? o) => o == null ? const [] : [o];

String _percentBand(TrendFacts f) =>
    (f.percentChange.abs() / ObservationThresholds.percentBandWidth)
        .floor()
        .toString();

/// The shared gate for per-dive mean trends (spec section 4.1): at least 8
/// dives in each period, the rule's own minimum, and effect size >= 0.5.
Observation? _meanTrend({
  required ObservationRuleId rule,
  required ObservationInputs inputs,
  required Iterable<_Sample> samples,
  required bool Function(TrendFacts facts) passesMinimum,
  required String Function(TrendFacts facts) band,
  required ObservationTarget target,
}) {
  final recent = <double>[];
  final previous = <double>[];
  for (final s in samples) {
    if (inputs.inRecentYear(s.date)) {
      recent.add(s.value);
    } else if (inputs.inPreviousYear(s.date)) {
      previous.add(s.value);
    }
  }
  const minDives = ObservationThresholds.trendMinDivesPerPeriod;
  if (recent.length < minDives || previous.length < minDives) return null;
  final facts = TrendFacts(
    recent: meanOf(recent),
    previous: meanOf(previous),
    recentDives: recent.length,
    previousDives: previous.length,
  );
  if (!passesMinimum(facts)) return null;
  final d = effectSize(recent, previous);
  if (d == null || d < ObservationThresholds.trendMinEffectSize) return null;
  return Observation(
    ruleId: rule,
    fingerprint: '${facts.direction.name}:${band(facts)}',
    score: d,
    facts: facts,
    target: target,
  );
}

bool Function(TrendFacts) _minPercent(double percent) =>
    (f) => f.previous > 0 && f.percentChange.abs() >= percent;

List<Observation> rmvTrendRule(ObservationInputs inputs) => _one(
  _meanTrend(
    rule: ObservationRuleId.rmvTrend,
    inputs: inputs,
    samples: inputs.rmvPerDive.map((v) => (date: v.date, value: v.value)),
    passesMinimum: _minPercent(ObservationThresholds.rmvMinPercent),
    band: _percentBand,
    target: const InsightsCategoryTarget('gas'),
  ),
);

List<Observation> maxDepthTrendRule(ObservationInputs inputs) => _one(
  _meanTrend(
    rule: ObservationRuleId.maxDepthTrend,
    inputs: inputs,
    samples: [
      for (final d in inputs.dives)
        if ((d.maxDepthM ?? 0) > 0) (date: d.date, value: d.maxDepthM!),
    ],
    passesMinimum: _minPercent(ObservationThresholds.maxDepthMinPercent),
    band: _percentBand,
    target: const InsightsCategoryTarget('progression'),
  ),
);

/// Runtime in minutes; bottom time is never substituted.
List<Observation> diveTimeTrendRule(ObservationInputs inputs) => _one(
  _meanTrend(
    rule: ObservationRuleId.diveTimeTrend,
    inputs: inputs,
    samples: [
      for (final d in inputs.dives)
        if ((d.runtimeSeconds ?? 0) > 0)
          (date: d.date, value: d.runtimeSeconds! / 60),
    ],
    passesMinimum: _minPercent(ObservationThresholds.diveTimeMinPercent),
    band: _percentBand,
    target: const InsightsCategoryTarget('progression'),
  ),
);

List<Observation> weightTrendRule(ObservationInputs inputs) => _one(
  _meanTrend(
    rule: ObservationRuleId.weightTrend,
    inputs: inputs,
    samples: [
      for (final d in inputs.dives)
        if (d.weightKg != null) (date: d.date, value: d.weightKg!),
    ],
    passesMinimum: (f) =>
        (f.recent - f.previous).abs() >= ObservationThresholds.weightMinKg,
    band: (f) => ((f.recent - f.previous).abs() /
            ObservationThresholds.weightBandKg)
        .floor()
        .toString(),
    target: const InsightsCategoryTarget('equipment'),
  ),
);

/// Dive counts per period. The log must start before the previous window,
/// or a diver who began logging mid-window would read as "more dives".
List<Observation> frequencyTrendRule(ObservationInputs inputs) {
  if (inputs.dives.isEmpty ||
      inputs.dives.first.date.isAfter(inputs.previousStart)) {
    return const [];
  }
  final recent = inputs.dives.where((d) => inputs.inRecentYear(d.date)).length;
  final previous =
      inputs.dives.where((d) => inputs.inPreviousYear(d.date)).length;
  if (previous == 0) return const [];
  final facts = TrendFacts(
    recent: recent.toDouble(),
    previous: previous.toDouble(),
    recentDives: recent,
    previousDives: previous,
  );
  if (facts.percentChange.abs() < ObservationThresholds.frequencyMinPercent ||
      (recent - previous).abs() < ObservationThresholds.frequencyMinDives) {
    return const [];
  }
  return [
    Observation(
      ruleId: ObservationRuleId.frequencyTrend,
      fingerprint: '${facts.direction.name}:${_percentBand(facts)}',
      score: facts.percentChange.abs() / 100,
      facts: facts,
      target: const InsightsCategoryTarget('time-patterns'),
    ),
  ];
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/insights/domain/observations/rules/trend_rules_test.dart`
Expected: PASS. If a fixture lands exactly on a window edge, move the fixture date, not the rule.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/insights/domain/observations test/features/insights/domain/observations
git add lib/features/insights/domain/observations test/features/insights/domain/observations
git commit -m "feat(insights): trend observation rules"
```

---

### Task 4: Milestone rules

**Files:**
- Create: `lib/features/insights/domain/observations/rules/milestone_rules.dart`
- Test: `test/features/insights/domain/observations/rules/milestone_rules_test.dart`

**Interfaces:**
- Produces: `diveCountMilestoneRule`, `diveHoursMilestoneRule`, `deepestDiveRule`, `longestDiveRule`, `newCountryRule`, `newSpeciesRule`; helpers `bool isDiveCountMilestone(int)`, `bool isDiveHoursMilestone(int)`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';
import 'package:submersion/features/insights/domain/observations/rules/milestone_rules.dart';

import '../observation_fixtures.dart';

List<ObservationDive> nDives(int n, {int endDaysAgo = 5, int spanDays = 600}) =>
    divesIn(prefix: 'd', count: n, endDaysAgo: endDaysAgo, spanDays: spanDays);

void main() {
  test('milestone ladders', () {
    expect([50, 100, 150, 200, 250, 300, 400, 500, 750, 1000].every(isDiveCountMilestone), isTrue);
    expect([10, 25, 350, 450, 600, 800].any(isDiveCountMilestone), isFalse);
    expect([25, 50, 100, 200, 300].every(isDiveHoursMilestone), isTrue);
    expect([75, 150, 250].any(isDiveHoursMilestone), isFalse);
  });

  group('diveCountMilestoneRule', () {
    test('the 100th dive, logged recently, fires', () {
      final out = diveCountMilestoneRule(ObservationInputs(now: now, dives: nDives(100)));
      final f = out.single.facts as MilestoneFacts;
      expect(f.milestone, 100);
      expect(f.includesPrior, isFalse);
      expect(out.single.fingerprint, '100');
      expect(out.single.target, DiveTarget(f.diveId));
    });

    test('prior dives count toward the career number', () {
      final out = diveCountMilestoneRule(ObservationInputs(now: now, dives: nDives(10), priorDives: 140));
      expect((out.single.facts as MilestoneFacts).milestone, 150);
      expect((out.single.facts as MilestoneFacts).includesPrior, isTrue);
    });

    test('a milestone the prior count alone reached never fires', () {
      expect(diveCountMilestoneRule(ObservationInputs(now: now, dives: nDives(3), priorDives: 100)), isEmpty);
    });

    test('an old crossing does not fire', () {
      expect(diveCountMilestoneRule(ObservationInputs(now: now, dives: nDives(100, endDaysAgo: 200))), isEmpty);
    });

    test('prior experience only, no logged dives: nothing', () {
      expect(diveCountMilestoneRule(ObservationInputs(now: now, priorDives: 500, priorTimeSeconds: 900000)), isEmpty);
      expect(diveHoursMilestoneRule(ObservationInputs(now: now, priorDives: 500, priorTimeSeconds: 900000)), isEmpty);
    });
  });

  test('diveHoursMilestoneRule: crossing 50 hours on a recent dive', () {
    final dives = [
      for (var k = 0; k < 49; k++) dive('o$k', daysAgo(300 + k), runtimeSeconds: 3600),
      dive('cross', daysAgo(3), runtimeSeconds: 5400),
    ]..sort((a, b) => a.date.compareTo(b.date));
    final out = diveHoursMilestoneRule(ObservationInputs(now: now, dives: dives));
    final f = out.single.facts as MilestoneFacts;
    expect(f.milestone, 50);
    expect(f.diveId, 'cross');
  });

  group('records', () {
    List<ObservationDive> depths(List<double> values) => [
      for (var k = 0; k < values.length; k++)
        dive('d$k', daysAgo(300 - k * 20), maxDepthM: values[k], runtimeSeconds: (values[k] * 100).round()),
    ];

    test('a recent new deepest dive after 9 earlier dives fires', () {
      final values = [18.0, 20, 22, 19, 25, 21, 24, 23, 20, 22, 26, 31];
      final dives = depths(values);
      final out = deepestDiveRule(ObservationInputs(now: now, dives: dives));
      final f = out.single.facts as DiveRecordFacts;
      expect(f.value, 31);
      expect(f.previousBest, 26);
      expect(out.single.fingerprint, 'd11');
    });

    test('fewer than 10 measured dives: nothing', () {
      expect(deepestDiveRule(ObservationInputs(now: now, dives: depths([10, 12, 14]))), isEmpty);
    });

    test('longestDiveRule tracks runtime', () {
      final dives = depths([18.0, 20, 22, 19, 25, 21, 24, 23, 20, 22, 26, 31]);
      expect((longestDiveRule(ObservationInputs(now: now, dives: dives)).single.facts as DiveRecordFacts).value, 3100);
    });
  });

  group('newCountryRule', () {
    test('a recent first dive in a country fires, case-insensitively', () {
      final dives = [
        dive('a', daysAgo(400), country: 'Mexico'),
        dive('b', daysAgo(30), country: ' mexico '),
        dive('c', daysAgo(20), country: 'Egypt'),
      ];
      final out = newCountryRule(ObservationInputs(now: now, dives: dives));
      expect(out.single.fingerprint, 'egypt');
      expect((out.single.facts as NewCountryFacts).country, 'Egypt');
      expect(out.single.target, const InsightsCategoryTarget('geographic'));
    });

    test('a log that started recently has no "new" countries', () {
      expect(newCountryRule(ObservationInputs(now: now, dives: [dive('a', daysAgo(20), country: 'Egypt')])), isEmpty);
    });
  });

  test('newSpeciesRule: count and newest', () {
    final out = newSpeciesRule(ObservationInputs(
      now: now,
      dives: [dive('old', daysAgo(500))],
      species: [
        ObservationSpecies(id: 's1', name: 'Manta', firstSeen: daysAgo(400)),
        ObservationSpecies(id: 's2', name: 'Whale shark', firstSeen: daysAgo(40)),
        ObservationSpecies(id: 's3', name: 'Mola', firstSeen: daysAgo(10)),
      ],
    ));
    final f = out.single.facts as NewSpeciesFacts;
    expect(f.count, 2);
    expect(f.newestSpeciesName, 'Mola');
    expect(out.single.fingerprint, '2:s3');
    expect(out.single.target, const InsightsCategoryTarget('marine-life'));
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/insights/domain/observations/rules/milestone_rules_test.dart`
Expected: FAIL, file missing.

- [ ] **Step 3: Write the implementation**

```dart
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
  final fresh = [
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/insights/domain/observations/rules/milestone_rules_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/insights/domain/observations test/features/insights/domain/observations
git add lib/features/insights/domain/observations test/features/insights/domain/observations
git commit -m "feat(insights): milestone observation rules"
```

---

### Task 5: Pattern rules

**Files:**
- Create: `lib/features/insights/domain/observations/rules/pattern_rules.dart`
- Test: `test/features/insights/domain/observations/rules/pattern_rules_test.dart`

**Interfaces:**
- Produces: `diveGapRule`, `favouriteSiteRule`, `regularBuddyRule`, `busiestMonthRule`.

- [ ] **Step 1: Write the failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';
import 'package:submersion/features/insights/domain/observations/rules/pattern_rules.dart';

import '../observation_fixtures.dart';

void main() {
  group('diveGapRule', () {
    test('fires at 90 days, keyed on the last dive', () {
      final out = diveGapRule(ObservationInputs(now: now, dives: [dive('a', daysAgo(200)), dive('b', daysAgo(120))]));
      expect((out.single.facts as DiveGapFacts).days, 120);
      expect(out.single.fingerprint, 'b');
      expect(out.single.target, const DiveLogTarget());
    });
    test('silent under 90 days, with no dives, or with a future dive', () {
      expect(diveGapRule(ObservationInputs(now: now, dives: [dive('a', daysAgo(89))])), isEmpty);
      expect(diveGapRule(ObservationInputs(now: now)), isEmpty);
      expect(diveGapRule(ObservationInputs(now: now, dives: [dive('a', daysAgo(200)), dive('f', now.add(const Duration(days: 30)))])), isEmpty);
    });
  });

  group('favouriteSiteRule', () {
    List<ObservationDive> log(int atHome, int elsewhere) => [
      for (var k = 0; k < atHome; k++) dive('h$k', daysAgo(10 + k * 7), siteId: 'home', siteName: 'Blue Hole'),
      for (var k = 0; k < elsewhere; k++) dive('e$k', daysAgo(12 + k * 7), siteId: 'e$k', siteName: 'Other $k'),
    ]..sort((a, b) => a.date.compareTo(b.date));

    test('5 of 20 (25%) fires', () {
      final out = favouriteSiteRule(ObservationInputs(now: now, dives: log(5, 15)));
      final f = out.single.facts as ShareFacts;
      expect([f.subjectName, f.dives, f.totalDives], ['Blue Hole', 5, 20]);
      expect(out.single.target, const SiteTarget('home'));
    });
    test('4 dives is too few; 5 of 21 is under 25%', () {
      expect(favouriteSiteRule(ObservationInputs(now: now, dives: log(4, 4))), isEmpty);
      expect(favouriteSiteRule(ObservationInputs(now: now, dives: log(5, 16))), isEmpty);
    });
  });

  test('regularBuddyRule: 40% of the last 12 months', () {
    const sam = ObservationBuddy(id: 'b1', name: 'Sam');
    final dives = [
      for (var k = 0; k < 10; k++) dive('d$k', daysAgo(10 + k * 20), buddies: k < 4 ? const [sam] : const []),
      dive('old', daysAgo(500), buddies: const [sam]),
    ]..sort((a, b) => a.date.compareTo(b.date));
    expect(regularBuddyRule(ObservationInputs(now: now, dives: dives)), isEmpty); // 4 dives < 5
    final more = [...dives, dive('d10', daysAgo(5), buddies: const [sam])]..sort((a, b) => a.date.compareTo(b.date));
    final out = regularBuddyRule(ObservationInputs(now: now, dives: more));
    expect((out.single.facts as ShareFacts).dives, 5);
    expect(out.single.target, const BuddyTarget('b1'));
  });

  test('busiestMonthRule: the same month leads in two years', () {
    List<ObservationDive> year(int y, int leadMonth) => [
      for (var k = 0; k < 4; k++) dive('$y-l$k', DateTime.utc(y, leadMonth, 2 + k)),
      dive('$y-x', DateTime.utc(y, leadMonth == 1 ? 2 : 1, 5)),
    ];
    final out = busiestMonthRule(ObservationInputs(now: now, dives: [...year(2023, 8), ...year(2024, 8), ...year(2025, 3)]));
    final f = out.single.facts as MonthFacts;
    expect([f.month, f.years], [8, 2]);
    expect(out.single.fingerprint, '8');
    expect(busiestMonthRule(ObservationInputs(now: now, dives: [...year(2023, 8), ...year(2024, 9)])), isEmpty);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/insights/domain/observations/rules/pattern_rules_test.dart`
Expected: FAIL, file missing.

- [ ] **Step 3: Write the implementation**

```dart
import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';
import 'package:submersion/features/insights/domain/observations/observation_thresholds.dart';

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
      facts: DiveGapFacts(days: days, lastDiveId: last.id, lastDiveDate: last.date),
      target: const DiveLogTarget(),
    ),
  ];
}

/// The subject with the most of the last 12 months' dives; ties go to the
/// smaller id so the result is deterministic.
({String id, String name, int count})? _top(
  Iterable<({String id, String name})> subjects,
) {
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

Observation? _share({
  required ObservationRuleId rule,
  required ObservationInputs inputs,
  required Iterable<({String id, String name})> Function(ObservationDive d) subjectsOf,
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

/// A buddy linked twice to one dive counts once for it.
List<Observation> regularBuddyRule(ObservationInputs inputs) {
  final o = _share(
    rule: ObservationRuleId.regularBuddy,
    inputs: inputs,
    subjectsOf: (d) => {
      for (final b in d.buddies) b.id: (id: b.id, name: b.name),
    }.values,
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
    final leaders = [for (final e in months.entries) if (e.value == max) e.key];
    if (leaders.length != 1) continue;
    leads.update(leaders.single, (n) => n + 1, ifAbsent: () => 1);
  }
  if (leads.isEmpty) return const [];
  final best = leads.entries.reduce((a, b) {
    if (a.value != b.value) return a.value > b.value ? a : b;
    return a.key <= b.key ? a : b;
  });
  if (best.value < ObservationThresholds.busiestMonthMinYears) return const [];
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/insights/domain/observations/rules/pattern_rules_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/insights/domain/observations test/features/insights/domain/observations
git add lib/features/insights/domain/observations test/features/insights/domain/observations
git commit -m "feat(insights): pattern observation rules"
```

---

### Task 6: Safety rule, engine and ranking

**Files:**
- Create: `lib/features/insights/domain/observations/rules/safety_rules.dart`
- Create: `lib/features/insights/domain/observations/observation_engine.dart`
- Test: `test/features/insights/domain/observations/rules/safety_rules_test.dart`
- Test: `test/features/insights/domain/observations/observation_engine_test.dart`

**Interfaces:**
- Consumes: Tasks 1 to 5.
- Produces: `ascentRateRule`; `typedef ObservationRule = List<Observation> Function(ObservationInputs)`; `const Map<ObservationRuleId, ObservationRule> observationRules`; `List<Observation> runObservationRules(ObservationInputs, {Set<String> mutedRuleIds, Set<String> dismissedKeys, Map<ObservationRuleId, ObservationRule> rules, void Function(ObservationRuleId, Object, StackTrace)? onRuleError})`; `int compareObservations(Observation, Observation)`; `List<Observation> selectStrip(List<Observation> ranked)`.

- [ ] **Step 1: Write the failing tests**

`safety_rules_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';
import 'package:submersion/features/insights/domain/observations/rules/safety_rules.dart';

import '../observation_fixtures.dart';

void main() {
  List<ObservationDive> profiled(int n) => [
    for (var k = 0; k < n; k++) dive('p$k', daysAgo(10 + k * 30), hasProfile: true),
    dive('noProfile', daysAgo(3)),
  ]..sort((a, b) => a.date.compareTo(b.date));

  test('fires above 9 m/min over 5 profiled dives, banded by whole m/min', () {
    final out = ascentRateRule(ObservationInputs(now: now, dives: profiled(5), recentAscentRate: 11.4));
    final f = out.single.facts as RateFacts;
    expect([f.metersPerMin, f.dives], [11.4, 5]);
    expect(out.single.fingerprint, '11');
    expect(out.single.target, const InsightsCategoryTarget('profile'));
  });

  test('never fires at or below the guidance, without data, or under 5 dives', () {
    expect(ascentRateRule(ObservationInputs(now: now, dives: profiled(5), recentAscentRate: 9.0)), isEmpty);
    expect(ascentRateRule(ObservationInputs(now: now, dives: profiled(5))), isEmpty);
    expect(ascentRateRule(ObservationInputs(now: now, dives: profiled(4), recentAscentRate: 14)), isEmpty);
  });
}
```

`observation_engine_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_engine.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';

import 'observation_fixtures.dart';

Observation obs(ObservationRuleId rule, double score, [String fp = 'x']) =>
    Observation(
      ruleId: rule,
      fingerprint: fp,
      score: score,
      facts: const MonthFacts(month: 1, years: 2),
      target: const DiveLogTarget(),
    );

void main() {
  final inputs = ObservationInputs(now: now);

  test('the registry covers every rule id', () {
    expect(observationRules.keys.toSet(), ObservationRuleId.values.toSet());
  });

  test('muted rules and dismissed keys are dropped', () {
    final rules = {
      ObservationRuleId.diveGap: (ObservationInputs _) => [obs(ObservationRuleId.diveGap, 1)],
      ObservationRuleId.busiestMonth: (ObservationInputs _) =>
          [obs(ObservationRuleId.busiestMonth, 1, 'a'), obs(ObservationRuleId.busiestMonth, 1, 'b')],
      ObservationRuleId.rmvTrend: (ObservationInputs _) => [obs(ObservationRuleId.rmvTrend, 1)],
    };
    final out = runObservationRules(
      inputs,
      rules: rules,
      mutedRuleIds: {'diveGap', 'fromANewerBuild'},
      dismissedKeys: {'busiestMonth:a'},
    );
    expect(out.map((o) => o.key), ['rmvTrend:x', 'busiestMonth:b']);
  });

  test('a throwing rule is reported and the rest survive', () {
    final errors = <ObservationRuleId>[];
    final out = runObservationRules(
      inputs,
      rules: {
        ObservationRuleId.diveGap: (ObservationInputs _) => throw StateError('boom'),
        ObservationRuleId.rmvTrend: (ObservationInputs _) => [obs(ObservationRuleId.rmvTrend, 1)],
      },
      onRuleError: (rule, _, _) => errors.add(rule),
    );
    expect(errors, [ObservationRuleId.diveGap]);
    expect(out, hasLength(1));
  });

  test('ranking: tier, then score, then rule order, then fingerprint', () {
    final ranked = [
      obs(ObservationRuleId.diveGap, 9),
      obs(ObservationRuleId.rmvTrend, 0.6),
      obs(ObservationRuleId.maxDepthTrend, 0.9),
      obs(ObservationRuleId.newCountry, 0.5, 'b'),
      obs(ObservationRuleId.newCountry, 0.5, 'a'),
      obs(ObservationRuleId.ascentRate, 11),
    ]..sort(compareObservations);
    expect(ranked.map((o) => o.key), [
      'ascentRate:x', 'newCountry:a', 'newCountry:b',
      'maxDepthTrend:x', 'rmvTrend:x', 'diveGap:x',
    ]);
  });

  test('strip: three items, at most two per kind', () {
    final ranked = [
      obs(ObservationRuleId.deepestDive, 1),
      obs(ObservationRuleId.newCountry, 0.9),
      obs(ObservationRuleId.newSpecies, 0.8),
      obs(ObservationRuleId.rmvTrend, 2),
      obs(ObservationRuleId.diveGap, 1),
    ];
    expect(selectStrip(ranked).map((o) => o.ruleId), [
      ObservationRuleId.deepestDive,
      ObservationRuleId.newCountry,
      ObservationRuleId.rmvTrend,
    ]);
    expect(selectStrip(const []), isEmpty);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/insights/domain/observations/rules/safety_rules_test.dart test/features/insights/domain/observations/observation_engine_test.dart`
Expected: FAIL, files missing.

- [ ] **Step 3: Write the implementation**

`safety_rules.dart`:

```dart
import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';
import 'package:submersion/features/insights/domain/observations/observation_thresholds.dart';

/// Average ascent rate over the last 12 months above the common 9 m/min
/// guidance. Fires only above it: a slower rate is never praised.
List<Observation> ascentRateRule(ObservationInputs inputs) {
  final rate = inputs.recentAscentRate;
  if (rate == null ||
      rate <= ObservationThresholds.ascentRateGuidanceLowMPerMin) {
    return const [];
  }
  final profiled = inputs.dives
      .where((d) => d.hasProfile && inputs.inRecentYear(d.date))
      .length;
  if (profiled < ObservationThresholds.ascentRateMinDives) return const [];
  return [
    Observation(
      ruleId: ObservationRuleId.ascentRate,
      fingerprint: '${rate.floor()}',
      score: rate,
      facts: RateFacts(metersPerMin: rate, dives: profiled),
      target: const InsightsCategoryTarget('profile'),
    ),
  ];
}
```

`observation_engine.dart`:

```dart
import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/domain/observations/observation_thresholds.dart';
import 'package:submersion/features/insights/domain/observations/rules/milestone_rules.dart';
import 'package:submersion/features/insights/domain/observations/rules/pattern_rules.dart';
import 'package:submersion/features/insights/domain/observations/rules/safety_rules.dart';
import 'package:submersion/features/insights/domain/observations/rules/trend_rules.dart';

typedef ObservationRule = List<Observation> Function(ObservationInputs inputs);

const Map<ObservationRuleId, ObservationRule> observationRules = {
  ObservationRuleId.rmvTrend: rmvTrendRule,
  ObservationRuleId.maxDepthTrend: maxDepthTrendRule,
  ObservationRuleId.diveTimeTrend: diveTimeTrendRule,
  ObservationRuleId.weightTrend: weightTrendRule,
  ObservationRuleId.frequencyTrend: frequencyTrendRule,
  ObservationRuleId.diveCountMilestone: diveCountMilestoneRule,
  ObservationRuleId.diveHoursMilestone: diveHoursMilestoneRule,
  ObservationRuleId.deepestDive: deepestDiveRule,
  ObservationRuleId.longestDive: longestDiveRule,
  ObservationRuleId.newCountry: newCountryRule,
  ObservationRuleId.newSpecies: newSpeciesRule,
  ObservationRuleId.diveGap: diveGapRule,
  ObservationRuleId.favouriteSite: favouriteSiteRule,
  ObservationRuleId.regularBuddy: regularBuddyRule,
  ObservationRuleId.busiestMonth: busiestMonthRule,
  ObservationRuleId.ascentRate: ascentRateRule,
};

/// Runs every rule not in [mutedRuleIds] (stored ids; unknown ones are
/// harmless), drops observations whose key is in [dismissedKeys], and
/// returns them ranked. A throwing rule goes to [onRuleError] and is
/// skipped, so one bad rule never hides the rest.
List<Observation> runObservationRules(
  ObservationInputs inputs, {
  Set<String> mutedRuleIds = const {},
  Set<String> dismissedKeys = const {},
  Map<ObservationRuleId, ObservationRule> rules = observationRules,
  void Function(ObservationRuleId rule, Object error, StackTrace stack)?
  onRuleError,
}) {
  final out = <Observation>[];
  for (final entry in rules.entries) {
    if (mutedRuleIds.contains(entry.key.dbValue)) continue;
    try {
      out.addAll(
        entry.value(inputs).where((o) => !dismissedKeys.contains(o.key)),
      );
    } catch (error, stack) {
      onRuleError?.call(entry.key, error, stack);
    }
  }
  return out..sort(compareObservations);
}

/// Spec section 4.4: kind tier, then score (high first), then rule
/// declaration order and fingerprint so equal scores sort the same way
/// every time.
int compareObservations(Observation a, Observation b) {
  final byKind = a.kind.index.compareTo(b.kind.index);
  if (byKind != 0) return byKind;
  final byScore = b.score.compareTo(a.score);
  if (byScore != 0) return byScore;
  final byRule = a.ruleId.index.compareTo(b.ruleId.index);
  if (byRule != 0) return byRule;
  return a.fingerprint.compareTo(b.fingerprint);
}

/// The landing strip: the first three of [ranked], skipping any that would
/// show one kind a third time.
List<Observation> selectStrip(List<Observation> ranked) {
  final perKind = <ObservationKind, int>{};
  final out = <Observation>[];
  for (final o in ranked) {
    if (out.length == ObservationThresholds.stripSize) break;
    final n = perKind[o.kind] ?? 0;
    if (n >= ObservationThresholds.stripMaxPerKind) continue;
    perKind[o.kind] = n + 1;
    out.add(o);
  }
  return out;
}
```

- [ ] **Step 4: Run all domain tests**

Run: `flutter test test/features/insights/domain/observations/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/insights/domain/observations test/features/insights/domain/observations
git add lib/features/insights/domain/observations test/features/insights/domain/observations
git commit -m "feat(insights): ascent rate rule and the observation engine"
```

---

### Task 7: Schema rung 261 (table, column, migration)

**Files:**
- Create: `lib/core/database/tables/insight_tables.dart`
- Create: `lib/core/database/migrations/helpers/insight_migrations.dart`
- Modify: `lib/core/database/database.dart` (import/export lines 3-56, table list after `SiteHides,` ~225, `currentSchemaVersion` line 235, `migrationVersions` ~1085)
- Modify: `lib/core/database/tables/diver_tables.dart` (after `hiddenTankPresetIds`, ~258)
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (add `part 'helpers/insight_migrations.dart';` in the part list, lines 30-55)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (after the v260 block)
- Modify: `lib/core/database/migrations/before_open.dart` (backstop near the v250 lines ~199)
- Modify: `test/core/database/migration_v260_tank_shared_computers_test.dart:8-14`
- Test: `test/core/database/migration_v261_insight_observations_test.dart`

**Interfaces:**
- Produces: Drift table `InsightObservationDismissals` (`db.insightObservationDismissals`, row `InsightObservationDismissalRow`, companion `InsightObservationDismissalsCompanion`); column `DiverSettings.insightsMutedObservationRules` (`insights_muted_observation_rules`); extension method `_assertInsightObservationsSchema()`.

- [ ] **Step 1: Write the failing migration test**

Model on `test/core/database/migration_v250_profile_hides_test.dart` and `migration_v206_condition_engine_settings_test.dart` (read both first and reuse their fixture helpers verbatim). The test asserts:

```dart
test('version bookkeeping', () {
  expect(AppDatabase.currentSchemaVersion, 261);
  expect(AppDatabase.migrationVersions, contains(261));
  expect(AppDatabase.migrationStepCount(260), 1);
  expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
});
```

plus: a v260 fixture (`PRAGMA user_version = 260`, minimal `divers` and `diver_settings(id, diver_id, created_at, updated_at)` tables) opened as `AppDatabase` gains `insight_observation_dismissals` with columns `id, diver_id, rule_id, fingerprint, dismissed_at, created_at, updated_at, hlc` (via `PRAGMA table_info`), `dismissed_at` nullable, and `diver_settings.insights_muted_observation_rules` nullable with existing rows reading null; a fixture without `divers` gains no table; a fixture at `user_version = 261` lacking both is healed by the backstop; a fresh `createTestDatabase()` has both.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/database/migration_v261_insight_observations_test.dart`
Expected: FAIL (`currentSchemaVersion` is 260; table missing).

- [ ] **Step 3: Implement**

`tables/insight_tables.dart` (copy the header comment style of `query_tables.dart:1-12`):

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/tables/diver_tables.dart';

/// v261: one row per dismissed Insights observation (issue #2381). The id
/// is derived from (diver, rule, fingerprint) by `observationDismissalId`,
/// so two devices dismissing the same observation write the same row and
/// sync merges it as a plain upsert. Undo clears [dismissedAt]; rows are
/// never deleted by the feature.
@DataClassName('InsightObservationDismissalRow')
class InsightObservationDismissals extends Table {
  TextColumn get id => text()();
  TextColumn get diverId =>
      text().references(Divers, #id, onDelete: KeyAction.cascade)();
  TextColumn get ruleId => text()();
  TextColumn get fingerprint => text()();
  IntColumn get dismissedAt => integer().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();

  /// Hybrid Logical Clock for cross-device conflict resolution.
  TextColumn get hlc => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

(Check the import path of `Divers` against `trip_tables.dart`'s import of it and copy that.)

`diver_tables.dart`, next to `hiddenTankPresetIds`:

```dart
  /// v261: muted Insights observation rules (#2381), JSON list of
  /// ObservationRuleId.dbValue. Null or absent = none muted.
  TextColumn get insightsMutedObservationRules => text().nullable()();
```

`helpers/insight_migrations.dart`:

```dart
part of '../app_database_migrations.dart';

/// v261: Insights observation dismissals and the muted-rules column.
/// Idempotent, so the rung and the beforeOpen backstop share it.
extension InsightMigrations on AppDatabase {
  Future<void> _assertInsightObservationsSchema() async {
    await _addColumnIfMissing(
      'diver_settings',
      'insights_muted_observation_rules',
      'TEXT',
    );
    if (!await _tableExists('divers')) return;
    await Migrator(this).createTable(insightObservationDismissals);
  }
}
```

(`createTable` on an existing table throws in Drift: copy the existence guard `_assertSavedQueriesSchema` uses in `query_migrations.dart:9-16` exactly, for example an `if (await _tableExists('insight_observation_dismissals')) return;` before it.)

`rungs_v231_onward.dart`, after the v260 block:

```dart
      // v261: Insights observation dismissals (synced) and the muted-rules
      // column on diver_settings. Additive; re-asserted in beforeOpen.
      if (from < 261) await _assertInsightObservationsSchema();
      if (from < 261) await reportProgress();
```

`before_open.dart`: add `await _assertInsightObservationsSchema();` with a one-line `// v261 backstop` comment next to the v250 backstop. The file is at the 800-line cap: shorten an adjacent multi-line comment by two lines in the same edit so the file stays at or under 800.

`database.dart`: add the `tables/insight_tables.dart` import and export beside the other table libraries; append `InsightObservationDismissals,` with a `// Insight observation dismissals (v261)` comment after `SiteHides,`; set `currentSchemaVersion = 261`; append to `migrationVersions`:

```dart
    // v261: insight_observation_dismissals (synced) and
    // diver_settings.insights_muted_observation_rules. Additive.
    261,
```

`migration_v260_tank_shared_computers_test.dart`: relax the exact pins to `greaterThanOrEqualTo(260)` and `greaterThanOrEqualTo(1)` the way `migration_v250_profile_hides_test.dart:25-32` did.

- [ ] **Step 4: Codegen, then run the tests**

Run the codegen script (`dart run build_runner build --delete-conflicting-outputs` inside a scratchpad script), then:
`flutter test test/core/database/migration_v261_insight_observations_test.dart test/core/database/migration_v260_tank_shared_computers_test.dart test/core/database/database_table_libraries_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/database test/core/database
git add lib/core/database test/core/database
git commit -m "feat(insights): schema 261 for observation dismissals and muted rules"
```

---

### Task 8: Sync registration and diver delete

**Files:**
- Modify: `lib/core/services/sync/sync_data_serializer.dart` (`SyncData` field/constructor/`toJson`/`fromJson` at ~325/435/540/648; `_baseTables` ~1111; `_buildSyncData` ~2262 plus a new `_exportInsightObservationDismissals`; `fetchRecord` ~3028; `fetchRecords` ~3464; `upsertRecord` ~4634; `upsertRecords` ~5898; `recordIdsFor` ~6372; `_syncTableFor` ~6777; `deleteRecord` ~7295)
- Modify: `lib/core/services/sync/sync_service.dart` (`mergeOrder` ~1534; `entityHasUpdatedAt` ~2568)
- Modify: `lib/core/data/repositories/sync_repository.dart` (`hlcTargets` ~107)
- Modify: `lib/features/divers/data/repositories/diver_delete_steps.dart` (`diverLibrarySteps`, last entry ~253)
- Modify: `test/core/services/sync/sync_parent_refs_completeness_test.dart` (`syncedTables` ~54)
- Modify: `test/core/services/sync/sync_data_serializer_batch_coverage_test.dart` (targets ~163)
- Modify: `test/features/divers/data/repositories/diver_delete_tombstones_test.dart` (seeder map)
- Test: `test/core/services/sync/insight_observation_dismissals_sync_test.dart`

**Interfaces:**
- Consumes: Task 7 table.
- Produces: sync entity type `'insightObservationDismissals'`, JSON key `'insightObservationDismissals'`.

- [ ] **Step 1: Write the failing round-trip test**

Copy `test/core/services/sync/saved_queries_sync_round_trip_test.dart` to the new file and adapt it to the new table: seed a diver, `upsertRecord('insightObservationDismissals', id, json)`, `fetchRecord` returns it, `upsertRecord` again with a newer `updatedAt` and `dismissedAt: null` overwrites (Undo travels), `upsertRecords`/`fetchRecords`/`recordIdsFor` round-trip two rows, `deleteRecord` removes one. Also assert, as `equipment_findings_sync_test.dart:48-63` does, that `SyncDataSerializer.debugBaseTableKeys` contains `'insightObservationDismissals'` and that the key survives `SyncData.fromJson(...).toJson()`.

- [ ] **Step 2: Run it (and the structural guards) to verify failure**

Run: `flutter test test/core/services/sync/insight_observation_dismissals_sync_test.dart test/core/services/sync/sync_hlc_target_registration_test.dart`
Expected: FAIL (unknown entity; hlc table not registered).

- [ ] **Step 3: Register the entity everywhere `savedQueries` is registered**

For each location listed under Files, add an `insightObservationDismissals` entry beside the `savedQueries` one with the same shape, substituting `_db.insightObservationDismissals`, `InsightObservationDismissalRow`, and the table name `insight_observation_dismissals`. Concretely:

```dart
// SyncData
final List<Map<String, dynamic>> insightObservationDismissals;
this.insightObservationDismissals = const [],
'insightObservationDismissals': insightObservationDismissals,
insightObservationDismissals: _parseList(json['insightObservationDismissals']),

// _baseTables (same relative position as in toJson)
(key: 'insightObservationDismissals', table: _db.insightObservationDismissals, blob: false, full: null),

// _buildSyncData
insightObservationDismissals: await _safeExport(
  'insightObservationDismissals',
  () => _exportInsightObservationDismissals(hlcSince),
),

Future<List<Map<String, dynamic>>> _exportInsightObservationDismissals(
  String? hlcSince,
) async {
  final query = _db.select(_db.insightObservationDismissals);
  if (hlcSince != null) {
    query.where((t) => t.hlc.isBiggerThanValue(hlcSince));
  }
  final rows = await query.get();
  return rows.map((r) => r.toJson()).toList();
}

// fetchRecord
case 'insightObservationDismissals':
  final row = await (_db.select(_db.insightObservationDismissals)
        ..where((t) => t.id.equals(recordId)))
      .getSingleOrNull();
  return row?.toJson();

// fetchRecords
case 'insightObservationDismissals':
  final rows = await (_db.select(_db.insightObservationDismissals)
        ..where((t) => t.id.isIn(idList)))
      .get();
  return {for (final r in rows) r.id: r.toJson()};

// upsertRecord
case 'insightObservationDismissals':
  await _db.into(_db.insightObservationDismissals).insertOnConflictUpdate(
    InsightObservationDismissalRow.fromJson(data).toCompanion(false),
  );
  return;

// upsertRecords
case 'insightObservationDismissals':
  await _db.batch((b) => b.insertAllOnConflictUpdate(
    _db.insightObservationDismissals,
    records
        .map((r) => InsightObservationDismissalRow.fromJson(r).toCompanion(false))
        .toList(),
  ));
  return;

// recordIdsFor
case 'insightObservationDismissals':
  return plain(_db.insightObservationDismissals, _db.insightObservationDismissals.id);

// _syncTableFor
case 'insightObservationDismissals':
  return _db.insightObservationDismissals;

// deleteRecord
case 'insightObservationDismissals':
  await (_db.delete(_db.insightObservationDismissals)
        ..where((t) => t.id.equals(recordId)))
      .go();
  return;
```

Match each arm's exact surrounding shape (the `return`/`break` convention and the batch wrapper) to its `savedQueries` neighbour; the snippets above follow the report of those neighbours.

`sync_service.dart`:

```dart
(type: 'insightObservationDismissals', records: data.insightObservationDismissals, hasUpdatedAt: true),
// entityHasUpdatedAt
'insightObservationDismissals': true,
```

No `parentRefs` entry (divers are excluded by design).

`sync_repository.dart` `hlcTargets`:

```dart
'insightObservationDismissals': (table: 'insight_observation_dismissals', pk: 'id'),
```

`diver_delete_steps.dart` `diverLibrarySteps`, last entry:

```dart
  (
    table: 'insight_observation_dismissals',
    entityType: 'insightObservationDismissals',
    where: 'diver_id = ?1',
  ),
```

Tests: add `'insight_observation_dismissals': 'insightObservationDismissals',` to `syncedTables`; add `(type: 'insightObservationDismissals', table: db.insightObservationDismissals.actualTableName),` to the batch coverage targets; add a seeder to `diver_delete_tombstones_test.dart` that inserts one dismissal for diver A with id `'dis-a'` and returns `[('insight_observation_dismissals', 'insightObservationDismissals', 'dis-a')]`, copying the trip_hides seeder's shape.

- [ ] **Step 4: Run sync and diver tests**

Run: `flutter test test/core/services/sync/ test/features/divers/data/repositories/diver_delete_tombstones_test.dart test/features/divers/data/repositories/diver_delete_owned_tables_test.dart`
Expected: PASS, including `sync_base_streaming_parity_test`, `base_publish_streaming_parity_test` and `sync_hlc_target_registration_test`.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/services/sync lib/core/data lib/features/divers test/core/services/sync test/features/divers
git add lib/core/services/sync lib/core/data/repositories/sync_repository.dart lib/features/divers/data/repositories/diver_delete_steps.dart test/core/services/sync test/features/divers
git commit -m "feat(insights): sync observation dismissals and remove them with their diver"
```

---

### Task 9: Dismissals repository

**Files:**
- Create: `lib/features/insights/data/repositories/observation_dismissals_repository.dart`
- Test: `test/features/insights/data/repositories/observation_dismissals_repository_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 7, 8.
- Produces: `class ObservationDismissalsRepository { static const entityType = 'insightObservationDismissals'; Stream<Set<String>> watchDismissedKeys(String diverId); Future<void> dismiss({required String diverId, required ObservationRuleId rule, required String fingerprint}); Future<void> undismiss({...same}); }`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/insights/data/repositories/observation_dismissals_repository.dart';
import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ObservationDismissalsRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = ObservationDismissalsRepository();
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.divers).insert(DiversCompanion.insert(
      id: 'diver-1', name: 'A', createdAt: now, updatedAt: now));
  });
  tearDown(tearDownTestDatabase);

  test('dismiss writes the deterministic row; undismiss clears it', () async {
    await repo.dismiss(diverId: 'diver-1', rule: ObservationRuleId.rmvTrend, fingerprint: 'down:1');
    final id = observationDismissalId('diver-1', ObservationRuleId.rmvTrend, 'down:1');
    final row = await (db.select(db.insightObservationDismissals)..where((t) => t.id.equals(id))).getSingle();
    expect(row.dismissedAt, isNotNull);
    expect(row.hlc, isNotNull); // marked pending for sync

    await repo.undismiss(diverId: 'diver-1', rule: ObservationRuleId.rmvTrend, fingerprint: 'down:1');
    final cleared = await (db.select(db.insightObservationDismissals)..where((t) => t.id.equals(id))).getSingle();
    expect(cleared.dismissedAt, isNull);
    expect(cleared.createdAt, row.createdAt);
    expect(await db.select(db.insightObservationDismissals).get(), hasLength(1));
  });

  test('watchDismissedKeys: own diver, dismissed only, unknown rules skipped', () async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await repo.dismiss(diverId: 'diver-1', rule: ObservationRuleId.diveGap, fingerprint: 'd9');
    await db.into(db.insightObservationDismissals).insert(InsightObservationDismissalsCompanion.insert(
      id: 'od_future', diverId: 'diver-1', ruleId: 'fromANewerBuild', fingerprint: 'x',
      dismissedAt: Value(now), createdAt: now, updatedAt: now));
    expect(await repo.watchDismissedKeys('diver-1').first, {'diveGap:d9'});
    expect(await repo.watchDismissedKeys('other').first, isEmpty);
  });
}
```

(Adjust `DiversCompanion.insert` required fields to the real table; copy them from another test that inserts a diver, such as `species_insights_test.dart`'s `insertTestDiver`.)

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/insights/data/repositories/observation_dismissals_repository_test.dart`
Expected: FAIL, file missing.

- [ ] **Step 3: Implement** (shape copied from `saved_query_repository.dart`)

```dart
import 'package:clock/clock.dart';
import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';

/// Dismissals of Insights observations (#2381). Rows are keyed by
/// [observationDismissalId] and never deleted here: Undo clears
/// `dismissed_at`, so a later re-dismissal never races a tombstone.
class ObservationDismissalsRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _log = LoggerService.forClass(ObservationDismissalsRepository);

  static const entityType = 'insightObservationDismissals';

  /// The keys ([observationKey]) [diverId] has dismissed. Rows whose rule
  /// this build does not know are skipped, and left untouched in the table.
  Stream<Set<String>> watchDismissedKeys(String diverId) {
    final query = _db.select(_db.insightObservationDismissals)
      ..where((t) => t.diverId.equals(diverId) & t.dismissedAt.isNotNull());
    return query.watch().map(
      (rows) => {
        for (final r in rows)
          if (ObservationRuleId.fromDbValue(r.ruleId) case final rule?)
            observationKey(rule, r.fingerprint),
      },
    );
  }

  Future<void> dismiss({
    required String diverId,
    required ObservationRuleId rule,
    required String fingerprint,
  }) => _write(diverId, rule, fingerprint, dismissed: true);

  Future<void> undismiss({
    required String diverId,
    required ObservationRuleId rule,
    required String fingerprint,
  }) => _write(diverId, rule, fingerprint, dismissed: false);

  Future<void> _write(
    String diverId,
    ObservationRuleId rule,
    String fingerprint, {
    required bool dismissed,
  }) async {
    try {
      final now = clock.now().millisecondsSinceEpoch;
      final id = observationDismissalId(diverId, rule, fingerprint);
      final existing = await (_db.select(
        _db.insightObservationDismissals,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      await _db
          .into(_db.insightObservationDismissals)
          .insertOnConflictUpdate(
            InsightObservationDismissalsCompanion(
              id: Value(id),
              diverId: Value(diverId),
              ruleId: Value(rule.dbValue),
              fingerprint: Value(fingerprint),
              dismissedAt: Value(dismissed ? now : null),
              createdAt: Value(existing?.createdAt ?? now),
              updatedAt: Value(now),
            ),
          );
      await _syncRepository.markRecordPending(
        entityType: entityType,
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to ${dismissed ? 'dismiss' : 'restore'} observation',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/insights/data/repositories/observation_dismissals_repository_test.dart`
Expected: PASS. If `hlc` is not stamped by `markRecordPending` in tests, assert on whatever the saved queries repository test asserts for its pending mark instead.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/insights test/features/insights
git add lib/features/insights/data test/features/insights/data
git commit -m "feat(insights): observation dismissals repository"
```

---

### Task 10: Muted rules setting

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (`AppSettings` field ~262, constructor ~616, `copyWith` ~799/~959; `SettingsNotifier` setter near `setConditionRuleEnabled` ~2026)
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (`createSettingsForDiver` ~147, `_storedColumns` ~403, `_mapRowToAppSettings` ~608)
- Modify: `test/helpers/mock_providers.dart` (`MockSettingsNotifier` overrides ~307)
- Modify: `test/features/insights/presentation/pages/records_page_test.dart` (its `SettingsNotifier` implementer ~322)
- Test: `test/features/settings/data/repositories/diver_settings_repository_muted_observations_test.dart`
- Test: `test/features/settings/presentation/providers/settings_muted_observations_test.dart` (or extend the existing condition-rule setter test)

**Interfaces:**
- Produces: `AppSettings.insightsMutedObservationRules` (`Set<String>`, default `const {}`); `SettingsNotifier.setObservationRuleMuted(ObservationRuleId rule, bool muted)`.

- [ ] **Step 1: Write the failing tests**

Copy `diver_settings_repository_hidden_tank_presets_test.dart` and adapt: saving `{'rmvTrend', 'fromANewerBuild'}` round-trips both values (unknown preserved); an empty set stores null; a row with a null column reads `{}`. For the notifier, copy the `setConditionRuleEnabled` test and assert `setObservationRuleMuted(ObservationRuleId.diveGap, true)` adds `'diveGap'`, a second call with `false` removes it, and an unknown id already in the set survives both calls.

- [ ] **Step 2: Run to verify failure**

Run the two new test files. Expected: FAIL (field and setter missing).

- [ ] **Step 3: Implement**

`AppSettings`:

```dart
  /// Insights observation rules the diver muted (#2381), as
  /// ObservationRuleId.dbValue strings. Unknown ids (a newer build's
  /// rules) are kept so a save never drops them.
  final Set<String> insightsMutedObservationRules;
  // constructor
  this.insightsMutedObservationRules = const {},
  // copyWith parameter
  Set<String>? insightsMutedObservationRules,
  // copyWith body
  insightsMutedObservationRules:
      insightsMutedObservationRules ?? this.insightsMutedObservationRules,
```

`SettingsNotifier`:

```dart
  Future<void> setObservationRuleMuted(
    ObservationRuleId rule,
    bool muted,
  ) async {
    final rules = {...state.insightsMutedObservationRules};
    if (muted) {
      rules.add(rule.dbValue);
    } else {
      rules.remove(rule.dbValue);
    }
    state = state.copyWith(insightsMutedObservationRules: rules);
    await _saveSettings();
  }
```

`diver_settings_repository.dart`, in the three places beside `conditionDisabledRules`, reusing its codec (`_encodeDisabledRules`/`_decodeDisabledRules`; rename nothing):

```dart
insightsMutedObservationRules: Value(
  _encodeDisabledRules(s.insightsMutedObservationRules),
),
// _storedColumns
insightsMutedObservationRules: Value(
  _encodeDisabledRules(settings.insightsMutedObservationRules),
),
// _mapRowToAppSettings
insightsMutedObservationRules: _decodeDisabledRules(
  row.insightsMutedObservationRules,
),
```

Mocks: add to `MockSettingsNotifier` and the records page test notifier:

```dart
  @override
  Future<void> setObservationRuleMuted(ObservationRuleId rule, bool muted) async {
    final rules = {...state.insightsMutedObservationRules};
    muted ? rules.add(rule.dbValue) : rules.remove(rule.dbValue);
    state = state.copyWith(insightsMutedObservationRules: rules);
  }
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/settings/ test/helpers/` then `flutter analyze`.
Expected: PASS, no analyzer issues (the analyzer catches any other `implements SettingsNotifier` class without `noSuchMethod`).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/settings test
git add lib/features/settings test/helpers/mock_providers.dart test/features/insights/presentation/pages/records_page_test.dart test/features/settings
git commit -m "feat(insights): muted observation rules setting"
```

---

### Task 11: Inputs queries and loader

**Files:**
- Create: `lib/features/insights/data/repositories/observation_inputs_queries.dart`
- Create: `lib/features/insights/data/observation_inputs_loader.dart`
- Test: `test/features/insights/data/repositories/observation_inputs_queries_test.dart`
- Test: `test/features/insights/data/observation_inputs_loader_test.dart`

**Interfaces:**
- Consumes: `InsightsRepository.getSacVolumePerDive`, `.getAscentDescentRates`, `SeenSpeciesRepository.getSeenSpecies`, `DiveStatsScope.and`, `effectiveRuntimeSecondsSql`, `wallClockUtcFromMillis`, `Diver`.
- Produces: `class ObservationInputsQueries { Future<List<ObservationDive>> dives({String? diverId}); }`; `class ObservationInputsLoader { ObservationInputsLoader({ObservationInputsQueries? queries, InsightsRepository? insights, SeenSpeciesRepository? species}); Future<ObservationInputs> load({String? diverId, Diver? diver, required DateTime now}); }`.

- [ ] **Step 1: Write the failing query test**

Using `setUpTestDatabase()` and local seeders copied from `dive_stats_scope_behavior_test.dart` (diver, sites with `country`, buddies with `dive_buddies` links, weights from `insights_repository_per_dive_test.dart`, a primary profile series from `ascent_descent_test.dart`), seed:

- dive `d1` (2026-01-10, diver A, site with country 'Egypt', 2 weight rows of 3 kg, runtime 3000 s, max depth 24, buddy Sam linked twice with two roles, a primary profile);
- dive `d2` (2026-02-01, diver A, no site, no weight, `runtime` null but entry/exit times 40 minutes apart);
- dive `x` excluded from statistics; dive `p` planned; dive `o` for diver B.

Assert `dives(diverId: 'A')` returns `[d1, d2]` in date order with: `d1.weightKg == 6`, `d1.country == 'Egypt'`, `d1.hasProfile`, `d1.buddies == [ObservationBuddy(id: sam, name: 'Sam')]` (once), `d1.runtimeSeconds == 3000`, `d2.runtimeSeconds == 2400` (from entry/exit), `d2.weightKg == null`, `d2.hasProfile == false`, and `d1.date == DateTime.utc(2026, 1, 10, ...)` matching the stored wall clock.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/insights/data/repositories/observation_inputs_queries_test.dart`
Expected: FAIL, file missing.

- [ ] **Step 3: Implement the queries**

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_stats_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_times_sql.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';

/// Read-only SQL for the observation rules (#2381): one row per in-scope
/// dive with the columns the rules need, plus its buddies. Whole log: no
/// view filter, only DiveStatsScope.
class ObservationInputsQueries {
  AppDatabase get _db => DatabaseService.instance.database;
  final _log = LoggerService.forClass(ObservationInputsQueries);

  Future<List<ObservationDive>> dives({String? diverId}) async {
    try {
      final diverFilter = diverId != null ? 'AND d.diver_id = ?' : '';
      final variables = [if (diverId != null) Variable<String>(diverId)];
      final rows = await _db.customSelect(
        'SELECT d.id AS id, d.dive_date_time AS ms, d.max_depth AS max_depth, '
        '${effectiveRuntimeSecondsSql('d')} AS runtime_s, '
        '(SELECT SUM(w.amount_kg) FROM dive_weights w '
        'WHERE w.dive_id = d.id) AS weight_kg, '
        'd.site_id AS site_id, ds.name AS site_name, ds.country AS country, '
        'EXISTS (SELECT 1 FROM dive_profile_series s WHERE s.dive_id = d.id '
        'AND s.is_primary = 1) AS has_profile '
        'FROM dives d LEFT JOIN dive_sites ds ON ds.id = d.site_id '
        'WHERE 1=1 $diverFilter ${DiveStatsScope.and(alias: 'd')} '
        'ORDER BY d.dive_date_time, d.id',
        variables: variables,
        readsFrom: {
          _db.dives,
          _db.diveWeights,
          _db.diveSites,
          _db.diveProfileSeries,
        },
      ).get();
      final buddies = await _buddiesByDive(diverFilter, variables);
      return [
        for (final r in rows)
          ObservationDive(
            id: r.read<String>('id'),
            date: wallClockUtcFromMillis(r.read<int>('ms')),
            maxDepthM: (r.data['max_depth'] as num?)?.toDouble(),
            runtimeSeconds: (r.data['runtime_s'] as num?)?.round(),
            weightKg: (r.data['weight_kg'] as num?)?.toDouble(),
            siteId: r.data['site_id'] as String?,
            siteName: r.data['site_name'] as String?,
            country: r.data['country'] as String?,
            hasProfile: (r.data['has_profile'] as int? ?? 0) != 0,
            buddies: buddies[r.read<String>('id')] ?? const [],
          ),
      ];
    } catch (e, stackTrace) {
      _log.error('Failed to load observation dives', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<Map<String, List<ObservationBuddy>>> _buddiesByDive(
    String diverFilter,
    List<Variable<Object>> variables,
  ) async {
    final rows = await _db.customSelect(
      'SELECT DISTINCT db.dive_id AS dive_id, b.id AS id, b.name AS name '
      'FROM dive_buddies db JOIN buddies b ON b.id = db.buddy_id '
      'JOIN dives d ON d.id = db.dive_id '
      'WHERE 1=1 $diverFilter ${DiveStatsScope.and(alias: 'd')} '
      'ORDER BY b.name, b.id',
      variables: variables,
      readsFrom: {_db.diveBuddies, _db.buddies, _db.dives},
    ).get();
    final out = <String, List<ObservationBuddy>>{};
    for (final r in rows) {
      out.putIfAbsent(r.read<String>('dive_id'), () => []).add(
        ObservationBuddy(id: r.read<String>('id'), name: r.read<String>('name')),
      );
    }
    return out;
  }
}
```

(Verify column names against the tables: `dive_profile_series.is_primary`, `dive_weights.amount_kg`, `buddies.name`, and that `dive_date_time` is NOT NULL; if it is nullable, skip null rows.)

- [ ] **Step 4: Write the loader test, see it fail, implement the loader**

Loader test: with the database seeded as above plus an RMV-capable dive (tank rows per `insights_repository_sac_test.dart`), a sighting of a species, and `Diver` `priorDiveCount: 40`, `priorDiveTimeSeconds: 3600`, assert `load(diverId: 'A', diver: diver, now: DateTime.utc(2026, 10, 5, 12))` returns `priorDives == 40`, `rmvPerDive` holding the SAC dive with its id, `species` with the first-seen date, `recentAscentRate` non-null for the profiled dive inside the window, and that `insightsFilterProvider` plays no part (the loader takes no filter). A negative `priorDiveCount` reads as 0.

```dart
import 'dart:math' as math;

import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
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

  Future<ObservationInputs> load({
    String? diverId,
    Diver? diver,
    required DateTime now,
  }) async {
    final windows = ObservationInputs(now: now);
    final results = await Future.wait([
      _queries.dives(diverId: diverId),
      _insights.getSacVolumePerDive(diverId: diverId),
      _species.getSeenSpecies(diverId: diverId),
      _insights.getAscentDescentRates(
        diverId: diverId,
        filter: DiveFilterState(startDate: windows.recentStart, endDate: now),
      ),
    ]);
    final dives = results[0] as List<ObservationDive>;
    final rmv = results[1] as List<TrendDataPoint>;
    final seen = results[2] as List<SeenSpecies>;
    final rates = results[3] as ({double? avgAscent, double? avgDescent});
    return ObservationInputs(
      now: now,
      dives: dives,
      rmvPerDive: [
        for (final p in rmv)
          if (p.diveId != null)
            ObservationValue(diveId: p.diveId!, date: p.date, value: p.value),
      ],
      species: [
        for (final s in seen)
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
```

(Import `SeenSpecies` from `lib/features/marine_life/domain/entities/seen_species.dart`. `TrendDataPoint` is re-exported by the insights repository.)

Run: `flutter test test/features/insights/data/`
Expected: PASS.

- [ ] **Step 5: Architecture tests and commit**

Run: `flutter test test/architecture/`
Expected: PASS (the stats-scope guard accepts both queries because they use `DiveStatsScope.and`).

```bash
dart format lib/features/insights test/features/insights
git add lib/features/insights/data test/features/insights/data
git commit -m "feat(insights): load observation inputs from the whole log"
```

---

### Task 12: Observation providers

**Files:**
- Create: `lib/features/insights/presentation/providers/observations_providers.dart`
- Test: `test/features/insights/presentation/providers/observations_providers_test.dart`

**Interfaces:**
- Consumes: Tasks 6, 9, 10, 11; `currentDiverIdProvider`, `currentDiverProvider`, `insightsRepositoryProvider`, `settingsProvider`, `localDayChanges()`.
- Produces: `observationInputsLoaderProvider`, `observationDismissalsRepositoryProvider`, `observationInputsProvider` (`FutureProvider<ObservationInputs>`), `dismissedObservationKeysProvider` (`StreamProvider<Set<String>>`), `observationsProvider` (`FutureProvider<List<Observation>>`), `observationStripProvider` (`Provider<AsyncValue<List<Observation>>>`).

- [ ] **Step 1: Write the failing test**

Override `observationInputsProvider` with a fixed `ObservationInputs` that makes `diveGapRule` and `busiestMonthRule` fire, `dismissedObservationKeysProvider` with `Stream.value({'busiestMonth:8'})`, and `settingsProvider` with a `MockSettingsNotifier(AppSettings(insightsMutedObservationRules: {...}))` from `getBaseOverrides`. Assert:

- `observationsProvider` yields only the dive-gap observation (busiest month dismissed);
- muting `diveGap` through the notifier yields an empty list on the next read;
- `observationStripProvider` is `AsyncData([])` then;
- with no current diver (`currentDiverProvider` overridden to `null`), `dismissedObservationKeysProvider` emits `{}` and nothing throws;
- `observationInputsProvider` does not depend on `insightsFilterProvider`: changing the filter does not rebuild it (count builds with a listener).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/insights/presentation/providers/observations_providers_test.dart`
Expected: FAIL, file missing.

- [ ] **Step 3: Implement**

```dart
import 'package:clock/clock.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/core/utils/local_day_changes.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/data/observation_inputs_loader.dart';
import 'package:submersion/features/insights/data/repositories/observation_dismissals_repository.dart';
import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_engine.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

final _log = LoggerService.forClass(ObservationInputsLoader);

final observationInputsLoaderProvider = Provider<ObservationInputsLoader>(
  (ref) => ObservationInputsLoader(insights: ref.watch(insightsRepositoryProvider)),
);

final observationDismissalsRepositoryProvider =
    Provider<ObservationDismissalsRepository>(
      (ref) => ObservationDismissalsRepository(),
    );

/// The whole log of the current diver, never the Insights view filter
/// (spec section 3). Refreshes on any Insights table change and at local
/// midnight, since every window is measured back from "now".
final observationInputsProvider = FutureProvider<ObservationInputs>((ref) async {
  final loader = ref.watch(observationInputsLoaderProvider);
  final repository = ref.watch(insightsRepositoryProvider);
  final diverId = ref.watch(currentDiverIdProvider);
  final diverFuture = ref.watch(currentDiverProvider.future);
  ref.invalidateSelfWhen(repository.watchInsightsChanges());
  ref.invalidateSelfWhen(localDayChanges());
  final diver = await diverFuture;
  return loader.load(
    diverId: diverId,
    diver: diver,
    now: asWallClockUtc(clock.now()),
  );
});

/// Keys the current diver dismissed; empty with no diver.
final dismissedObservationKeysProvider = StreamProvider<Set<String>>((
  ref,
) async* {
  final diver = await ref.watch(currentDiverProvider.future);
  if (diver == null) {
    yield const <String>{};
    return;
  }
  yield* ref
      .watch(observationDismissalsRepositoryProvider)
      .watchDismissedKeys(diver.id);
});

final observationsProvider = FutureProvider<List<Observation>>((ref) async {
  final inputsFuture = ref.watch(observationInputsProvider.future);
  final dismissedFuture = ref.watch(dismissedObservationKeysProvider.future);
  final muted = ref.watch(
    settingsProvider.select((s) => s.insightsMutedObservationRules),
  );
  final inputs = await inputsFuture;
  final dismissed = await dismissedFuture;
  return runObservationRules(
    inputs,
    mutedRuleIds: muted,
    dismissedKeys: dismissed,
    onRuleError: (rule, error, stack) => _log.error(
      'Observation rule ${rule.dbValue} failed',
      error: error,
      stackTrace: stack,
    ),
  );
});

/// The landing strip's observations (spec section 4.4).
final observationStripProvider = Provider<AsyncValue<List<Observation>>>(
  (ref) => ref.watch(observationsProvider).whenData(selectStrip),
);
```

(Check `localDayChanges` and `asWallClockUtc` import paths against `dashboard_providers.dart`. If `provider_change_tick_test` flags `dismissedObservationKeysProvider`, it is reading through a Drift `watch()` stream, which already refreshes on table change: add the provider to that test's documented allow-list mechanism, or add `ref.invalidateSelfWhen(...)` on the dismissals table updates, whichever the guard's message prescribes.)

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/insights/presentation/providers/observations_providers_test.dart test/architecture/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/insights test/features/insights
git add lib/features/insights/presentation/providers test/features/insights/presentation/providers
git commit -m "feat(insights): observation providers"
```

---

### Task 13: Strings and the sentence formatter

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the 10 other ARB files; regenerate `lib/l10n/arb/app_localizations*.dart`
- Create: `lib/features/insights/presentation/formatters/observation_sentence.dart`
- Test: `test/features/insights/presentation/formatters/observation_sentence_test.dart`

**Interfaces:**
- Consumes: Task 1 facts; `UnitFormatter`; `AppLocalizations`.
- Produces: `String observationSentence(Observation o, AppLocalizations l10n, UnitFormatter units)`; `String observationRuleLabel(ObservationRuleId rule, AppLocalizations l10n)`; `String insightsMonthName(AppLocalizations l10n, int month)`.

- [ ] **Step 1: Add the English strings (with `@` metadata) to `app_en.arb`**

| Key | English | Placeholders |
| --- | --- | --- |
| `insights_observations_title` | Observations | |
| `insights_observations_seeAll` | See all | |
| `insights_observations_filterNote` | Observations use your whole log, so the filter does not apply to them | |
| `insights_observations_empty` | Observations appear as your log grows | |
| `insights_observations_error` | Couldn't load observations | |
| `insights_observations_actions` | Observation actions | |
| `insights_observations_dismiss` | Dismiss | |
| `insights_observations_dismissed` | Observation dismissed | |
| `insights_observations_dismissFailed` | Couldn't dismiss the observation | |
| `insights_observations_mute` | Don't show this kind | |
| `insights_observations_muted` | Observations of this kind are hidden | |
| `insights_observations_undo` | Undo | |
| `insights_observations_mutedKinds` | Muted kinds | |
| `insights_observations_mutedKinds_empty` | No kinds are muted | |
| `insights_observations_unmute` | Unmute | |
| `insights_observations_rule_rmvTrend` | RMV trend | |
| `insights_observations_rule_maxDepthTrend` | Max depth trend | |
| `insights_observations_rule_diveTimeTrend` | Dive time trend | |
| `insights_observations_rule_weightTrend` | Weight trend | |
| `insights_observations_rule_frequencyTrend` | Dive frequency | |
| `insights_observations_rule_diveCountMilestone` | Dive count milestones | |
| `insights_observations_rule_diveHoursMilestone` | Dive hours milestones | |
| `insights_observations_rule_deepestDive` | New deepest dive | |
| `insights_observations_rule_longestDive` | New longest dive | |
| `insights_observations_rule_newCountry` | New countries | |
| `insights_observations_rule_newSpecies` | New species | |
| `insights_observations_rule_diveGap` | Time since last dive | |
| `insights_observations_rule_favouriteSite` | Favourite site | |
| `insights_observations_rule_regularBuddy` | Regular buddy | |
| `insights_observations_rule_busiestMonth` | Busiest month | |
| `insights_observations_rule_ascentRate` | Ascent rate | |
| `insights_observations_rmvTrend_improved` | Your RMV improved: {recent} over the last 12 months, {percent}% lower than the year before ({previous}) | recent, previous, percent: String |
| `insights_observations_rmvTrend_rose` | Your RMV rose: {recent} over the last 12 months, {percent}% higher than the year before ({previous}) | same |
| `insights_observations_maxDepthTrend_deeper` | Over the last 12 months your average max depth was {recent}, {percent}% deeper than the year before ({previous}) | same |
| `insights_observations_maxDepthTrend_shallower` | Over the last 12 months your average max depth was {recent}, {percent}% shallower than the year before ({previous}) | same |
| `insights_observations_diveTimeTrend_longer` | Over the last 12 months your average dive time was {recent}, {percent}% longer than the year before ({previous}) | same |
| `insights_observations_diveTimeTrend_shorter` | Over the last 12 months your average dive time was {recent}, {percent}% shorter than the year before ({previous}) | same |
| `insights_observations_weightTrend_more` | Over the last 12 months you carried {amount} more weight on average than the year before | amount: String |
| `insights_observations_weightTrend_less` | Over the last 12 months you carried {amount} less weight on average than the year before | amount: String |
| `insights_observations_frequencyTrend_more` | `{count, plural, =1{You logged 1 dive in the last 12 months, {percent}% more than the year before} other{You logged {count} dives in the last 12 months, {percent}% more than the year before}}` | count: int, percent: String |
| `insights_observations_frequencyTrend_fewer` | same shape with "fewer" | count: int, percent: String |
| `insights_observations_diveCountMilestone` | You reached {count} dives on {date} | count, date: String |
| `insights_observations_diveCountMilestone_logged` | You reached {count} logged dives on {date} | count, date: String |
| `insights_observations_diveHoursMilestone` | You passed {hours} hours underwater on {date} | hours, date: String |
| `insights_observations_diveHoursMilestone_logged` | You passed {hours} logged hours underwater on {date} | hours, date: String |
| `insights_observations_deepestDive` | New deepest dive: {value} on {date}, beyond your previous {previous} | value, date, previous: String |
| `insights_observations_longestDive` | New longest dive: {value} on {date}, beyond your previous {previous} | value, date, previous: String |
| `insights_observations_newCountry` | Your first dive in {country}, on {date} | country, date: String |
| `insights_observations_newSpecies` | `{count, plural, =1{A new species in the last 90 days: {name}} other{{count} new species in the last 90 days, most recently {name}}}` | count: int, name: String |
| `insights_observations_diveGap` | `{count, plural, =1{Your last dive was 1 day ago} other{Your last dive was {count} days ago}}` | count: int |
| `insights_observations_favouriteSite` | {site} hosted {dives} of your {total} dives in the last 12 months | site, dives, total: String |
| `insights_observations_regularBuddy` | You dived with {buddy} on {dives} of your {total} dives in the last 12 months | buddy, dives, total: String |
| `insights_observations_busiestMonth` | {month} has been your busiest month in {years} different years | month, years: String |
| `insights_observations_ascentRate` | Your average ascent rate over the last 12 months was {rate}, across {dives} dives. Common guidance is {low} to {high} or slower | rate, dives, low, high: String |

- [ ] **Step 2: Translate every key into ar, de, es, fr, he, hu, it, nl, pt, zh**

Write the translations with a small Python 3.14 script that loads each ARB as an ordered dict, inserts the keys after the last `insights_` key, and writes UTF-8 with the file's existing indentation. Plural keys: Arabic has zero/one/two/few/many/other branches; fr and pt `=1{}` branches use `{count}`; keep "RMV" untranslated (as the Gas page does) and follow each locale's existing Insights terminology (de "Einblicke", and the locale's existing word for "dive"). Then run `flutter gen-l10n`.

Run: `flutter test test/l10n/`
Expected: PASS (`arb_parity_test`, `arabic_plural_categories_test`, `plural_singular_interpolates_argument_test`, `rmv_relabel_test`, `german_sac_terminology_test`).

- [ ] **Step 3: Write the failing formatter test**

For a metric `AppSettings()` and an imperial one (`depthUnit: DepthUnit.feet`, `weightUnit: WeightUnit.pounds`, `volumeUnit: VolumeUnit.cubicFeet`; copy the enum names from `unit_formatter_test.dart`), and `lookupAppLocalizations(const Locale('en'))`, assert:

- RMV down 25%, 15 vs 20 L/min: contains "improved", "25%", "15.0 L/min", "20.0 L/min"; imperial contains "cuft/min" and not "L/min";
- max depth up: metric contains "m", imperial contains "ft";
- ascent rate 11.4: metric contains "11.4m/min" and "9m/min to 10m/min" (decimals 0 for the guidance), imperial uses ft/min;
- dive gap 120 days: "120 days ago";
- busiest month 8: "August";
- a mismatched facts type (a `MonthFacts` on `rmvTrend`) falls back to the rule label "RMV trend" instead of throwing;
- in `Locale('de')` the RMV percent renders with no hard-coded English.

- [ ] **Step 4: Implement the formatter**

```dart
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/domain/observations/observation_thresholds.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

String _pct(TrendFacts t) => formatFixedForDisplay(t.percentChange.abs(), 0);

String _minutes(AppLocalizations l10n, double minutes) =>
    l10n.insights_records_longestDiveValue(minutes.round());

String insightsMonthName(AppLocalizations l10n, int month) => [
  l10n.insights_timePatterns_month_jan, l10n.insights_timePatterns_month_feb,
  l10n.insights_timePatterns_month_mar, l10n.insights_timePatterns_month_apr,
  l10n.insights_timePatterns_month_may, l10n.insights_timePatterns_month_jun,
  l10n.insights_timePatterns_month_jul, l10n.insights_timePatterns_month_aug,
  l10n.insights_timePatterns_month_sep, l10n.insights_timePatterns_month_oct,
  l10n.insights_timePatterns_month_nov, l10n.insights_timePatterns_month_dec,
][month - 1];

String observationRuleLabel(ObservationRuleId rule, AppLocalizations l10n) =>
    switch (rule) {
      ObservationRuleId.rmvTrend => l10n.insights_observations_rule_rmvTrend,
      ObservationRuleId.maxDepthTrend => l10n.insights_observations_rule_maxDepthTrend,
      ObservationRuleId.diveTimeTrend => l10n.insights_observations_rule_diveTimeTrend,
      ObservationRuleId.weightTrend => l10n.insights_observations_rule_weightTrend,
      ObservationRuleId.frequencyTrend => l10n.insights_observations_rule_frequencyTrend,
      ObservationRuleId.diveCountMilestone => l10n.insights_observations_rule_diveCountMilestone,
      ObservationRuleId.diveHoursMilestone => l10n.insights_observations_rule_diveHoursMilestone,
      ObservationRuleId.deepestDive => l10n.insights_observations_rule_deepestDive,
      ObservationRuleId.longestDive => l10n.insights_observations_rule_longestDive,
      ObservationRuleId.newCountry => l10n.insights_observations_rule_newCountry,
      ObservationRuleId.newSpecies => l10n.insights_observations_rule_newSpecies,
      ObservationRuleId.diveGap => l10n.insights_observations_rule_diveGap,
      ObservationRuleId.favouriteSite => l10n.insights_observations_rule_favouriteSite,
      ObservationRuleId.regularBuddy => l10n.insights_observations_rule_regularBuddy,
      ObservationRuleId.busiestMonth => l10n.insights_observations_rule_busiestMonth,
      ObservationRuleId.ascentRate => l10n.insights_observations_rule_ascentRate,
    };

/// The observation as one localized sentence in the diver's units. A facts
/// type that does not match its rule (a programming error) falls back to
/// the rule's label rather than throwing in the middle of a list.
String observationSentence(
  Observation o,
  AppLocalizations l10n,
  UnitFormatter units,
) {
  final down = switch (o.facts) {
    TrendFacts(:final direction) => direction == TrendDirection.down,
    _ => false,
  };
  return switch ((o.ruleId, o.facts)) {
    (ObservationRuleId.rmvTrend, final TrendFacts t) => (down
        ? l10n.insights_observations_rmvTrend_improved
        : l10n.insights_observations_rmvTrend_rose)(
        units.formatRmv(t.recent), units.formatRmv(t.previous), _pct(t)),
    (ObservationRuleId.maxDepthTrend, final TrendFacts t) => (down
        ? l10n.insights_observations_maxDepthTrend_shallower
        : l10n.insights_observations_maxDepthTrend_deeper)(
        units.formatDepth(t.recent), units.formatDepth(t.previous), _pct(t)),
    (ObservationRuleId.diveTimeTrend, final TrendFacts t) => (down
        ? l10n.insights_observations_diveTimeTrend_shorter
        : l10n.insights_observations_diveTimeTrend_longer)(
        _minutes(l10n, t.recent), _minutes(l10n, t.previous), _pct(t)),
    (ObservationRuleId.weightTrend, final TrendFacts t) => (down
        ? l10n.insights_observations_weightTrend_less
        : l10n.insights_observations_weightTrend_more)(
        units.formatWeight((t.recent - t.previous).abs())),
    (ObservationRuleId.frequencyTrend, final TrendFacts t) => (down
        ? l10n.insights_observations_frequencyTrend_fewer
        : l10n.insights_observations_frequencyTrend_more)(
        t.recentDives, _pct(t)),
    (ObservationRuleId.diveCountMilestone, final MilestoneFacts m) =>
      (m.includesPrior
          ? l10n.insights_observations_diveCountMilestone
          : l10n.insights_observations_diveCountMilestone_logged)(
          '${m.milestone}', units.formatDate(m.date)),
    (ObservationRuleId.diveHoursMilestone, final MilestoneFacts m) =>
      (m.includesPrior
          ? l10n.insights_observations_diveHoursMilestone
          : l10n.insights_observations_diveHoursMilestone_logged)(
          '${m.milestone}', units.formatDate(m.date)),
    (ObservationRuleId.deepestDive, final DiveRecordFacts r) =>
      l10n.insights_observations_deepestDive(units.formatDepth(r.value),
          units.formatDate(r.date), units.formatDepth(r.previousBest)),
    (ObservationRuleId.longestDive, final DiveRecordFacts r) =>
      l10n.insights_observations_longestDive(_minutes(l10n, r.value / 60),
          units.formatDate(r.date), _minutes(l10n, r.previousBest / 60)),
    (ObservationRuleId.newCountry, final NewCountryFacts c) =>
      l10n.insights_observations_newCountry(c.country, units.formatDate(c.date)),
    (ObservationRuleId.newSpecies, final NewSpeciesFacts s) =>
      l10n.insights_observations_newSpecies(s.count, s.newestSpeciesName),
    (ObservationRuleId.diveGap, final DiveGapFacts g) =>
      l10n.insights_observations_diveGap(g.days),
    (ObservationRuleId.favouriteSite, final ShareFacts s) =>
      l10n.insights_observations_favouriteSite(s.subjectName, '${s.dives}', '${s.totalDives}'),
    (ObservationRuleId.regularBuddy, final ShareFacts s) =>
      l10n.insights_observations_regularBuddy(s.subjectName, '${s.dives}', '${s.totalDives}'),
    (ObservationRuleId.busiestMonth, final MonthFacts m) =>
      l10n.insights_observations_busiestMonth(insightsMonthName(l10n, m.month), '${m.years}'),
    (ObservationRuleId.ascentRate, final RateFacts r) =>
      l10n.insights_observations_ascentRate(
        units.formatDepthRate(r.metersPerMin),
        '${r.dives}',
        units.formatDepthRate(ObservationThresholds.ascentRateGuidanceLowMPerMin, decimals: 0),
        units.formatDepthRate(ObservationThresholds.ascentRateGuidanceHighMPerMin, decimals: 0),
      ),
    (final rule, _) => observationRuleLabel(rule, l10n),
  };
}
```

(The generated method parameter order follows the placeholder order in each ARB message's metadata; declare placeholders in the order the calls above pass them. Adjust the tear-off calls if `formatRmv` or `formatDepthRate` signatures differ.)

- [ ] **Step 5: Run tests and commit**

Run: `flutter test test/features/insights/presentation/formatters/observation_sentence_test.dart test/l10n/ test/architecture/`
Expected: PASS.

```bash
dart format lib test
git add lib/l10n/arb lib/features/insights/presentation/formatters test/features/insights/presentation/formatters
git commit -m "feat(insights): observation sentences in 11 languages"
```

---

### Task 14: Observation card and strip

**Files:**
- Create: `lib/features/insights/presentation/widgets/observation_card.dart`
- Create: `lib/features/insights/presentation/widgets/observations_strip.dart`
- Test: `test/features/insights/presentation/widgets/observation_card_test.dart`
- Test: `test/features/insights/presentation/widgets/observations_strip_test.dart`

**Interfaces:**
- Consumes: Tasks 12 and 13.
- Produces: `ObservationCard({required Observation observation})`; `ObservationsStrip()`; `void openObservationTarget(BuildContext, ObservationTarget)`; `void openObservationsPage(BuildContext)`.

- [ ] **Step 1: Write the failing widget tests**

Pump with `getBaseOverrides()`, `MaterialApp.router` on a `GoRouter` holding stub routes for `/insights`, `/insights/:id`, `/dives`, `/dives/:diveId`, `/sites/:siteId`, `/buddies/:buddyId` (each a `Text(state.uri.toString())`), and `locale: const Locale('en')`. Card tests:

- shows the sentence for a dive-gap observation;
- tapping a `DiveTarget` card lands on `/dives/<id>`; an `InsightsCategoryTarget('gas')` card on a phone width pushes `/insights/gas` and on a 1400-wide view goes to `/insights?selected=gas`;
- the overflow (tooltip "Observation actions") shows "Dismiss" and "Don't show this kind"; "Dismiss" calls the repository (override `observationDismissalsRepositoryProvider` with a fake recording calls) and shows "Observation dismissed" with "Undo"; tapping Undo calls `undismiss` with the same rule and fingerprint;
- with no current diver the menu has no "Dismiss";
- a throwing fake `dismiss` shows "Couldn't dismiss the observation";
- "Don't show this kind" calls `setObservationRuleMuted(rule, true)` on the mock notifier, shows "Observations of this kind are hidden", and Undo unmutes.

Strip tests (override `observationStripProvider`):

- `AsyncData([])` and `AsyncLoading()` render nothing (`find.byType(Card)` none, size zero);
- three observations render three cards under the "Observations" header with "See all";
- "See all" pushes `/insights/observations` on a phone and goes to `/insights?selected=observations` on desktop;
- with `insightsFilterProvider` set to an active filter, the filter note shows;
- `AsyncError` shows "Couldn't load observations" and "Retry", and Retry invalidates `observationsProvider` (count builds of an overridden provider).

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/insights/presentation/widgets/observation_card_test.dart test/features/insights/presentation/widgets/observations_strip_test.dart`
Expected: FAIL, files missing.

- [ ] **Step 3: Implement**

`observation_card.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';
import 'package:submersion/features/insights/presentation/formatters/observation_sentence.dart';
import 'package:submersion/features/insights/presentation/providers/observations_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// Opens an Insights category in the detail pane on desktop, or pushes it
/// on a phone, matching how the category list navigates.
void _openInsightsCategory(BuildContext context, String id) {
  if (ResponsiveBreakpoints.isMasterDetail(context)) {
    context.go('/insights?selected=$id');
  } else {
    context.push('/insights/$id');
  }
}

void openObservationsPage(BuildContext context) =>
    _openInsightsCategory(context, 'observations');

void openObservationTarget(BuildContext context, ObservationTarget target) {
  switch (target) {
    case InsightsCategoryTarget(:final categoryId):
      _openInsightsCategory(context, categoryId);
    case DiveTarget(:final diveId):
      context.push('/dives/$diveId');
    case SiteTarget(:final siteId):
      context.push('/sites/$siteId');
    case BuddyTarget(:final buddyId):
      context.push('/buddies/$buddyId');
    case DiveLogTarget():
      context.go('/dives');
  }
}

IconData _icon(Observation o) => switch (o.kind) {
  ObservationKind.safety => Icons.health_and_safety_outlined,
  ObservationKind.milestone => Icons.emoji_events_outlined,
  ObservationKind.trend => switch (o.facts) {
    TrendFacts(direction: TrendDirection.down) => Icons.trending_down,
    _ => Icons.trending_up,
  },
  ObservationKind.pattern => Icons.repeat,
};

enum _Action { dismiss, mute }

class ObservationCard extends ConsumerWidget {
  final Observation observation;
  const ObservationCard({super.key, required this.observation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final scheme = Theme.of(context).colorScheme;
    final canDismiss = ref.watch(currentDiverProvider).valueOrNull != null;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(_icon(observation), color: scheme.primary),
        title: Text(observationSentence(observation, l10n, units)),
        onTap: () => openObservationTarget(context, observation.target),
        trailing: PopupMenuButton<_Action>(
          tooltip: l10n.insights_observations_actions,
          onSelected: (action) => switch (action) {
            _Action.dismiss => _dismiss(context, ref),
            _Action.mute => _mute(context, ref),
          },
          itemBuilder: (context) => [
            if (canDismiss)
              PopupMenuItem(
                value: _Action.dismiss,
                child: Text(l10n.insights_observations_dismiss),
              ),
            PopupMenuItem(
              value: _Action.mute,
              child: Text(l10n.insights_observations_mute),
            ),
          ],
        ),
      ),
    );
  }

  SnackBar _undoBar(String message, String undo, VoidCallback onUndo) =>
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        // An action makes a SnackBar persist by default (#406).
        persist: false,
        showCloseIcon: true,
        action: SnackBarAction(label: undo, onPressed: onUndo),
      );

  Future<void> _dismiss(BuildContext context, WidgetRef ref) async {
    final diver = ref.read(currentDiverProvider).valueOrNull;
    if (diver == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final repo = ref.read(observationDismissalsRepositoryProvider);
    final o = observation;
    try {
      await repo.dismiss(
        diverId: diver.id,
        rule: o.ruleId,
        fingerprint: o.fingerprint,
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.insights_observations_dismissFailed)),
      );
      return;
    }
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        _undoBar(
          l10n.insights_observations_dismissed,
          l10n.insights_observations_undo,
          () => unawaited(
            repo
                .undismiss(
                  diverId: diver.id,
                  rule: o.ruleId,
                  fingerprint: o.fingerprint,
                )
                .catchError((Object _) {}),
          ),
        ),
      );
  }

  Future<void> _mute(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final notifier = ref.read(settingsProvider.notifier);
    final rule = observation.ruleId;
    await notifier.setObservationRuleMuted(rule, true);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        _undoBar(
          l10n.insights_observations_muted,
          l10n.insights_observations_undo,
          () => unawaited(notifier.setObservationRuleMuted(rule, false)),
        ),
      );
  }
}
```

(The undismiss failure is already logged by the repository, so the `catchError` only keeps an unawaited future from surfacing as an unhandled error; if the repo has a `logFailure` helper, use it instead as `condition_findings_card.dart:162-171` does.)

`observations_strip.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/observations_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/observation_card.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Up to three observations at the top of the Insights landing. Takes no
/// space while loading or when there is nothing to say.
class ObservationsStrip extends ConsumerWidget {
  const ObservationsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final strip = ref.watch(observationStripProvider);
    final filtered = ref.watch(
      insightsFilterProvider.select((f) => f.hasActiveFilters),
    );
    return strip.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => StatEmptyState(
        icon: Icons.error_outline,
        message: l10n.insights_observations_error,
        action: l10n.insights_records_retry,
        onAction: () => ref.invalidate(observationsProvider),
      ),
      data: (observations) {
        if (observations.isEmpty) return const SizedBox.shrink();
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.insights_observations_title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton(
                  onPressed: () => openObservationsPage(context),
                  child: Text(l10n.insights_observations_seeAll),
                ),
              ],
            ),
            if (filtered)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.insights_observations_filterNote,
                  key: const Key('observations-filter-note'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (final o in observations) ...[
              ObservationCard(observation: o),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}
```

(Check `StatEmptyState`'s exact parameter names in `stat_section_card.dart` before using it.)

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/insights/presentation/widgets/ test/architecture/`
Expected: PASS (including `list_tile_trailing_width_test`, since the trailing is a `PopupMenuButton`).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/insights test/features/insights
git add lib/features/insights/presentation/widgets test/features/insights/presentation/widgets
git commit -m "feat(insights): observation card and landing strip"
```

---

### Task 15: Observations page, route and muted kinds

**Files:**
- Create: `lib/features/insights/presentation/pages/insights_observations_page.dart`
- Create: `lib/features/insights/presentation/widgets/muted_observation_kinds_sheet.dart`
- Modify: `lib/core/router/app_router.dart` (insights child routes ~894-964; imports ~85-96)
- Modify: `lib/features/insights/presentation/pages/insights_page.dart` (`_buildCategoryPage` switch)
- Test: `test/features/insights/presentation/pages/insights_observations_page_test.dart`
- Modify: `test/core/router/app_router_test.dart` (one `findMatch` test)

**Interfaces:**
- Consumes: Tasks 12 to 14.
- Produces: `InsightsObservationsPage({bool embedded = false})`; `Future<void> showMutedObservationKinds(BuildContext context)`; route name `insightsObservations`, path `/insights/observations`.

- [ ] **Step 1: Write the failing tests**

Page tests (override `observationsProvider`):

- lists every observation (five in, five cards);
- an empty list shows "Observations appear as your log grows";
- an error shows the error text and Retry;
- the filter note shows under an active filter;
- not embedded: an app bar titled "Observations" with an action tooltip "Muted kinds"; embedded: no `AppBar`, a header row with the same action;
- the muted-kinds sheet lists "RMV trend" when `insightsMutedObservationRules` is `{'rmvTrend', 'fromANewerBuild'}` (the unknown id is not listed), Unmute removes `rmvTrend` and keeps `fromANewerBuild`; with nothing muted it says "No kinds are muted".

Router test: `findMatch(Uri.parse('/insights/observations')).fullPath == '/insights/observations'`, and `_findRouteByName(..., 'insightsObservations')` is non-null.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/insights/presentation/pages/insights_observations_page_test.dart test/core/router/app_router_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`muted_observation_kinds_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/presentation/formatters/observation_sentence.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

Future<void> showMutedObservationKinds(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => const SafeArea(child: _MutedKindsSheet()),
    );

class _MutedKindsSheet extends ConsumerWidget {
  const _MutedKindsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = ref.watch(
      settingsProvider.select((s) => s.insightsMutedObservationRules),
    );
    // A newer build's rule ids stay stored but are not listed here.
    final rules = [
      for (final rule in ObservationRuleId.values)
        if (muted.contains(rule.dbValue)) rule,
    ];
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              l10n.insights_observations_mutedKinds,
              style: theme.textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          if (rules.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.insights_observations_mutedKinds_empty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final rule in rules)
                    ListTile(
                      title: Text(observationRuleLabel(rule, l10n)),
                      trailing: IconButton(
                        icon: const Icon(Icons.visibility_outlined),
                        tooltip: l10n.insights_observations_unmute,
                        onPressed: () => ref
                            .read(settingsProvider.notifier)
                            .setObservationRuleMuted(rule, false),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
```

`insights_observations_page.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/insights/presentation/providers/insights_filter_provider.dart';
import 'package:submersion/features/insights/presentation/providers/observations_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/muted_observation_kinds_sheet.dart';
import 'package:submersion/features/insights/presentation/widgets/observation_card.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Every observation for the current diver, ranked (spec section 5.4).
class InsightsObservationsPage extends ConsumerWidget {
  final bool embedded;
  const InsightsObservationsPage({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final observations = ref.watch(observationsProvider);
    final filtered = ref.watch(
      insightsFilterProvider.select((f) => f.hasActiveFilters),
    );
    final mutedAction = IconButton(
      icon: const Icon(Icons.visibility_off_outlined),
      tooltip: l10n.insights_observations_mutedKinds,
      onPressed: () => showMutedObservationKinds(context),
    );
    final body = observations.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => StatEmptyState(
        icon: Icons.error_outline,
        message: l10n.insights_observations_error,
        action: l10n.insights_records_retry,
        onAction: () => ref.invalidate(observationsProvider),
      ),
      data: (list) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (embedded)
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.insights_observations_title,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                mutedAction,
              ],
            ),
          if (filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.insights_observations_filterNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (list.isEmpty)
            StatEmptyState(
              icon: Icons.insights_outlined,
              message: l10n.insights_observations_empty,
            ),
          for (final o in list) ...[
            ObservationCard(observation: o),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.insights_observations_title),
        actions: [mutedAction],
      ),
      body: body,
    );
  }
}
```

`app_router.dart`, inside the `/insights` routes list (static paths before parameterised ones):

```dart
          GoRoute(
            path: 'observations',
            name: 'insightsObservations',
            builder: (context, state) => const InsightsObservationsPage(),
          ),
```

`insights_page.dart` `_buildCategoryPage`:

```dart
      case 'observations':
        return const InsightsObservationsPage(embedded: true);
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/insights/presentation/pages/ test/core/router/app_router_test.dart test/architecture/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/core/router/app_router.dart lib/features/insights/presentation test/features/insights/presentation/pages test/core/router/app_router_test.dart
git commit -m "feat(insights): observations page and muted kinds"
```

---

### Task 16: Place the strip on the landing

**Files:**
- Modify: `lib/features/insights/presentation/pages/insights_page.dart` (`summaryBuilder`; `InsightsMobileContent` list)
- Modify: `lib/features/insights/presentation/pages/insights_overview_page.dart` (`showObservations` flag; `_OverviewBody` children)
- Test: `test/features/insights/presentation/pages/insights_page_content_test.dart` (extend)
- Test: `test/features/insights/presentation/pages/insights_overview_page_test.dart` (extend)

**Interfaces:**
- Consumes: Task 14 `ObservationsStrip`.
- Produces: `InsightsOverviewPage({bool embedded = false, bool showObservations = false})`.

- [ ] **Step 1: Write the failing tests**

- `InsightsMobileContent` with `observationStripProvider` overridden to three observations shows the strip above the first category tile (the strip's top `dy` is less than the Overview tile's) and the list still scrolls to the last category;
- with an empty strip, the first category tile sits where it did before (no gap: compare its top against a pump with the strip provider never resolving);
- `InsightsOverviewPage(embedded: true, showObservations: true)` shows the strip above the aggregate grid; `InsightsOverviewPage(embedded: true)` (the Overview category detail) does not.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/insights/presentation/pages/insights_page_content_test.dart test/features/insights/presentation/pages/insights_overview_page_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

`insights_page.dart`: `summaryBuilder: (context) => const InsightsOverviewPage(embedded: true, showObservations: true),`. In `InsightsMobileContent`, replace the `ListView.separated` with a `ListView` that keeps the existing separators and leads with the strip:

```dart
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: ObservationsStrip(),
                ),
                for (final (index, category)
                    in insightsCategoriesOf(context).indexed) ...[
                  if (index == 1) const Divider(height: 16, thickness: 1),
                  if (index > 1) const Divider(height: 1),
                  _InsightsCategoryTile(
                    category: category,
                    onTap: () => context.push(category.location),
                  ),
                ],
              ],
            ),
          ),
```

(An empty strip is a zero-size `SizedBox`, but the `Padding` around it adds 8 px: move the padding inside `ObservationsStrip`'s data branch instead, through an optional `padding` parameter, so an empty strip is truly zero-size. Adjust Task 14's widget accordingly and keep its tests green.)

`insights_overview_page.dart`: add `final bool showObservations;` with default `false` to `InsightsOverviewPage`, pass it to `_OverviewBody`, and insert before `_AggregateGrid`:

```dart
            if (showObservations) ...[
              const ObservationsStrip(),
              const SizedBox(height: 16),
            ],
```

(Same zero-size rule: put the trailing gap inside the strip's data branch so an empty strip adds no space.)

- [ ] **Step 4: Run Insights tests**

Run: `flutter test test/features/insights/ test/architecture/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/insights/presentation test/features/insights/presentation
git commit -m "feat(insights): show observations at the top of the Insights landing"
```

---

### Task 17: Whole-branch verification

- [ ] **Step 1:** `dart format .` then `git status --porcelain` (nothing unformatted).
- [ ] **Step 2:** `flutter analyze` (zero issues).
- [ ] **Step 3:** `flutter test test/architecture/ test/l10n/ test/core/database/ test/core/services/sync/ test/features/insights/ test/features/settings/ test/features/divers/ test/core/router/` (all pass).
- [ ] **Step 4:** Verify `flutter gen-l10n` leaves no diff (`git status --porcelain -- 'lib/l10n/arb/app_localizations*.dart'` empty).
- [ ] **Step 5:** Launch the app (run skill) on a library with a year-plus of dives; confirm the strip on phone and desktop widths, the Observations page, dismiss with Undo, mute and unmute, and the filter note, in light and dark. Capture the after screenshots for the PR.
