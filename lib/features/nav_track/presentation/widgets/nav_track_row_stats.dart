import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/tracks/presentation/widgets/track_stat_row.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Duration up to the last dead-reckoned sample, as stored at import
/// (`durationSeconds`, the same active range `NavTrackStats.of` and the
/// 3D/2D ribbons stop at). `route.endTime` is the raw recording's own last
/// timestamp, which on a file with a surface GPS fix (011.DAT.csv) includes
/// the post-surfacing walk; the raw span is only the fallback for a row
/// stored before the duration was.
///
/// Public (not `nav_track_list_row.dart`-private) because both that file's
/// `formatNavTrackDetailLine` (the map info card's full joined string) and
/// [navTrackStats] below (the list row's stat row) need the same formatting.
String formatNavTrackDuration(AppLocalizations l10n, NavTrack route) {
  final seconds =
      route.durationSeconds ??
      ((route.endTime - route.startTime) / 1000).round();
  final d = Duration(seconds: seconds < 0 ? 0 : seconds);
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  return h > 0
      ? l10n.navTrack_list_durationHours(h, m)
      : l10n.navTrack_list_durationMinutes(m);
}

/// [route]'s distance, max depth and duration as [TrackStat]s for the list
/// row's stat line, each omitted when its source value is null (duration is
/// always present). Unlike the GPS row's duration -- baked into one ICU
/// sentence per locale -- these are plain optional fields already joined
/// with a literal `' · '` in `formatNavTrackDetailLine`, so splitting them
/// back out here is purely mechanical and locale-safe.
List<TrackStat> navTrackStats(
  AppLocalizations l10n,
  UnitFormatter units,
  NavTrack route,
) => [
  if (route.totalDistance != null)
    TrackStat(
      icon: Icons.straighten,
      text: units.formatDistance(route.totalDistance!),
    ),
  if (route.maxDepth != null)
    TrackStat(
      icon: Icons.arrow_downward,
      text: units.formatDepth(route.maxDepth),
    ),
  TrackStat(icon: Icons.schedule, text: formatNavTrackDuration(l10n, route)),
];

/// [route]'s date and device name only (distance/maxDepth/duration moved to
/// [navTrackStats] instead), for the list row's meta line.
/// `formatNavTrackDetailLine` in `nav_track_list_row.dart` keeps the full
/// joined string -- still used verbatim by the map info card's subtitle.
String navTrackMetaLine(UnitFormatter units, NavTrack route) {
  final startedAt = DateTime.fromMillisecondsSinceEpoch(
    route.startTime,
    isUtc: true,
  );
  return [
    units.formatDate(startedAt),
    if (route.deviceName != null) route.deviceName!,
  ].join(' · ');
}
