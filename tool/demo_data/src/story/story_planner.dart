import 'dart:math';

import '../shape/dive_shape.dart';
import 'catalog.dart';
import 'story_plan.dart';

/// Plans the demo diver's six years (issue #3708): a recreational start,
/// technical open circuit, then a rebreather course and a few CCR dives, with
/// every certification earned before the first dive that needs it.
///
/// Home waters are a lake region; about three trips a year go to warm-water
/// destinations, with Mediterranean wrecks once the diver is technical. Every
/// place is a site from the app's own public catalogue.
class StoryPlanner {
  StoryPlanner(this.random, this.catalog);

  final Random random;
  final Catalog catalog;

  static const home = Destination(
    key: 'home',
    label: 'Lake diving',
    country: 'Deutschland',
    region: 'Bayern',
    waterTempC: (5, 16),
    freshwater: true,
  );

  static const tropical = [
    Destination(
      key: 'red-sea',
      label: 'Red Sea',
      country: 'مصر',
      region: 'البحر الأحمر',
      waterTempC: (22, 28),
      freshwater: false,
      liveaboard: true,
    ),
    Destination(
      key: 'bali',
      label: 'Bali',
      country: 'Indonesia',
      region: 'Bali',
      waterTempC: (26, 29),
      freshwater: false,
    ),
    Destination(
      key: 'cebu',
      label: 'Cebu',
      country: 'Philippines',
      region: 'Cebu',
      waterTempC: (26, 29),
      freshwater: false,
    ),
    Destination(
      key: 'similan',
      label: 'Similan Islands',
      country: 'ประเทศไทย',
      region: 'จังหวัดพังงา',
      waterTempC: (27, 29),
      freshwater: false,
      liveaboard: true,
    ),
    Destination(
      key: 'maldives',
      label: 'Maldives',
      country: 'ދިވެހިރާއްޖެ',
      region: 'މާލެ އަތޮޅު',
      waterTempC: (27, 30),
      freshwater: false,
    ),
    Destination(
      key: 'raja-ampat',
      label: 'Raja Ampat',
      country: 'Indonesia',
      region: 'Papua Barat Daya',
      waterTempC: (27, 30),
      freshwater: false,
      liveaboard: true,
    ),
  ];

  static const mediterranean = Destination(
    key: 'med',
    label: 'Mediterranean wrecks',
    country: 'France',
    region: 'Occitanie',
    waterTempC: (14, 22),
    freshwater: false,
  );

  static const people = [
    FictionalPerson(
      id: 'p-mara',
      firstName: 'Mara',
      lastName: 'Lindqvist',
      role: 'buddy',
    ),
    FictionalPerson(
      id: 'p-tobias',
      firstName: 'Tobias',
      lastName: 'Reinholt',
      role: 'buddy',
    ),
    FictionalPerson(
      id: 'p-priya',
      firstName: 'Priya',
      lastName: 'Varadan',
      role: 'buddy',
    ),
    FictionalPerson(
      id: 'p-sam',
      firstName: 'Sam',
      lastName: 'Okonkwo-Hale',
      role: 'buddy',
    ),
    FictionalPerson(
      id: 'p-lena',
      firstName: 'Lena',
      lastName: 'Marchetti',
      role: 'buddy',
    ),
    FictionalPerson(
      id: 'p-jonas',
      firstName: 'Jonas',
      lastName: 'Vettermann',
      role: 'buddy',
    ),
    FictionalPerson(
      id: 'p-hannah',
      firstName: 'Hannah',
      lastName: 'Brookfield',
      role: 'instructor',
    ),
    FictionalPerson(
      id: 'p-diego',
      firstName: 'Diego',
      lastName: 'Albarrán',
      role: 'instructor',
    ),
    FictionalPerson(
      id: 'p-kenji',
      firstName: 'Kenji',
      lastName: 'Moriwaki',
      role: 'instructor',
    ),
    FictionalPerson(
      id: 'p-ayu',
      firstName: 'Ayu',
      lastName: 'Setiawati',
      role: 'guide',
    ),
  ];

  /// The courses and the dive numbers of their training dives, for a
  /// [diveCount] dive story with [ccrCount] CCR dives at the end.
  static Map<CertLevel, (int, int)> courseDives(int diveCount, int ccrCount) {
    final ccrStart = diveCount - ccrCount + 1;
    return {
      CertLevel.openWater: (1, 4),
      CertLevel.advanced: (16, 20),
      CertLevel.rescue: (60, 61),
      CertLevel.deep: (100, 103),
      CertLevel.decoProcedures: (136, 139),
      CertLevel.trimix: (200, 203),
      CertLevel.ccr: (ccrStart, ccrStart + 4),
    };
  }

  static const _techStart = 136;
  static const _trimixCertAfter = 203;

  StoryPlan plan({required DateTime anchor, int diveCount = 300}) {
    final ccrCount = 8 + random.nextInt(5);
    final ccrStart = diveCount - ccrCount + 1;
    final courseRanges = courseDives(diveCount, ccrCount);
    final sitesByDest = <String, List<CatalogSite>>{};
    List<CatalogSite> sitesFor(Destination d) =>
        sitesByDest.putIfAbsent(d.key, () => _pickSites(d, d == home ? 8 : 7));

    final slots = _schedule(anchor, diveCount, sitesFor);
    final instructors = people.where((p) => p.role == 'instructor').toList();
    final buddies = people.where((p) => p.role != 'instructor').toList();

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
        instructorId: instructors[courses.length % instructors.length].id,
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
        issueDate: slots[29].start.subtract(const Duration(days: 3)),
      ),
    ]..sort((a, b) => a.issueDate.compareTo(b.issueDate));

    final dives = <PlannedDive>[];
    for (var i = 0; i < diveCount; i++) {
      final n = i + 1;
      final slot = slots[i];
      final course = courseOf[n];
      final phase = n >= ccrStart
          ? StoryPhase.rebreather
          : n >= _techStart
          ? StoryPhase.technicalOc
          : StoryPhase.recreational;
      final spec = _spec(n, phase, course?.level, ccrStart);
      dives.add(
        PlannedDive(
          number: n,
          start: slot.start,
          phase: phase,
          wantedKinds: spec.kinds,
          siteId: slot.siteId,
          destination: slot.destination,
          targetMaxDepth: spec.depth,
          diveMode: phase == StoryPhase.rebreather ? 'ccr' : 'oc',
          tankCount: spec.tanks,
          buddyIds: {
            if (course != null) course.instructorId,
            buddies[random.nextInt(buddies.length)].id,
            if (course == null && random.nextDouble() < 0.3)
              buddies[random.nextInt(buddies.length)].id,
          }.toList(),
          plannedDuration: Duration(
            minutes: switch (phase) {
              StoryPhase.recreational => 75,
              StoryPhase.technicalOc => 130,
              StoryPhase.rebreather => 160,
            },
          ),
          tripId: slot.tripId,
          courseId: course?.id,
          requiresCert: spec.requires,
          night: slot.night,
        ),
      );
    }

    final usedSites = <String>{for (final d in dives) d.siteId};
    final allSites = {for (final s in catalog.sites) s.id: s};
    return StoryPlan(
      anchor: anchor,
      dives: dives,
      trips: _trips,
      certs: certs,
      courses: courses,
      sites: [for (final id in usedSites) allSites[id]!],
      centers: _centers.values.whereType<CatalogCenter>().toList(),
      people: people,
      home: home,
    );
  }

  ({Set<ShapeKind> kinds, double depth, int tanks, CertLevel? requires}) _spec(
    int n,
    StoryPhase phase,
    CertLevel? course,
    int ccrStart,
  ) {
    double range(double lo, double hi) =>
        (lo + random.nextDouble() * (hi - lo)).roundToDouble();
    const rec = {ShapeKind.recreational};
    const deco = {ShapeKind.deepOpenCircuit, ShapeKind.multiGasDeco};
    switch (course) {
      case CertLevel.openWater:
        return (kinds: rec, depth: range(6, 12), tanks: 1, requires: null);
      case CertLevel.advanced:
        return (
          kinds: rec,
          depth: range(16, 28),
          tanks: 1,
          requires: CertLevel.openWater,
        );
      case CertLevel.rescue:
        return (
          kinds: rec,
          depth: range(5, 12),
          tanks: 1,
          requires: CertLevel.advanced,
        );
      case CertLevel.deep:
        return (
          kinds: rec,
          depth: range(28, 38),
          tanks: 1,
          requires: CertLevel.advanced,
        );
      case CertLevel.decoProcedures:
        return (
          kinds: deco,
          depth: range(30, 45),
          tanks: 2,
          requires: CertLevel.deep,
        );
      case CertLevel.trimix:
        return (
          kinds: {ShapeKind.trimix},
          depth: range(45, 60),
          tanks: 3,
          requires: CertLevel.decoProcedures,
        );
      case CertLevel.ccr:
        return (
          kinds: {ShapeKind.ccr},
          depth: range(10, 30),
          tanks: 3,
          requires: CertLevel.decoProcedures,
        );
      case CertLevel.nitrox || null:
        break;
    }
    switch (phase) {
      case StoryPhase.recreational:
        final max = n < 16 ? 18.0 : (n > 103 ? 38.0 : 30.0);
        return (
          kinds: rec,
          depth: range(10, max),
          tanks: 1,
          requires: n < 16
              ? CertLevel.openWater
              : (n > 103 ? CertLevel.deep : CertLevel.advanced),
        );
      case StoryPhase.technicalOc:
        final roll = random.nextDouble();
        if (roll < 0.25) {
          return (
            kinds: rec,
            depth: range(15, 30),
            tanks: 1,
            requires: CertLevel.advanced,
          );
        }
        if (n > _trimixCertAfter && roll > 0.7) {
          return (
            kinds: {ShapeKind.trimix},
            depth: range(50, 70),
            tanks: 3,
            requires: CertLevel.trimix,
          );
        }
        return (
          kinds: deco,
          depth: range(38, 55),
          tanks: 2,
          requires: CertLevel.decoProcedures,
        );
      case StoryPhase.rebreather:
        return (
          kinds: {ShapeKind.ccr},
          depth: range(30, 60),
          tanks: 3,
          requires: CertLevel.ccr,
        );
    }
  }

  final _trips = <PlannedTrip>[];
  final _centers = <String, CatalogCenter?>{};

  /// Dive slots in time order: a weekend at home, trips three times a year and
  /// local days between, spread evenly over six years before [anchor].
  List<_Slot> _schedule(
    DateTime anchor,
    int diveCount,
    List<CatalogSite> Function(Destination) sitesFor,
  ) {
    final windowStart = DateTime(anchor.year - 6, anchor.month, anchor.day + 7);
    final windowEnd = DateTime(anchor.year, anchor.month, anchor.day - 10);
    final yearDays = windowEnd.difference(windowStart).inDays / 6;
    final slots = <_Slot>[];
    var tropicalIndex = random.nextInt(tropical.length);
    for (var y = 0; y < 6; y++) {
      final yearStart = DateTime(
        windowStart.year,
        windowStart.month,
        windowStart.day + (y * yearDays).round(),
      );
      final target = y < 5 ? diveCount ~/ 6 : diveCount - 5 * (diveCount ~/ 6);
      final tripSizes = [for (var i = 0; i < 3; i++) 9 + random.nextInt(5)];
      var local = target - tripSizes.fold<int>(0, (a, b) => a + b);
      final busy = <(DateTime, DateTime)>[];
      for (var i = 0; i < 3; i++) {
        final dest = y >= 3 && i == 1
            ? mediterranean
            : tropical[tropicalIndex++ % tropical.length];
        final offset = (yearDays * (0.15 + 0.3 * i) + random.nextInt(25))
            .round();
        final first = DateTime(
          yearStart.year,
          yearStart.month,
          yearStart.day + offset,
        );
        busy.add(_trip(dest, first, tripSizes[i], slots, sitesFor));
      }
      // Local days: weekends at home, two dives each, between the trips.
      final days = (local / 2).ceil();
      for (var k = 0; k < days; k++) {
        var day = DateTime(
          yearStart.year,
          yearStart.month,
          yearStart.day + ((k + 0.5) * yearDays / days).round(),
        );
        while (day.weekday != DateTime.saturday ||
            busy.any((b) => !day.isBefore(b.$1) && !day.isAfter(b.$2))) {
          day = DateTime(day.year, day.month, day.day + 1);
        }
        final count = min(2, local);
        local -= count;
        // The first weekend is the Open Water course: four dives over two days.
        if (y == 0 && k == 0) {
          _day(home, day, 2, slots, sitesFor, null);
          _day(
            home,
            DateTime(day.year, day.month, day.day + 1),
            2,
            slots,
            sitesFor,
            null,
          );
          local -= 2;
          continue;
        }
        if (count > 0) _day(home, day, count, slots, sitesFor, null);
      }
    }
    slots.sort((a, b) => a.start.compareTo(b.start));
    return slots.take(diveCount).toList();
  }

  (DateTime, DateTime) _trip(
    Destination dest,
    DateTime first,
    int size,
    List<_Slot> slots,
    List<CatalogSite> Function(Destination) sitesFor,
  ) {
    final perDay = dest.liveaboard ? 3 : 2;
    final days = (size / perDay).ceil();
    final id = 'trip-${_trips.length + 1}';
    var left = size;
    for (var d = 0; d < days; d++) {
      final count = min(perDay, left);
      left -= count;
      _day(
        dest,
        DateTime(first.year, first.month, first.day + d),
        count,
        slots,
        sitesFor,
        id,
      );
    }
    final start = DateTime(first.year, first.month, first.day - 1);
    final end = DateTime(first.year, first.month, first.day + days, 12);
    _trips.add(
      PlannedTrip(
        id: id,
        destination: dest,
        start: start,
        end: end,
        siteIds: [for (final s in sitesFor(dest)) s.id],
        centerId: _centerFor(dest)?.id,
      ),
    );
    return (start, end);
  }

  void _day(
    Destination dest,
    DateTime day,
    int count,
    List<_Slot> slots,
    List<CatalogSite> Function(Destination) sitesFor,
    String? tripId,
  ) {
    const starts = [(8, 30), (12, 0), (15, 30)];
    final sites = sitesFor(dest);
    for (var i = 0; i < count; i++) {
      final night = i == count - 1 && count > 1 && random.nextDouble() < 0.12;
      final (h, m) = night ? (19, 30) : starts[i];
      slots.add(
        _Slot(
          start: DateTime(
            day.year,
            day.month,
            day.day,
            h,
            m + random.nextInt(20),
          ),
          destination: dest,
          siteId: sites[random.nextInt(sites.length)].id,
          tripId: tripId,
          night: night,
        ),
      );
    }
  }

  List<CatalogSite> _pickSites(Destination d, int count) {
    final pool =
        catalog.sites
            .where((s) => s.country == d.country && s.region == d.region)
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id))
          ..shuffle(random);
    if (pool.isEmpty) throw StateError('no catalogue sites for ${d.label}');
    return pool.take(count).toList();
  }

  CatalogCenter? _centerFor(Destination d) => _centers.putIfAbsent(d.key, () {
    final pool = catalog.centers.where((c) => c.country == d.country).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return pool.isEmpty ? null : pool[random.nextInt(pool.length)];
  });
}

class _Slot {
  const _Slot({
    required this.start,
    required this.destination,
    required this.siteId,
    required this.night,
    this.tripId,
  });

  final DateTime start;
  final Destination destination;
  final String siteId;
  final bool night;
  final String? tripId;
}
