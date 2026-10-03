import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/tracks/domain/track_kind.dart';

/// One row of the Tracks area: a GPS surface track or an underwater track.
///
/// Each variant wraps its own entity unchanged, so the existing rows, info
/// cards and polyline layers render it; this type only carries what the
/// merged list, the map and the summary need to treat both alike.
sealed class TrackListItem {
  const TrackListItem();

  String get id;

  TrackKind get kind;

  /// Wall-clock-as-UTC epoch milliseconds, the dives.entryTime convention.
  int get startTime;

  /// Null for a GPS track still recording.
  int? get endTime;

  /// Whether the overview map can place it. Underwater tracks without an
  /// anchor have no position on Earth and show only in the list.
  bool get isMappable;

  /// Time the summary counts; null when there is nothing to count yet.
  Duration? get recordedTime;

  /// Selection identity, qualified by kind so ids from the two tables can
  /// never resolve to the wrong one.
  String get selectionKey => '${kind.name}:$id';
}

final class GpsTrackItem extends TrackListItem {
  const GpsTrackItem(this.track);

  final GpsTrack track;

  @override
  String get id => track.id;

  @override
  TrackKind get kind => TrackKind.gps;

  /// Trim-aware, matching what the track's own detail page shows.
  @override
  int get startTime => track.effectiveStartTime;

  @override
  int? get endTime => track.effectiveEndTime;

  @override
  bool get isMappable => true;

  @override
  Duration? get recordedTime {
    final end = endTime;
    if (end == null) return null;
    return Duration(milliseconds: end - startTime);
  }
}

final class UnderwaterTrackItem extends TrackListItem {
  const UnderwaterTrackItem(this.track);

  final NavTrack track;

  @override
  String get id => track.id;

  @override
  TrackKind get kind => TrackKind.underwater;

  @override
  int get startTime => track.startTime;

  @override
  int? get endTime => track.endTime;

  @override
  bool get isMappable => track.anchor != null;

  /// The stored dive duration (up to the last dead-reckoned sample), with
  /// the raw recording span only for a row stored before it was.
  @override
  Duration? get recordedTime {
    final seconds =
        track.durationSeconds ??
        ((track.endTime - track.startTime) / 1000).round();
    return Duration(seconds: seconds < 0 ? 0 : seconds);
  }
}
