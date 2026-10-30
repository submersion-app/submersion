import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/demo_data/src/shape/dive_shape.dart';
import '../../../tool/demo_data/src/shape/shape_budget.dart';
import '../../../tool/demo_data/src/story/catalog.dart';
import '../../../tool/demo_data/src/story/destinations.dart';
import '../../../tool/demo_data/src/story/story_plan.dart';
import '../../../tool/demo_data/src/story/story_planner.dart';
import 'synthetic_shapes.dart';

void main() {
  final anchor = DateTime(2026, 10, 1);
  late Catalog catalog;
  late StoryPlan plan;

  setUpAll(() {
    catalog = Catalog.load('assets/data');
    plan = StoryPlanner(Random(42), catalog).plan(anchor: anchor);
  });

  Map<String, int> appearances() {
    final counts = <String, int>{};
    for (final d in plan.dives) {
      for (final id in d.buddyIds) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    return counts;
  }

  FictionalPerson person(String id) =>
      plan.people.firstWhere((p) => p.id == id);

  test('about 700 dives over six years before the anchor, in order', () {
    expect(plan.dives.length, 700);
    expect(
      plan.dives.first.start.isAfter(DateTime(anchor.year - 6, anchor.month)),
      isTrue,
    );
    expect(plan.dives.last.start.isBefore(anchor), isTrue);
    for (var i = 1; i < plan.dives.length; i++) {
      final prev = plan.dives[i - 1];
      expect(
        plan.dives[i].start.isAfter(prev.start.add(prev.plannedDuration)),
        isTrue,
        reason: 'dive ${plan.dives[i].number} overlaps the one before',
      );
      expect(plan.dives[i].number, prev.number + 1);
    }
  });

  test('phases run recreational, technical OC, then 15 CCR dives', () {
    final phases = [for (final d in plan.dives) d.phase];
    final firstTech = phases.indexOf(StoryPhase.technicalOc);
    final firstCcr = phases.indexOf(StoryPhase.rebreather);
    // The deco course opens the technical phase, placed near dive 250.
    expect(firstTech + 1, plan.milestones[StoryMilestone.techStart]);
    expect(firstTech + 1, inInclusiveRange(220, 280));
    expect(firstCcr, greaterThan(firstTech));
    expect(
      phases.sublist(firstTech).contains(StoryPhase.recreational),
      isFalse,
    );
    final ccr = plan.dives.where((d) => d.diveMode == 'ccr').toList();
    // Five rebreather shapes reach a first card's depths, three uses each.
    expect(ccr.length, 15);
    expect(ccr.every((d) => d.phase == StoryPhase.rebreather), isTrue);
  });

  test('each certification is issued before the first dive that needs it', () {
    for (final d in plan.dives) {
      final needed = d.requiresCert;
      if (needed == null) continue;
      final cert = plan.certs.firstWhere((c) => c.level == needed);
      expect(
        cert.issueDate.isAfter(d.start),
        isFalse,
        reason: 'dive ${d.number} needs ${needed.name}',
      );
    }
    expect(plan.certs.map((c) => c.level), contains(CertLevel.ccr));
  });

  test('every course has training dives inside its own dates', () {
    for (final course in plan.courses) {
      final dives = plan.dives.where((d) => d.courseId == course.id);
      expect(dives, isNotEmpty, reason: course.name);
      for (final d in dives) {
        expect(d.start.isBefore(course.start), isFalse, reason: course.name);
        expect(
          d.start.isAfter(course.end.add(const Duration(days: 1))),
          isFalse,
        );
      }
    }
  });

  test('6 to 8 trips in every year, never overlapping', () {
    final trips = [...plan.trips]..sort((a, b) => a.start.compareTo(b.start));
    for (var i = 1; i < trips.length; i++) {
      expect(
        trips[i].start.difference(trips[i - 1].end).inDays,
        greaterThanOrEqualTo(10),
        reason: '${trips[i - 1].id} and ${trips[i].id}',
      );
    }
    // The schedule's own years, counted back from the anchor.
    final start = DateTime(anchor.year - 6, anchor.month, anchor.day + 7);
    final end = DateTime(anchor.year, anchor.month, anchor.day - 1);
    final yearDays = end.difference(start).inDays / 6;
    for (var y = 0; y < 6; y++) {
      final from = start.add(Duration(days: (y * yearDays).round()));
      final to = start.add(Duration(days: ((y + 1) * yearDays).round()));
      final count = trips
          .where((t) => !t.start.isBefore(from) && t.start.isBefore(to))
          .length;
      expect(count, inInclusiveRange(6, 8), reason: 'year $y');
    }
  });

  test('every dive on a trip falls within the trip', () {
    final trips = {for (final t in plan.trips) t.id: t};
    for (final d in plan.dives.where((d) => d.tripId != null)) {
      final t = trips[d.tripId]!;
      expect(d.start.isBefore(t.start), isFalse);
      expect(d.start.isAfter(t.end.add(const Duration(days: 1))), isFalse);
    }
  });

  test('at least 20 destinations and 30 dive centres used', () {
    // Half the trips revisit seven Caribbean islands and one a year is a
    // weekend near home (the maintainer's choices), which leaves about 16
    // trips for somewhere new.
    expect(
      {for (final d in plan.dives) d.destination.key}.length,
      greaterThanOrEqualTo(20),
    );
    expect(
      {for (final d in plan.dives) ?d.centerId}.length,
      greaterThanOrEqualTo(30),
    );
  });

  test("every trip dive's centre is one of its trip's centres", () {
    final trips = {for (final t in plan.trips) t.id: t};
    final catalogIds = {for (final c in catalog.centers) c.id};
    for (final d in plan.dives) {
      if (d.centerId == null) continue;
      expect(catalogIds, contains(d.centerId));
      if (d.tripId != null) {
        expect(trips[d.tripId]!.centerIds, contains(d.centerId));
      }
    }
  });

  test('every site comes from the destination it is dived at', () {
    for (final d in plan.dives) {
      final sites = {
        for (final s in catalogSitesFor(d.destination, catalog)) s.id,
      };
      expect(sites, contains(d.siteId), reason: 'dive ${d.number}');
    }
  });

  test('60 to 100 people, skewed to a few', () {
    expect(plan.people.length, inInclusiveRange(60, 100));
    final counts = appearances().values.toList()..sort((a, b) => b - a);
    final total = counts.fold(0, (a, b) => a + b);
    expect(counts.take(8).fold(0, (a, b) => a + b) * 2, greaterThan(total));
    expect(counts.where((c) => c <= 5).length, greaterThanOrEqualTo(30));
    expect(appearances().length, plan.people.length);
  });

  test(
    'guides dive only at their destination, instructors only on their course',
    () {
      for (final d in plan.dives) {
        for (final id in d.buddyIds) {
          final p = person(id);
          if (p.role == PersonRole.guide) {
            expect(
              p.destinationKey,
              d.destination.key,
              reason: 'dive ${d.number}',
            );
          }
          if (p.role == PersonRole.instructor) {
            final course = plan.courses.firstWhere((c) => c.id == d.courseId);
            expect(course.level, p.course, reason: 'dive ${d.number}');
          }
        }
      }
    },
  );

  test('the tech team appears only on technical or rebreather dives', () {
    for (final d in plan.dives) {
      for (final id in d.buddyIds) {
        if (person(id).role == PersonRole.techTeam) {
          expect(d.phase, isNot(StoryPhase.recreational));
          expect(d.wantedKinds, isNot(contains(ShapeKind.recreational)));
        }
      }
    }
  });

  test(
    'scooter dives come after the scooter milestone and never in a spring',
    () {
      final from = plan.milestones[StoryMilestone.scooter]!;
      final scooter = plan.dives.where((d) => d.scooter).toList();
      expect(scooter.length, greaterThanOrEqualTo(15));
      for (final d in scooter) {
        expect(d.number, greaterThanOrEqualTo(from));
        expect(d.destination.scooterOk, isTrue);
        expect(d.tankCount > 1 || d.diveMode == 'ccr', isTrue);
      }
    },
  );

  test('every milestone is a dive of the story, in story order', () {
    final m = plan.milestones;
    expect(m.keys.toSet(), StoryMilestone.values.toSet());
    expect(m[StoryMilestone.firstDive], 1);
    expect(m[StoryMilestone.techStart], inInclusiveRange(220, 280));
    expect(
      m[StoryMilestone.ownRegulator]!,
      greaterThan(m[StoryMilestone.firstTrip]!),
    );
    expect(m[StoryMilestone.drysuit]!, lessThan(m[StoryMilestone.techStart]!));
    expect(
      m[StoryMilestone.scooter]!,
      greaterThan(m[StoryMilestone.techStart]!),
    );
    expect(
      m[StoryMilestone.cellSwap]!,
      greaterThan(m[StoryMilestone.ccrCourse]!),
    );
    expect(m[StoryMilestone.cellSwap]!, lessThan(plan.dives.length - 4));
  });

  test('before the drysuit, home dives stay in the warm months', () {
    final drysuit = plan.milestones[StoryMilestone.drysuit]!;
    for (final d in plan.dives.where(
      (d) => d.destination.key == 'home' && d.number < drysuit,
    )) {
      if (d.courseId != null) continue;
      expect(d.start.month, inInclusiveRange(5, 9), reason: 'dive ${d.number}');
    }
  });

  test('water temperature follows the destination and the season', () {
    for (final d in plan.dives) {
      final (lo, hi) = d.destination.waterTempC;
      expect(
        d.waterTempC,
        inInclusiveRange(lo, hi),
        reason: 'dive ${d.number}',
      );
    }
    final home = plan.dives.where((d) => d.destination.key == 'home');
    // Home diving keeps to the boat season, so April stands for the cold.
    final august = home
        .where((d) => d.start.month == 8)
        .map((d) => d.waterTempC);
    final april = home
        .where((d) => d.start.month == 4)
        .map((d) => d.waterTempC);
    expect(august.reduce(min), greaterThan(april.reduce(max)));
  });

  test(
    'no technical-phase dive deeper than 45 m uses a recreational shape kind',
    () {
      for (final d in plan.dives) {
        if (d.phase == StoryPhase.recreational || d.targetMaxDepth <= 45) {
          continue;
        }
        expect(d.wantedKinds, isNot(contains(ShapeKind.recreational)));
      }
    },
  );

  test('the synthetic shapes cover the story', () {
    expect(shapeShortfalls(plan, syntheticShapes()), isEmpty);
  });

  test('the same seed plans the same story', () {
    final again = StoryPlanner(Random(42), catalog).plan(anchor: anchor);

    expect(
      [for (final d in again.dives) '${d.start}|${d.siteId}|${d.buddyIds}'],
      [for (final d in plan.dives) '${d.start}|${d.siteId}|${d.buddyIds}'],
    );
  });

  test('a refused name changes only that person', () {
    final name = plan.people[20].name;
    final again = StoryPlanner(
      Random(42),
      catalog,
      refusedNames: {name},
    ).plan(anchor: anchor);

    expect(again.people[20].name, isNot(name));
    expect(
      [for (final d in again.dives) '${d.start}|${d.siteId}'],
      [for (final d in plan.dives) '${d.start}|${d.siteId}'],
    );
  });
}
