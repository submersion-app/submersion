import 'package:flutter/material.dart' show DateTimeRange;

import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';

/// Most tracks the overview map draws at once, across both kinds.
///
/// Every track drawn hydrates a full point blob and, for GPS on a cold
/// cache, spawns its own simplification isolate; the date filter defaults
/// to unbounded, so without a cap a large library would do that for every
/// track in one frame. Newest first, because that is what a diver looks for.
const int kTracksOverviewLimit = 40;

/// Whether [startMs] falls inside [range], inclusive of the end date's whole
/// day.
///
/// The range is read as calendar days: the date picker hands back local
/// midnights, while track start times are wall-clock-as-UTC, so comparing
/// the range's own instants would shift both bounds by the device's UTC
/// offset. Each bound is rebuilt as a wall-clock-as-UTC day boundary, using
/// day arithmetic rather than adding a Duration so no DST change can move it.
bool startsWithin(int startMs, DateTimeRange range) {
  final from = DateTime.utc(
    range.start.year,
    range.start.month,
    range.start.day,
  ).millisecondsSinceEpoch;
  final to =
      DateTime.utc(
        range.end.year,
        range.end.month,
        range.end.day + 1,
      ).millisecondsSinceEpoch -
      1;
  return startMs >= from && startMs <= to;
}

/// Both kinds as one list: filtered by [kind] and [range], newest first.
///
/// Ties on start time break by selection key: `List.sort` is not stable,
/// and without a tie-breaker two tracks starting together could swap places
/// between rebuilds.
List<TrackListItem> mergeTracks({
  required List<GpsTrack> gps,
  required List<NavTrack> underwater,
  required TrackKindFilter kind,
  required DateTimeRange? range,
}) {
  final items = <TrackListItem>[
    if (kind.admits(TrackKind.gps))
      for (final track in gps) GpsTrackItem(track),
    if (kind.admits(TrackKind.underwater))
      for (final track in underwater) UnderwaterTrackItem(track),
  ];
  final bounded = range == null
      ? items
      : [
          for (final item in items)
            if (startsWithin(item.startTime, range)) item,
        ];
  final sorted = [...bounded]
    ..sort((a, b) {
      final byTime = b.startTime.compareTo(a.startTime);
      return byTime != 0 ? byTime : a.selectionKey.compareTo(b.selectionKey);
    });
  return List.unmodifiable(sorted);
}

/// What the overview map draws: the newest [limit] mappable items, and
/// whether the cap dropped any the filters allowed.
({List<TrackListItem> items, bool truncated}) capOverview(
  List<TrackListItem> items, {
  int limit = kTracksOverviewLimit,
}) {
  final mappable = [
    for (final item in items)
      if (item.isMappable) item,
  ];
  return (
    items: List.unmodifiable(mappable.take(limit)),
    truncated: mappable.length > limit,
  );
}
