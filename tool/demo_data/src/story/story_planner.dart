import 'dart:math';

import '../shape/dive_shape.dart';
import 'buddy_picker.dart';
import 'catalog.dart';
import 'course_plan.dart';
import 'destination_life.dart';
import 'destinations.dart';
import 'dive_spec.dart';
import 'milestones.dart';
import 'people.dart';
import 'schedule.dart';
import 'story_plan.dart';

/// Plans the demo diver's six years: a recreational start, technical open
/// circuit from dive 250, then a rebreather course and 15 to 18 rebreather
/// dives at the end, with every certification earned before the first dive
/// that needs it.
///
/// Home waters are a lake region dived all year; 6 to 8 trips a year go all
/// over the world. Every place is a site from the app's own public
/// catalogue, and every person is fictional.
class StoryPlanner {
  StoryPlanner(this.random, this.catalog, {this.refusedNames = const {}});

  final Random random;
  final Catalog catalog;

  /// Names the privacy check refused; the people factory skips them.
  final Set<String> refusedNames;

  static const home = homeDestination;

  /// Rebreather dives: the five harvested rebreather shapes that reach a
  /// first card's depths, three uses each.
  static const ccrCount = 15;

  StoryPlan plan({required DateTime anchor, int diveCount = 700}) {
    final ccrStart = diveCount - ccrCount + 1;
    final schedule = StorySchedule(random, catalog);
    final slots = schedule.build(anchor, diveCount);
    final courseRanges = placeCourses(slots, ccrCount);
    final techStart = courseRanges[CertLevel.decoProcedures]!.$1;
    final buddies = BuddyPicker(
      random,
      PeopleFactory(random, refused: refusedNames),
    );
    for (final t in schedule.trips) {
      buddies.meetTrip(t);
    }

    final courses = <PlannedCourse>[];
    final courseOf = <int, PlannedCourse>{};
    for (final MapEntry(key: level, value: (from, to))
        in courseRanges.entries) {
      final first = slots[from - 1].start;
      final last = slots[to - 1].start;
      final course = PlannedCourse(
        id: 'course-${level.name}',
        level: level,
        start: DateTime(first.year, first.month, first.day),
        end: DateTime(last.year, last.month, last.day, 23),
        instructorId: buddies
            .instructorFor(level, slots[from - 1].destination)
            .id,
      );
      courses.add(course);
      for (var n = from; n <= to; n++) {
        courseOf[n] = course;
      }
    }
    final certs = [
      for (final c in courses)
        PlannedCert(
          id: 'cert-${c.level.name}',
          level: c.level,
          // When the last training dive ends: a later dive the same day
          // already dives on the new card.
          issueDate: slots[courseRanges[c.level]!.$2 - 1].start.add(
            const Duration(hours: 2),
          ),
          courseId: c.id,
          instructorId: c.instructorId,
        ),
      PlannedCert(
        id: 'cert-nitrox',
        level: CertLevel.nitrox,
        issueDate: slots[nitroxDive - 1].start.subtract(
          const Duration(days: 3),
        ),
      ),
    ]..sort((a, b) => a.issueDate.compareTo(b.issueDate));

    final dives = <PlannedDive>[];
    for (var i = 0; i < diveCount; i++) {
      final n = i + 1;
      final slot = slots[i];
      final course = courseOf[n];
      final phase = n >= ccrStart
          ? StoryPhase.rebreather
          : n >= techStart
          ? StoryPhase.technicalOc
          : StoryPhase.recreational;
      final spec = diveSpecFor(
        n,
        phase,
        course?.level,
        slot.destination,
        random,
        courseRanges,
      );
      // At home the dive picks the wreck, reef or beach for its depth, and
      // the wrecks and reefs are boat dives.
      final atHome = slot.destination.key == home.key;
      // A quarter of the recreational days at home are beach dives at an
      // inlet, as shallow as the inlet.
      final beach =
          atHome &&
          phase == StoryPhase.recreational &&
          course == null &&
          random.nextDouble() < 0.25;
      final siteId = beach
          ? (homeShoreSites.toList()
              ..sort())[random.nextInt(homeShoreSites.length)]
          : atHome
          ? _homeSiteFor(spec.depth)
          : slot.siteId;
      final depth = beach
          ? min(spec.depth, homeSiteDepthM[siteId]!)
          : spec.depth;
      final rebreather = phase == StoryPhase.rebreather;
      final scooter =
          n >= scooterDive &&
          slot.destination.scooterOk &&
          (spec.tanks > 1 || rebreather) &&
          course == null &&
          random.nextDouble() < 0.3;
      dives.add(
        PlannedDive(
          number: n,
          start: slot.start,
          phase: phase,
          wantedKinds: spec.kinds,
          siteId: siteId,
          destination: slot.destination,
          targetMaxDepth: depth,
          diveMode: rebreather ? 'ccr' : 'oc',
          tankCount: spec.tanks,
          buddyIds: buddies.forDive(slot, spec.kinds, phase, course),
          plannedDuration: Duration(
            minutes: switch (phase) {
              StoryPhase.recreational => 75,
              StoryPhase.technicalOc => 130,
              StoryPhase.rebreather => 160,
            },
          ),
          waterTempC: slot.waterTempC,
          tripId: slot.tripId,
          courseId: course?.id,
          requiresCert: spec.requires,
          night: slot.night,
          centerId: slot.centerId,
          scooter: scooter,
          boat: atHome ? !homeShoreSites.contains(siteId) : slot.boat,
        ),
      );
    }
    _placeUnseen(dives, buddies);

    final trips = [
      for (final t in schedule.trips)
        PlannedTrip(
          id: t.id,
          destination: t.destination,
          start: t.start,
          end: t.end,
          siteIds: t.siteIds,
          centerIds: t.centerIds,
          guideIds: buddies.tripPeople[t.id]!.guides,
          boatBuddyIds: buddies.tripPeople[t.id]!.guests,
          boatName: t.boatName,
          resortName: t.resortName,
        ),
    ];
    final usedSites = <String>{for (final d in dives) d.siteId};
    final usedCenters = <String>{
      for (final d in dives) ?d.centerId,
      for (final t in trips) ...t.centerIds,
    };
    final allSites = {for (final s in catalog.sites) s.id: s};
    final allCenters = {for (final c in catalog.centers) c.id: c};
    return StoryPlan(
      anchor: anchor,
      dives: dives,
      trips: trips,
      certs: certs,
      courses: courses,
      sites: [for (final id in usedSites) allSites[id]!],
      centers: [for (final id in usedCenters) allCenters[id]!],
      people: buddies.all,
      home: home,
      milestones: storyMilestones(
        dives,
        ccrStart: ccrStart,
        courses: courseRanges,
      ),
    );
  }

  /// Someone the dice left off every dive joins one where they belong: a
  /// guide or guest a dive of their trip, a regular a home weekend, a tech
  /// team member a technical dive. Nobody is in the logbook without a dive.
  /// A home site that goes to [depth] and not far below it: a shallow dive
  /// stays off the deep offshore wrecks, and the beaches take only shallow
  /// dives.
  String _homeSiteFor(double depth) {
    List<String> within(double extra) => [
      for (final MapEntry(key: id, value: bottom) in homeSiteDepthM.entries)
        if (bottom >= depth && bottom <= depth + extra) id,
    ];
    final near = within(15);
    final pool = near.isNotEmpty ? near : within(double.infinity);
    if (pool.isEmpty) throw StateError('no home site goes to $depth m');
    return pool[random.nextInt(pool.length)];
  }

  void _placeUnseen(List<PlannedDive> dives, BuddyPicker buddies) {
    final seen = <String>{for (final d in dives) ...d.buddyIds};
    void join(String id, bool Function(PlannedDive d) fits) {
      if (seen.contains(id)) return;
      final where = [
        for (var i = 0; i < dives.length; i++)
          if (fits(dives[i])) i,
      ];
      final i = where[random.nextInt(where.length)];
      dives[i] = _withBuddy(dives[i], id);
      seen.add(id);
    }

    for (final p in buddies.regulars) {
      join(
        p.id,
        (d) =>
            d.tripId == null &&
            d.courseId == null &&
            d.wantedKinds.contains(ShapeKind.recreational),
      );
    }
    for (final p in buddies.techTeam) {
      join(
        p.id,
        (d) =>
            d.tripId == null &&
            d.phase != StoryPhase.recreational &&
            !d.wantedKinds.contains(ShapeKind.recreational),
      );
    }
    for (final MapEntry(key: tripId, value: met)
        in buddies.tripPeople.entries) {
      for (final id in [...met.guides, ...met.guests]) {
        if (seen.contains(id)) continue;
        final onTrip = [
          for (var i = 0; i < dives.length; i++)
            if (dives[i].tripId == tripId) i,
        ];
        final i = onTrip[random.nextInt(onTrip.length)];
        dives[i] = _withBuddy(dives[i], id);
        seen.add(id);
      }
    }
  }

  static PlannedDive _withBuddy(PlannedDive d, String id) => PlannedDive(
    number: d.number,
    start: d.start,
    phase: d.phase,
    wantedKinds: d.wantedKinds,
    siteId: d.siteId,
    destination: d.destination,
    targetMaxDepth: d.targetMaxDepth,
    diveMode: d.diveMode,
    tankCount: d.tankCount,
    buddyIds: [...d.buddyIds, id],
    plannedDuration: d.plannedDuration,
    waterTempC: d.waterTempC,
    tripId: d.tripId,
    courseId: d.courseId,
    requiresCert: d.requiresCert,
    night: d.night,
    centerId: d.centerId,
    scooter: d.scooter,
    boat: d.boat,
  );
}
