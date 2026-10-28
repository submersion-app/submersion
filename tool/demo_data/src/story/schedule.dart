import 'dart:math';

import 'catalog.dart';
import 'course_plan.dart';
import 'destinations.dart';
import 'story_plan.dart';

/// One dive slot of the schedule, before it is numbered and given a kind.
class Slot {
  const Slot({
    required this.start,
    required this.destination,
    required this.siteId,
    required this.night,
    required this.waterTempC,
    this.tripId,
    this.centerId,
    this.boat = false,
  });

  final DateTime start;
  final Destination destination;
  final String siteId;
  final bool night;
  final double waterTempC;
  final String? tripId;
  final String? centerId;
  final bool boat;
}

/// A trip as the schedule lays it out; people are added once dives are
/// numbered.
class TripDraft {
  TripDraft({
    required this.id,
    required this.destination,
    required this.start,
    required this.end,
    required this.siteIds,
    required this.centerIds,
    this.boatName,
    this.resortName,
  });

  final String id;
  final Destination destination;
  final DateTime start;
  final DateTime end;
  final List<String> siteIds;
  final List<String> centerIds;
  final String? boatName;
  final String? resortName;
}

/// Lays out six years of diving before an anchor date: 6 to 8 trips a year
/// at least ten days apart, and weekends at the home lakes between them.
///
/// The first year is lighter (90 dives) and its lake weekends stay in the
/// warm months, before the diver owns a drysuit. Dives per year then hold
/// near (diveCount - 90) / 5.
class StorySchedule {
  StorySchedule(this.random, this.catalog);

  final Random random;
  final Catalog catalog;
  final trips = <TripDraft>[];
  final _sites = <String, List<CatalogSite>>{};
  final _southern = <String, bool>{};
  final _recent = <String>[];
  final _used = <String>{};

  static const firstYearDives = 90;

  List<CatalogSite> sitesFor(Destination d) => _sites.putIfAbsent(d.key, () {
    final pool = catalogSitesFor(d, catalog)..shuffle(random);
    return pool.take(d == homeDestination ? 8 : 7).toList();
  });

  List<Slot> build(DateTime anchor, int diveCount) {
    final windowStart = DateTime(anchor.year - 6, anchor.month, anchor.day + 7);
    final windowEnd = DateTime(anchor.year, anchor.month, anchor.day - 10);
    final yearDays = windowEnd.difference(windowStart).inDays / 6;
    final slots = <Slot>[];
    final perYear = ((diveCount - firstYearDives) / 5).floor();
    var planned = 0;
    for (var y = 0; y < 6; y++) {
      final yearStart = _day(windowStart, (y * yearDays).round());
      final target = y == 0
          ? firstYearDives
          : (y < 5 ? perYear : diveCount - firstYearDives - 4 * perYear);
      final yearSlots = <Slot>[];
      final busy = <(DateTime, DateTime)>[];
      var opening = yearStart;
      if (y == 0) {
        // The Open Water course: four dives over the first weekend.
        while (opening.weekday != DateTime.saturday) {
          opening = _day(opening, 1);
        }
        _dayAtHome(opening, 2, yearSlots);
        _dayAtHome(_day(opening, 1), 2, yearSlots);
        busy.add((opening, _day(opening, 1)));
      }
      final tripCount = y == 0 ? 6 : 6 + random.nextInt(3);
      final minHome = y == 0 ? 12 : 34;
      final sizes = _tripPlans(y, tripCount, planned, target, yearDays);
      final tripBudget = target - minHome - (y == 0 ? 4 : 0);
      while (sizes.fold(0, (a, t) => a + t.days * t.perDay) > tripBudget) {
        final biggest = sizes.reduce(
          (a, b) => a.days * a.perDay >= b.days * b.perDay ? a : b,
        );
        biggest.days--;
      }
      final segment = (yearDays - 20) / tripCount;
      for (var i = 0; i < tripCount; i++) {
        final plan = sizes[i];
        final room = segment - plan.days - 12;
        final offset = 20 + segment * i + random.nextDouble() * max(1, room);
        final first = _day(yearStart, offset.round());
        busy.add(_trip(plan, first, yearSlots));
      }
      final home = target - yearSlots.length;
      _weekends(yearStart, yearDays, home, busy, yearSlots, warmOnly: y == 0);
      planned += yearSlots.length;
      slots.addAll(yearSlots);
    }
    slots.sort((a, b) => a.start.compareTo(b.start));
    return slots;
  }

  /// The destinations and lengths of one year's trips.
  List<_TripPlan> _tripPlans(
    int year,
    int count,
    int divesBefore,
    int target,
    double yearDays,
  ) {
    final plans = <_TripPlan>[];
    var liveaboards = 0;
    var nearHome = 0;
    for (var i = 0; i < count; i++) {
      final estimate = divesBefore + target * (i + 0.5) / count;
      bool eligible(Destination d) {
        if (d.minPhase == StoryPhase.technicalOc &&
            estimate < techStartDive + 20) {
          return false;
        }
        if (year == 0 && (d.nearHome || d.waterTempC.$1 < 14)) return false;
        if (d.nearHome && nearHome >= 2) return false;
        if (d.liveaboard && (liveaboards >= 2 || year == 0 && i < 2)) {
          return false;
        }
        return !_recent.contains(d.key);
      }

      final pool = tripDestinations.where(eligible).toList();
      final fresh = pool.where((d) => !_used.contains(d.key)).toList();
      final from = fresh.isNotEmpty && random.nextDouble() < 0.75
          ? fresh
          : pool;
      final dest = from[random.nextInt(from.length)];
      _used.add(dest.key);
      _recent.add(dest.key);
      if (_recent.length > 8) _recent.removeAt(0);
      if (dest.liveaboard) liveaboards++;
      if (dest.nearHome) nearHome++;
      plans.add(
        dest.liveaboard
            ? _TripPlan(dest, 6 + random.nextInt(3), 3)
            : dest.nearHome
            ? _TripPlan(dest, 2 + random.nextInt(2), 2)
            : _TripPlan(dest, 5 + random.nextInt(5), 2),
      );
    }
    return plans;
  }

  (DateTime, DateTime) _trip(_TripPlan plan, DateTime first, List<Slot> out) {
    final dest = plan.destination;
    final id = 'trip-${trips.length + 1}';
    final centers = _centersFor(dest);
    final boat = dest.liveaboard;
    for (var d = 0; d < plan.days; d++) {
      final perDay = plan.perDay + (random.nextDouble() < 0.25 ? 1 : 0);
      final centerId = centers.isEmpty ? null : centers[d % centers.length];
      _dayAt(
        dest,
        _day(first, d),
        perDay,
        out,
        tripId: id,
        centerId: centerId,
        boat: !dest.freshwater && (boat || random.nextDouble() < 0.85),
      );
    }
    final start = _day(first, -1);
    final last = _day(first, plan.days - 1);
    final end = DateTime(last.year, last.month, last.day + 1, 12);
    trips.add(
      TripDraft(
        id: id,
        destination: dest,
        start: start,
        end: end,
        siteIds: [for (final s in sitesFor(dest)) s.id],
        centerIds: centers,
        boatName: dest.boatNames.isEmpty
            ? null
            : dest.boatNames[random.nextInt(dest.boatNames.length)],
        resortName: dest.resortNames.isEmpty
            ? null
            : dest.resortNames[random.nextInt(dest.resortNames.length)],
      ),
    );
    return (start, end);
  }

  /// Weekends at the home lakes between the trips: two dives on a Saturday,
  /// now and then the Sunday as well.
  void _weekends(
    DateTime yearStart,
    double yearDays,
    int dives,
    List<(DateTime, DateTime)> busy,
    List<Slot> out, {
    required bool warmOnly,
  }) {
    final saturdays = <DateTime>[];
    for (var d = 0; d < yearDays - 7; d++) {
      final day = _day(yearStart, d);
      if (day.weekday != DateTime.saturday) continue;
      if (warmOnly && (day.month < 5 || day.month > 9)) continue;
      final clash = busy.any(
        (b) => !day.isBefore(_day(b.$1, -2)) && !day.isAfter(_day(b.$2, 3)),
      );
      if (!clash) saturdays.add(day);
    }
    var left = dives;
    final days = (dives / 2).ceil();
    for (var k = 0; k < days && left > 0; k++) {
      final day = saturdays[(k * saturdays.length / days).floor()];
      final count = min(2, left);
      _dayAtHome(day, count, out);
      left -= count;
      if (left > 0 && k % 4 == 3) {
        final sunday = min(2, left);
        _dayAtHome(_day(day, 1), sunday, out);
        left -= sunday;
      }
    }
    if (left > 0) throw StateError('not enough free weekends at home');
  }

  void _dayAtHome(DateTime day, int count, List<Slot> out) =>
      _dayAt(homeDestination, day, count, out);

  void _dayAt(
    Destination dest,
    DateTime day,
    int count,
    List<Slot> out, {
    String? tripId,
    String? centerId,
    bool boat = false,
  }) {
    const starts = [(8, 30), (11, 30), (14, 30), (17, 30)];
    final sites = sitesFor(dest);
    for (var i = 0; i < count; i++) {
      final night = i == count - 1 && count > 1 && random.nextDouble() < 0.12;
      final (h, m) = night ? (19, 30) : starts[i];
      out.add(
        Slot(
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
          centerId: centerId,
          boat: boat,
          waterTempC: _waterTemp(dest, day),
        ),
      );
    }
  }

  /// The water at [d] on [day]: a wide range follows the season (coldest at
  /// the end of January, warmest at the end of July, flipped south of the
  /// equator); a narrow one is just a day's variation.
  double _waterTemp(Destination d, DateTime day) {
    final (lo, hi) = d.waterTempC;
    final double f;
    if (hi - lo >= 6) {
      final south = _southern.putIfAbsent(
        d.key,
        () => sitesFor(d).first.latitude < 0,
      );
      final dayOfYear = day.difference(DateTime(day.year)).inDays;
      final phase = 2 * pi * (dayOfYear - 30 + (south ? 182 : 0)) / 365;
      f = ((1 - cos(phase)) / 2 + (random.nextDouble() - 0.5) * 0.08).clamp(
        0.0,
        1.0,
      );
    } else {
      f = random.nextDouble();
    }
    return ((lo + f * (hi - lo)) * 10).roundToDouble() / 10;
  }

  /// One or two catalogue dive centres in [d]'s country, nearest its sites
  /// when the centres have coordinates.
  List<String> _centersFor(Destination d) {
    final pool = catalog.centers.where((c) => c.country == d.country).toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    if (pool.isEmpty) return const [];
    final site = sitesFor(d).first;
    double distance(CatalogCenter c) => c.latitude == null
        ? double.infinity
        : (pow(c.latitude! - site.latitude, 2) +
                  pow(c.longitude! - site.longitude, 2))
              .toDouble();
    final near = [...pool]..sort((a, b) => distance(a).compareTo(distance(b)));
    final choices = near.take(6).toList()..shuffle(random);
    final count = d.liveaboard || d.nearHome ? 1 : 1 + random.nextInt(2);
    return [for (final c in choices.take(count)) c.id];
  }

  static DateTime _day(DateTime from, int days) =>
      DateTime(from.year, from.month, from.day + days);
}

class _TripPlan {
  _TripPlan(this.destination, this.days, this.perDay);

  final Destination destination;
  int days;
  final int perDay;
}
