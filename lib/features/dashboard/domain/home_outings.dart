import 'package:flutter/foundation.dart';

/// A dive site's position, as an outing's map pins it.
typedef OutingSite = ({double latitude, double longitude});

/// One dive as the Home outings panel needs it.
@immutable
class OutingDive {
  final String id;

  /// The dive's start as its wall clock flagged UTC, as stored.
  final DateTime dateTime;
  final String? tripId;
  final String? tripName;
  final String? siteName;
  final double? maxDepth;
  final Set<String> speciesIds;

  /// The dive site's position, when the site has one.
  final double? siteLatitude;
  final double? siteLongitude;

  const OutingDive({
    required this.id,
    required this.dateTime,
    this.tripId,
    this.tripName,
    this.siteName,
    this.maxDepth,
    this.speciesIds = const {},
    this.siteLatitude,
    this.siteLongitude,
  });

  OutingDive copyWith({
    String? id,
    DateTime? dateTime,
    String? tripId,
    String? tripName,
    String? siteName,
    double? maxDepth,
    Set<String>? speciesIds,
    double? siteLatitude,
    double? siteLongitude,
  }) => OutingDive(
    id: id ?? this.id,
    dateTime: dateTime ?? this.dateTime,
    tripId: tripId ?? this.tripId,
    tripName: tripName ?? this.tripName,
    siteName: siteName ?? this.siteName,
    maxDepth: maxDepth ?? this.maxDepth,
    speciesIds: speciesIds ?? this.speciesIds,
    siteLatitude: siteLatitude ?? this.siteLatitude,
    siteLongitude: siteLongitude ?? this.siteLongitude,
  );
}

/// A group of dives: one trip's dives, or trip-less dives close together.
@immutable
class Outing {
  /// The trip, or null for trip-less dives.
  final String? tripId;

  /// The trip's name, or the most-dived site's; null when no dive has a site.
  final String? name;

  /// The first and last dive days, as local midnights of the wall clock.
  final DateTime firstDay;
  final DateTime lastDay;

  /// In date order.
  final List<String> diveIds;
  final double? maxDepth;
  final int speciesCount;

  /// Each dive's maximum depth in date order, a missing depth as 0.
  final List<double> depths;

  /// The positions of the sites dived, each once, in date order; empty when
  /// no site has a position.
  final List<OutingSite> sites;

  const Outing({
    required this.tripId,
    required this.name,
    required this.firstDay,
    required this.lastDay,
    required this.diveIds,
    required this.maxDepth,
    required this.speciesCount,
    required this.depths,
    this.sites = const [],
  });

  int get diveCount => diveIds.length;

  Outing copyWith({
    String? tripId,
    String? name,
    DateTime? firstDay,
    DateTime? lastDay,
    List<String>? diveIds,
    double? maxDepth,
    int? speciesCount,
    List<double>? depths,
    List<OutingSite>? sites,
  }) => Outing(
    tripId: tripId ?? this.tripId,
    name: name ?? this.name,
    firstDay: firstDay ?? this.firstDay,
    lastDay: lastDay ?? this.lastDay,
    diveIds: diveIds ?? this.diveIds,
    maxDepth: maxDepth ?? this.maxDepth,
    speciesCount: speciesCount ?? this.speciesCount,
    depths: depths ?? this.depths,
    sites: sites ?? this.sites,
  );
}

/// The dive's day as a count of days, free of daylight saving: the wall
/// clock's calendar fields read in UTC.
int _dayNumber(DateTime wallClock) =>
    DateTime.utc(
      wallClock.year,
      wallClock.month,
      wallClock.day,
    ).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

DateTime _localDay(DateTime wallClock) =>
    DateTime(wallClock.year, wallClock.month, wallClock.day);

/// Groups [dives] into outings, newest first by their last dive, at most
/// [limit].
///
/// Every dive on a trip belongs to that trip's outing. Trip-less dives are
/// grouped among themselves in date order: a dive joins the previous
/// trip-less dive's outing when its day is at most [maxGapDays] after that
/// dive's day.
///
/// [cutAt] says the trip-less dives in [dives] are the newest part of a
/// longer log, read back to that dive time: older ones exist but were not
/// read. A trip-less outing beginning within [maxGapDays] of the cut may be
/// missing some of them, so it is dropped, unless it is the only outing.
/// Trip outings must be whole: the caller reads every dive of each trip.
List<Outing> groupOutings(
  List<OutingDive> dives, {
  int limit = 8,
  int maxGapDays = 2,
  DateTime? cutAt,
}) {
  final sorted = [...dives]..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  final byTrip = <String, List<OutingDive>>{};
  final tripless = <List<OutingDive>>[];
  for (final dive in sorted) {
    final trip = dive.tripId;
    if (trip != null) {
      (byTrip[trip] ??= []).add(dive);
      continue;
    }
    final last = tripless.isEmpty ? null : tripless.last.last;
    if (last != null &&
        _dayNumber(dive.dateTime) - _dayNumber(last.dateTime) <= maxGapDays) {
      tripless.last.add(dive);
    } else {
      tripless.add([dive]);
    }
  }
  final groups = [...byTrip.values, ...tripless]
    ..sort((a, b) => b.last.dateTime.compareTo(a.last.dateTime));
  if (cutAt != null && groups.length > 1) {
    final cutDay = _dayNumber(cutAt);
    groups.removeWhere(
      (g) =>
          g.first.tripId == null &&
          _dayNumber(g.first.dateTime) - cutDay <= maxGapDays,
    );
  }
  return [for (final g in groups.take(limit)) _outingOf(g)];
}

Outing _outingOf(List<OutingDive> dives) {
  final first = dives.first;
  final depths = [for (final d in dives) d.maxDepth ?? 0];
  final known = [
    for (final d in dives)
      if (d.maxDepth != null) d.maxDepth!,
  ];
  return Outing(
    tripId: first.tripId,
    name: first.tripId != null ? first.tripName : _mostDivedSite(dives),
    firstDay: _localDay(first.dateTime),
    lastDay: _localDay(dives.last.dateTime),
    diveIds: List.unmodifiable([for (final d in dives) d.id]),
    maxDepth: known.isEmpty ? null : known.reduce((a, b) => a > b ? a : b),
    speciesCount: {for (final d in dives) ...d.speciesIds}.length,
    depths: List.unmodifiable(depths),
    sites: List.unmodifiable(
      {
        for (final d in dives)
          // 0,0 is the usual stand-in for an unknown position.
          if (d.siteLatitude != null &&
              d.siteLongitude != null &&
              !(d.siteLatitude == 0 && d.siteLongitude == 0))
            (latitude: d.siteLatitude!, longitude: d.siteLongitude!),
      }.toList(),
    ),
  );
}

/// The site with the most of [dives] (in date order); a tie goes to the site
/// dived first.
String? _mostDivedSite(List<OutingDive> dives) {
  final counts = <String, int>{};
  for (final d in dives) {
    final site = d.siteName?.trim();
    if (site == null || site.isEmpty) continue;
    counts[site] = (counts[site] ?? 0) + 1;
  }
  String? best;
  for (final entry in counts.entries) {
    // Map iteration follows insertion, which is date order.
    if (best == null || entry.value > counts[best]!) best = entry.key;
  }
  return best;
}

/// A photo or video that could be an outing's cover.
@immutable
class CoverCandidate {
  final String mediaId;
  final String diveId;
  final bool isVideo;
  final bool isFavorite;
  final bool hasSpeciesTag;
  final DateTime? takenAt;

  const CoverCandidate({
    required this.mediaId,
    required this.diveId,
    required this.isVideo,
    required this.isFavorite,
    required this.hasSpeciesTag,
    this.takenAt,
  });

  CoverCandidate copyWith({
    String? mediaId,
    String? diveId,
    bool? isVideo,
    bool? isFavorite,
    bool? hasSpeciesTag,
    DateTime? takenAt,
  }) => CoverCandidate(
    mediaId: mediaId ?? this.mediaId,
    diveId: diveId ?? this.diveId,
    isVideo: isVideo ?? this.isVideo,
    isFavorite: isFavorite ?? this.isFavorite,
    hasSpeciesTag: hasSpeciesTag ?? this.hasSpeciesTag,
    takenAt: takenAt ?? this.takenAt,
  );
}

/// The cover among [candidates]: a favourite, else one with a species tag,
/// else any; within a tier photos before videos, then the earliest (an
/// undated item last), then by id so the choice is stable. Null with none.
String? chooseOutingCover(Iterable<CoverCandidate> candidates) {
  int tier(CoverCandidate c) => c.isFavorite
      ? 0
      : c.hasSpeciesTag
      ? 1
      : 2;
  int compare(CoverCandidate a, CoverCandidate b) {
    final byTier = tier(a).compareTo(tier(b));
    if (byTier != 0) return byTier;
    if (a.isVideo != b.isVideo) return a.isVideo ? 1 : -1;
    final at = a.takenAt, bt = b.takenAt;
    if (at != bt) {
      if (at == null) return 1;
      if (bt == null) return -1;
      final byTime = at.compareTo(bt);
      if (byTime != 0) return byTime;
    }
    return a.mediaId.compareTo(b.mediaId);
  }

  final sorted = [...candidates]..sort(compare);
  return sorted.isEmpty ? null : sorted.first.mediaId;
}
