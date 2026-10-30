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

  /// How many of the latest trips' places wait before a second visit.
  static const _recentSize = 8;

  /// Trips planned so far, and how many of them went to the Caribbean.
  var _tripCount = 0;
  var _caribbeanTrips = 0;
  final _used = <String>{};

  static const firstYearDives = 90;

  /// A destination's sites: one picked at random, then its nearest
  /// neighbours within [clusterKm] (or the nearest few where the catalogue
  /// is sparse), so a day's dives are a boat ride apart, not a flight.
  List<CatalogSite> sitesFor(Destination d) => _sites.putIfAbsent(d.key, () {
    final pool = catalogSitesFor(d, catalog);
    List<CatalogSite> around(CatalogSite seed) => [
      for (final s in pool)
        if (kmBetween(seed.latitude, seed.longitude, s.latitude, s.longitude) <=
            clusterKm)
          s,
    ];
    // A seed whose neighbourhood is as full as any, picked at random.
    final sizes = {for (final s in pool) s.id: around(s).length};
    final best = sizes.values.reduce(max);
    final seeds = [
      for (final s in pool)
        if (sizes[s.id]! >= min(best, 4)) s,
    ];
    final seed = seeds[random.nextInt(seeds.length)];
    double away(CatalogSite s) =>
        kmBetween(seed.latitude, seed.longitude, s.latitude, s.longitude);
    final cluster = around(seed)..sort((a, b) => away(a).compareTo(away(b)));
    return cluster.take(d == homeDestination ? 14 : 7).toList();
  });

  static const clusterKm = 25.0;

  /// The final weeks before the anchor are home weekends, both days dived:
  /// the rebreather phase is dived at the home lakes, and the newest dive
  /// is days before the anchor.
  static const finalHomeDays = 70;

  List<Slot> build(DateTime anchor, int diveCount) {
    final windowStart = DateTime(anchor.year - 6, anchor.month, anchor.day + 7);
    final windowEnd = DateTime(anchor.year, anchor.month, anchor.day - 1);
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
      final last = y == 5;
      final tripCount = y == 0 ? 6 : 6 + random.nextInt(3);
      // Weekends at the lakes are most of a year's diving days.
      final minHome = y == 0 ? 12 : 45;
      final sizes = _tripPlans(y, tripCount, planned, target, yearDays);
      final tripBudget = target - minHome;
      while (sizes.fold(0, (a, t) => a + t.days * t.perDay) > tripBudget) {
        final biggest = sizes.reduce(
          (a, b) => a.days * a.perDay >= b.days * b.perDay ? a : b,
        );
        biggest.days--;
      }
      final tripDays = yearDays - 20 - (last ? finalHomeDays : 0);
      final segment = tripDays / tripCount;
      for (var i = 0; i < tripCount; i++) {
        final plan = sizes[i];
        final room = segment - plan.days - 12;
        final offset = 20 + segment * i + random.nextDouble() * max(1, room);
        final first = _day(yearStart, offset.round());
        busy.add(_trip(plan, first, yearSlots));
      }
      final home = target - yearSlots.length;
      _weekends(
        yearStart,
        yearDays,
        home,
        busy,
        yearSlots,
        // The Open Water course is on the first trip; the lakes wait for it
        // and for the warm months.
        warmOnly: y == 0,
        notBefore: y == 0 ? busy.first.$2 : null,
        finalDays: last ? finalHomeDays : 0,
        windowEnd: windowEnd,
      );
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
        // A Caribbean regular goes back to the same islands, and a weekend
        // place is driven to every year; elsewhere a place waits a while
        // before a second visit.
        final wait = caribbeanDestinations.contains(d.key) || d.nearHome
            ? 3
            : _recentSize;
        return !_recent.reversed.take(wait).contains(d.key);
      }

      // About half the trips go to the Caribbean: likely while the trips so
      // far fall short of half, unlikely once they are past it.
      final behind = _caribbeanTrips * 2 < _tripCount + 1;
      final caribbean = random.nextDouble() < (behind ? 0.85 : 0.15);
      final eligibleAll = tripDestinations.where(eligible).toList();
      // From the second year, one trip a year is a weekend drive near home.
      final weekend = [
        if (year >= 1 && i == count ~/ 2 && nearHome == 0)
          for (final d in eligibleAll)
            if (d.nearHome) d,
      ];
      final ofRegion = [
        for (final d in eligibleAll)
          if (caribbeanDestinations.contains(d.key) == caribbean) d,
      ];
      final pool = weekend.isNotEmpty
          ? weekend
          : ofRegion.isNotEmpty
          ? ofRegion
          : eligibleAll;
      // Away from the Caribbean the diver mostly goes somewhere new; the
      // islands are revisited as favourites.
      final fresh = pool.where((d) => !_used.contains(d.key)).toList();
      final from =
          fresh.isNotEmpty && random.nextDouble() < (caribbean ? 0.6 : 0.95)
          ? fresh
          : pool;
      final dest = from[random.nextInt(from.length)];
      _used.add(dest.key);
      _recent.add(dest.key);
      if (_recent.length > _recentSize) _recent.removeAt(0);
      _tripCount++;
      if (caribbeanDestinations.contains(dest.key)) _caribbeanTrips++;
      if (dest.liveaboard) liveaboards++;
      if (dest.nearHome) nearHome++;
      plans.add(
        dest.liveaboard
            ? _TripPlan(dest, 6 + random.nextInt(3), 3)
            : dest.nearHome
            ? _TripPlan(dest, 2 + random.nextInt(2), 2)
            : _TripPlan(
                dest,
                5 + random.nextInt(5),
                random.nextDouble() < 0.3 ? 3 : 2,
              ),
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
      final perDay = plan.perDay;
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

  /// Weekends on the Jersey shore between the trips, in the boat season: two
  /// dives on a Saturday, now and then the Sunday as well.
  void _weekends(
    DateTime yearStart,
    double yearDays,
    int dives,
    List<(DateTime, DateTime)> busy,
    List<Slot> out, {
    required bool warmOnly,
    required DateTime windowEnd,
    DateTime? notBefore,
    int finalDays = 0,
  }) {
    final saturdays = <DateTime>[];
    final finalFrom = _day(windowEnd, -finalDays);
    var left = dives;
    // The final weeks first: every weekend, both days.
    if (finalDays > 0) {
      var day = windowEnd;
      while (day.weekday != DateTime.sunday &&
          day.weekday != DateTime.saturday) {
        day = _day(day, -1);
      }
      if (day.weekday == DateTime.sunday) day = _day(day, -1);
      final finals = <DateTime>[];
      for (; !day.isBefore(finalFrom); day = _day(day, -7)) {
        finals.add(day);
      }
      // Newest first, so the last weekend before the anchor is always dived.
      for (final saturday in finals) {
        if (left <= 0) break;
        final sunday = _day(saturday, 1);
        if (!sunday.isAfter(windowEnd)) {
          _dayAtHome(sunday, min(2, left), out);
          left -= min(2, left);
        }
        if (left <= 0) break;
        _dayAtHome(saturday, min(2, left), out);
        left -= min(2, left);
      }
    }
    for (var d = 0; d < yearDays - 7; d++) {
      final day = _day(yearStart, d);
      if (day.weekday != DateTime.saturday) continue;
      if (finalDays > 0 && !day.isBefore(finalFrom)) continue;
      if (notBefore != null && !day.isAfter(notBefore)) continue;
      if (warmOnly && (day.month < 5 || day.month > 9)) continue;
      // The Jersey boats run from April to November.
      if (day.month < 4 || day.month > 11) continue;
      final clash = busy.any(
        (b) => !day.isBefore(_day(b.$1, -2)) && !day.isAfter(_day(b.$2, 3)),
      );
      if (!clash) saturdays.add(day);
    }
    // When the season's free Saturdays are too few, the Sundays dive too;
    // each day is dived at most once.
    final days = (left / 2).ceil();
    final saturdaysOnly = days <= saturdays.length;
    final pool = saturdaysOnly
        ? saturdays
        : [
            for (final s in saturdays) ...[s, _day(s, 1)],
          ];
    final spread = min(days, pool.length);
    for (var k = 0; k < spread && left > 0; k++) {
      final day = pool[(k * pool.length / spread).floor()];
      final count = min(2, left);
      _dayAtHome(day, count, out);
      left -= count;
      if (saturdaysOnly && left > 0 && k % 4 == 3) {
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
      final site = sites[random.nextInt(sites.length)];
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
          siteId: site.id,
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
        : kmBetween(c.latitude!, c.longitude!, site.latitude, site.longitude);
    final near = [...pool]..sort((a, b) => distance(a).compareTo(distance(b)));
    // Centres near the sites; where none is, one whose place the catalogue
    // does not give (likely local), and never one known to be far away: a
    // trip with none dives on its own from the shore.
    final close = near.where((c) => distance(c) <= 30).toList();
    final unplaced = pool.where((c) => c.latitude == null).toList();
    final choices =
        (close.isNotEmpty
                ? close
                : unplaced.isNotEmpty
                ? unplaced
                : const <CatalogCenter>[])
            .take(6)
            .toList()
          ..shuffle(random);
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
