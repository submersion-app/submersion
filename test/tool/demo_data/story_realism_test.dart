import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/demo_data/src/story/catalog.dart';
import '../../../tool/demo_data/src/story/destinations.dart';
import '../../../tool/demo_data/src/story/story_plan.dart';
import '../../../tool/demo_data/src/story/story_planner.dart';

/// The story as a whole, the way a diver reading the logbook would judge it,
/// over several seeds and anchors.
void main() {
  late Catalog catalog;
  final plans = <String, StoryPlan>{};

  setUpAll(() {
    catalog = Catalog.load('assets/data');
    for (final seed in [42, 1, 7]) {
      for (final anchor in [DateTime(2026, 10, 1), DateTime(2026, 10, 27)]) {
        plans['seed $seed, ${anchor.month}/${anchor.day}'] = StoryPlanner(
          Random(seed),
          catalog,
        ).plan(anchor: anchor);
      }
    }
  });

  void eachPlan(void Function(String name, StoryPlan plan) check) =>
      plans.forEach(check);

  test('every course is one run of dives at one place within 14 days', () {
    eachPlan((name, plan) {
      for (final course in plan.courses) {
        final dives = plan.dives.where((d) => d.courseId == course.id).toList();
        expect(dives, isNotEmpty, reason: '$name ${course.id}');
        expect(
          {for (final d in dives) '${d.destination.key}|${d.tripId}'},
          hasLength(1),
          reason: '$name ${course.id}',
        );
        final numbers = [for (final d in dives) d.number];
        expect(
          numbers.last - numbers.first,
          numbers.length - 1,
          reason: '$name ${course.id} is not consecutive',
        );
        expect(
          dives.last.start.difference(dives.first.start).inDays,
          lessThanOrEqualTo(14),
          reason: '$name ${course.id}',
        );
      }
    });
  });

  test('the Open Water course is the first four dives', () {
    eachPlan((name, plan) {
      final ow = plan.dives.where((d) => d.courseId == 'course-openWater');
      expect([for (final d in ow) d.number], [1, 2, 3, 4], reason: name);
    });
  });

  test('the rebreather phase is dived at home', () {
    eachPlan((name, plan) {
      final ccr = plan.dives.where((d) => d.diveMode == 'ccr');
      expect(
        ccr.every((d) => d.destination.key == 'home'),
        isTrue,
        reason: name,
      );
      final swap = plan.milestones[StoryMilestone.cellSwap]!;
      expect(
        ccr.where((d) => d.number >= swap).length,
        greaterThanOrEqualTo(4),
        reason: name,
      );
    });
  });

  test('the newest dive is in the last week before the anchor', () {
    eachPlan((name, plan) {
      final gap = plan.anchor.difference(plan.dives.last.start);
      expect(gap.inHours, greaterThan(0), reason: name);
      expect(gap.inDays, lessThan(7), reason: name);
    });
  });

  test('springs are dived at cavern depth, without technical dives', () {
    eachPlan((name, plan) {
      for (final d in plan.dives.where(
        (d) => d.destination.key == 'florida-springs',
      )) {
        expect(
          d.targetMaxDepth,
          lessThanOrEqualTo(20),
          reason: '$name ${d.number}',
        );
        expect(d.tankCount, 1, reason: '$name ${d.number}');
      }
    });
  });

  test('rebreather dives stay within a CCR card', () {
    eachPlan((name, plan) {
      for (final d in plan.dives.where((d) => d.diveMode == 'ccr')) {
        expect(
          d.targetMaxDepth,
          lessThanOrEqualTo(40),
          reason: '$name ${d.number}',
        );
      }
    });
  });

  test('the tech team travels only with a trip that took one of them', () {
    eachPlan((name, plan) {
      final tech = {
        for (final p in plan.people)
          if (p.role == PersonRole.techTeam) p.id,
      };
      final perTrip = <String, Set<String>>{};
      for (final d in plan.dives.where((d) => d.tripId != null)) {
        perTrip
            .putIfAbsent(d.tripId!, () => {})
            .addAll(d.buddyIds.where(tech.contains));
      }
      for (final MapEntry(key: trip, value: who) in perTrip.entries) {
        expect(who.length, lessThanOrEqualTo(1), reason: '$name $trip');
      }
      expect(
        perTrip.values.where((w) => w.isNotEmpty).length,
        lessThan(plan.trips.length ~/ 3),
        reason: name,
      );
    });
  });

  test("a day's dive sites are within 60 km of each other", () {
    eachPlan((name, plan) {
      final sites = {for (final s in plan.sites) s.id: s};
      final byDay = <String, List<CatalogSite>>{};
      for (final d in plan.dives) {
        byDay
            .putIfAbsent(
              '${d.start.year}-${d.start.month}-${d.start.day}',
              () => [],
            )
            .add(sites[d.siteId]!);
      }
      for (final MapEntry(key: day, value: list) in byDay.entries) {
        for (final a in list) {
          for (final b in list) {
            expect(
              kmBetween(a.latitude, a.longitude, b.latitude, b.longitude),
              lessThan(60),
              reason: '$name $day ${a.name} / ${b.name}',
            );
          }
        }
      }
    });
  });

  test('a resort dive centre is near the sites it dives', () {
    eachPlan((name, plan) {
      final sites = {for (final s in plan.sites) s.id: s};
      final centers = {for (final c in plan.centers) c.id: c};
      var near = 0;
      var located = 0;
      for (final d in plan.dives) {
        final c = centers[d.centerId];
        if (c == null || c.latitude == null || d.destination.liveaboard) {
          continue;
        }
        located++;
        final s = sites[d.siteId]!;
        if (kmBetween(c.latitude!, c.longitude!, s.latitude, s.longitude) <
            60) {
          near++;
        }
      }
      expect(near / located, greaterThan(0.9), reason: name);
    });
  });
}
