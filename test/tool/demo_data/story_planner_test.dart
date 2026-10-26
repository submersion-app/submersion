import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/demo_data/src/shape/dive_shape.dart';
import '../../../tool/demo_data/src/story/catalog.dart';
import '../../../tool/demo_data/src/story/story_plan.dart';
import '../../../tool/demo_data/src/story/story_planner.dart';

void main() {
  final anchor = DateTime(2026, 10, 1);
  late Catalog catalog;
  late StoryPlan plan;

  setUpAll(() {
    catalog = Catalog.load('assets/data');
    plan = StoryPlanner(Random(42), catalog).plan(anchor: anchor);
  });

  test('about 300 dives over six years before the anchor, in order', () {
    expect(plan.dives.length, 300);
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

  test('phases run recreational, technical OC, then 8 to 12 CCR dives', () {
    final phases = [for (final d in plan.dives) d.phase];
    final firstTech = phases.indexOf(StoryPhase.technicalOc);
    final firstCcr = phases.indexOf(StoryPhase.rebreather);
    expect(firstTech, greaterThan(100));
    expect(firstCcr, greaterThan(firstTech));
    expect(
      phases.sublist(firstTech).contains(StoryPhase.recreational),
      isFalse,
    );
    final ccr = plan.dives.where((d) => d.diveMode == 'ccr').length;
    expect(ccr, inInclusiveRange(8, 12));
    expect(
      plan.dives
          .where((d) => d.diveMode == 'ccr')
          .every((d) => d.phase == StoryPhase.rebreather),
      isTrue,
    );
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

  test('every site and centre comes from the bundled catalogues', () {
    final siteIds = {for (final s in catalog.sites) s.id};
    final centerIds = {for (final c in catalog.centers) c.id};
    for (final d in plan.dives) {
      expect(siteIds, contains(d.siteId));
    }
    for (final t in plan.trips) {
      if (t.centerId != null) expect(centerIds, contains(t.centerId));
    }
  });

  test('every dive on a trip falls within the trip', () {
    final trips = {for (final t in plan.trips) t.id: t};
    for (final d in plan.dives.where((d) => d.tripId != null)) {
      final t = trips[d.tripId]!;
      expect(d.start.isBefore(t.start), isFalse);
      expect(d.start.isAfter(t.end.add(const Duration(days: 1))), isFalse);
    }
    expect(plan.trips.length, greaterThanOrEqualTo(12));
  });

  test('wanted kinds follow the phase', () {
    for (final d in plan.dives) {
      switch (d.phase) {
        case StoryPhase.recreational:
          expect(d.wantedKinds, contains(ShapeKind.recreational));
        case StoryPhase.rebreather:
          expect(
            d.wantedKinds.contains(ShapeKind.ccr) || d.diveMode == 'oc',
            isTrue,
          );
        case StoryPhase.technicalOc:
          break;
      }
    }
  });

  test('the same seed plans the same story', () {
    final again = StoryPlanner(Random(42), catalog).plan(anchor: anchor);

    expect(
      [for (final d in again.dives) '${d.start}|${d.siteId}'],
      [for (final d in plan.dives) '${d.start}|${d.siteId}'],
    );
  });
}
