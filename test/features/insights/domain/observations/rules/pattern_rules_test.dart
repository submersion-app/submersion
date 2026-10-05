import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';
import 'package:submersion/features/insights/domain/observations/rules/pattern_rules.dart';

import '../observation_fixtures.dart';

List<ObservationDive> byDate(List<ObservationDive> dives) =>
    [...dives]..sort((a, b) => a.date.compareTo(b.date));

void main() {
  group('diveGapRule', () {
    test('fires at 90 days, keyed on the last dive', () {
      final out = diveGapRule(
        ObservationInputs(
          now: now,
          dives: [dive('a', daysAgo(200)), dive('b', daysAgo(120))],
        ),
      );
      expect((out.single.facts as DiveGapFacts).days, 120);
      expect(out.single.fingerprint, 'b');
      expect(out.single.target, const DiveLogTarget());
    });

    test('silent under 90 days, with no dives, or with a future dive', () {
      expect(
        diveGapRule(
          ObservationInputs(now: now, dives: [dive('a', daysAgo(89))]),
        ),
        isEmpty,
      );
      expect(diveGapRule(ObservationInputs(now: now)), isEmpty);
      expect(
        diveGapRule(
          ObservationInputs(
            now: now,
            dives: [
              dive('a', daysAgo(200)),
              dive('f', now.add(const Duration(days: 30))),
            ],
          ),
        ),
        isEmpty,
      );
    });
  });

  group('favouriteSiteRule', () {
    List<ObservationDive> log(int atHome, int elsewhere) => byDate([
      for (var k = 0; k < atHome; k++)
        dive('h$k', daysAgo(10 + k * 7), siteId: 'home', siteName: 'Blue Hole'),
      for (var k = 0; k < elsewhere; k++)
        dive('e$k', daysAgo(12 + k * 7), siteId: 'e$k', siteName: 'Other $k'),
    ]);

    test('5 of 20 (25%) fires', () {
      final out = favouriteSiteRule(
        ObservationInputs(now: now, dives: log(5, 15)),
      );
      final f = out.single.facts as ShareFacts;
      expect([f.subjectName, f.dives, f.totalDives], ['Blue Hole', 5, 20]);
      expect(out.single.target, const SiteTarget('home'));
    });

    test('4 dives is too few; 5 of 21 is under 25%', () {
      expect(
        favouriteSiteRule(ObservationInputs(now: now, dives: log(4, 4))),
        isEmpty,
      );
      expect(
        favouriteSiteRule(ObservationInputs(now: now, dives: log(5, 16))),
        isEmpty,
      );
    });
  });

  test('regularBuddyRule: 40% of the last 12 months, once per dive', () {
    const sam = ObservationBuddy(id: 'b1', name: 'Sam');
    final dives = byDate([
      for (var k = 0; k < 10; k++)
        dive(
          'd$k',
          daysAgo(10 + k * 20),
          // A buddy linked twice to one dive (two roles) counts once.
          buddies: k < 4 ? const [sam, sam] : const [],
        ),
      dive('old', daysAgo(500), buddies: const [sam]),
    ]);
    expect(
      regularBuddyRule(ObservationInputs(now: now, dives: dives)),
      isEmpty,
    );
    final more = byDate([
      ...dives,
      dive('d10', daysAgo(5), buddies: const [sam]),
    ]);
    final out = regularBuddyRule(ObservationInputs(now: now, dives: more));
    expect((out.single.facts as ShareFacts).dives, 5);
    expect(out.single.target, const BuddyTarget('b1'));
  });

  test('busiestMonthRule: the same month leads in two years', () {
    List<ObservationDive> year(int y, int leadMonth) => [
      for (var k = 0; k < 4; k++)
        dive('$y-l$k', DateTime.utc(y, leadMonth, 2 + k)),
      dive('$y-x', DateTime.utc(y, leadMonth == 1 ? 2 : 1, 5)),
    ];
    final out = busiestMonthRule(
      ObservationInputs(
        now: now,
        dives: byDate([...year(2023, 8), ...year(2024, 8), ...year(2025, 3)]),
      ),
    );
    final f = out.single.facts as MonthFacts;
    expect([f.month, f.years], [8, 2]);
    expect(out.single.fingerprint, '8');
    expect(
      busiestMonthRule(
        ObservationInputs(
          now: now,
          dives: byDate([...year(2023, 8), ...year(2024, 9)]),
        ),
      ),
      isEmpty,
    );
  });
}
