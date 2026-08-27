import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Row labels shared by the two surfaces that list tracks: the GPS logger page
/// and the overview map's list pane. They drifted apart once already, showing
/// different times and counts for the same track.

/// The start of the track as trimmed, in the diver's date and time format.
///
/// Track times are wall-clock-as-UTC - the recording device's local clock
/// reinterpreted as UTC - so the UTC components are formatted directly and
/// never converted to device-local.
String formatTrackStart(UnitFormatter units, GpsTrack track) {
  final start = DateTime.fromMillisecondsSinceEpoch(
    track.effectiveStartTime,
    isUtc: true,
  );
  return '${units.formatDate(start)} ${units.formatTime(start)}';
}

/// Compact duration, matching the app-wide dive_field_formatter style
/// ("Xh Ym" at an hour or more, "Xmin" below).
String formatCompactDuration(Duration duration) {
  if (duration.inHours < 1) return '${duration.inMinutes}min';
  return '${duration.inHours}h ${duration.inMinutes % 60}m';
}

/// Duration of the track as trimmed, compactly ("47min", "3h 12m").
///
/// The trim bounds are stored scalars, so this stays correct even though list
/// rows are hydrated without points.
String formatTrackDuration(GpsTrack track) {
  final end = track.effectiveEndTime;
  if (end == null) return '--';
  return formatCompactDuration(
    Duration(milliseconds: end - track.effectiveStartTime),
  );
}

/// The user's label when they gave one, else the start time.
String formatTrackTitle(UnitFormatter units, GpsTrack track) {
  final name = track.name?.trim();
  if (name != null && name.isNotEmpty) return name;
  return formatTrackStart(units, track);
}

/// The line under [formatTrackTitle]: fixes and duration, led by the start
/// time when the title is a name and would otherwise hide it.
String formatTrackDetailLine(
  AppLocalizations l10n,
  UnitFormatter units,
  GpsTrack track,
) {
  final figures = formatTrackSubtitle(l10n, track, formatTrackDuration(track));
  final start = formatTrackStart(units, track);
  return formatTrackTitle(units, track) == start
      ? figures
      : '$start • $figures';
}

/// Fix count and duration, both honouring a trim.
///
/// [effectivePointCount] is null when a trim exists but the row was hydrated
/// without points, which is every list row. Printing the stored (untrimmed)
/// count beside a trimmed duration would contradict the detail page, so the
/// count is dropped and the row says it is trimmed instead.
String formatTrackSubtitle(
  AppLocalizations l10n,
  GpsTrack track,
  String duration,
) {
  final count = track.effectivePointCount;
  return count == null
      ? l10n.gpsLogger_trackSubtitleTrimmed(duration)
      : l10n.gpsLogger_trackSubtitle(count, duration);
}
