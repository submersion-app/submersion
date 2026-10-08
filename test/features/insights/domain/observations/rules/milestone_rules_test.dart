import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';
import 'package:submersion/features/insights/domain/observations/rules/milestone_rules.dart';

import '../observation_fixtures.dart';

List<ObservationDive> nDives(int n, {int endDaysAgo = 5}) =>
    divesIn(prefix: 'd', count: n, endDaysAgo: endDaysAgo, spanDays: 600);

void main() {
  test('milestone ladders', () {
    expect(
      [
        50,
        100,
        150,
        200,
        250,
        300,
        400,
        500,
        750,
        1000,
      ].every(isDiveCountMilestone),
      isTrue,
    );
    expect([10, 25, 350, 450, 600, 800].any(isDiveCountMilestone), isFalse);
    expect([25, 50, 100, 200, 300].every(isDiveHoursMilestone), isTrue);
    expect([75, 150, 250].any(isDiveHoursMilestone), isFalse);
  });

  group('diveCountMilestoneRule', () {
    test('the 100th dive, logged recently, fires', () {
      final out = diveCountMilestoneRule(
        ObservationInputs(now: now, dives: nDives(100)),
      );
      final f = out.single.facts as MilestoneFacts;
      expect(f.milestone, 100);
      expect(f.includesPrior, isFalse);
      expect(out.single.fingerprint, '100');
      expect(out.single.target, DiveTarget(f.diveId));
    });

    test('prior dives count toward the career number', () {
      final out = diveCountMilestoneRule(
        ObservationInputs(now: now, dives: nDives(10), priorDives: 140),
      );
      final f = out.single.facts as MilestoneFacts;
      expect(f.milestone, 150);
      expect(f.includesPrior, isTrue);
    });

    test('a milestone the prior count alone reached never fires', () {
      expect(
        diveCountMilestoneRule(
          ObservationInputs(now: now, dives: nDives(3), priorDives: 100),
        ),
        isEmpty,
      );
    });

    test('an old crossing does not fire', () {
      expect(
        diveCountMilestoneRule(
          ObservationInputs(now: now, dives: nDives(100, endDaysAgo: 200)),
        ),
        isEmpty,
      );
    });

    test('prior experience only, no logged dives: nothing', () {
      final inputs = ObservationInputs(
        now: now,
        priorDives: 500,
        priorTimeSeconds: 900000,
      );
      expect(diveCountMilestoneRule(inputs), isEmpty);
      expect(diveHoursMilestoneRule(inputs), isEmpty);
      expect(deepestDiveRule(inputs), isEmpty);
      expect(newCountryRule(inputs), isEmpty);
      expect(newSpeciesRule(inputs), isEmpty);
    });
  });

  test('diveHoursMilestoneRule: crossing 50 hours on a recent dive', () {
    final dives = [
      for (var k = 0; k < 49; k++)
        dive('o$k', daysAgo(300 + k), runtimeSeconds: 3600),
      dive('cross', daysAgo(3), runtimeSeconds: 5400),
    ]..sort((a, b) => a.date.compareTo(b.date));
    final out = diveHoursMilestoneRule(
      ObservationInputs(now: now, dives: dives),
    );
    final f = out.single.facts as MilestoneFacts;
    expect(f.milestone, 50);
    expect(f.diveId, 'cross');
  });

  group('records', () {
    List<ObservationDive> depths(List<double> values) => [
      for (var k = 0; k < values.length; k++)
        dive(
          'd$k',
          daysAgo(300 - k * 20),
          maxDepthM: values[k],
          runtimeSeconds: (values[k] * 100).round(),
        ),
    ];
    final values = <double>[18, 20, 22, 19, 25, 21, 24, 23, 20, 22, 26, 31];

    test('a recent new deepest dive after 9 earlier dives fires', () {
      final out = deepestDiveRule(
        ObservationInputs(now: now, dives: depths(values)),
      );
      final f = out.single.facts as DiveRecordFacts;
      expect(f.value, 31);
      expect(f.previousBest, 26);
      expect(out.single.fingerprint, 'd11');
    });

    test('fewer than 10 measured dives: nothing', () {
      expect(
        deepestDiveRule(
          ObservationInputs(now: now, dives: depths([10, 12, 14])),
        ),
        isEmpty,
      );
    });

    test('longestDiveRule tracks runtime', () {
      final out = longestDiveRule(
        ObservationInputs(now: now, dives: depths(values)),
      );
      expect((out.single.facts as DiveRecordFacts).value, 3100);
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
      expect(
        newCountryRule(
          ObservationInputs(
            now: now,
            dives: [dive('a', daysAgo(20), country: 'Egypt')],
          ),
        ),
        isEmpty,
      );
    });
  });

  test('newSpeciesRule: count and newest', () {
    final out = newSpeciesRule(
      ObservationInputs(
        now: now,
        dives: [dive('old', daysAgo(500))],
        species: [
          ObservationSpecies(id: 's1', name: 'Manta', firstSeen: daysAgo(400)),
          ObservationSpecies(
            id: 's2',
            name: 'Whale shark',
            firstSeen: daysAgo(40),
          ),
          ObservationSpecies(id: 's3', name: 'Mola', firstSeen: daysAgo(10)),
        ],
      ),
    );
    final f = out.single.facts as NewSpeciesFacts;
    expect(f.count, 2);
    expect(f.newestSpeciesName, 'Mola');
    expect(out.single.fingerprint, '2:s3');
    expect(out.single.target, const InsightsCategoryTarget('marine-life'));
  });
}
