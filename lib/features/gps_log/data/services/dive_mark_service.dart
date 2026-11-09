import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_draft_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/gps_track_matcher.dart';

/// "Entered water" and "Surfaced" at the dive site (issue #637): each pair
/// of taps makes one draft dive, at the recorded track's position at each
/// tap. The buttons on the GPS log and the lock screen actions both call it.
class DiveMarkService {
  DiveMarkService({
    required DiveDraftRepository drafts,
    required String? Function() currentDiverId,
    required Future<List<GpsTrackPoint>> Function() recordedPoints,
    DateTime Function()? clock,
  }) : _drafts = drafts,
       _currentDiverId = currentDiverId,
       _recordedPoints = recordedPoints,
       _clock = clock ?? DateTime.now;

  final DiveDraftRepository _drafts;
  final String? Function() _currentDiverId;

  /// The running recording's points so far, empty when nothing records.
  final Future<List<GpsTrackPoint>> Function() _recordedPoints;
  final DateTime Function() _clock;

  /// The diver who last tapped "Entered water" here, so "Surfaced" closes
  /// their draft even if the app switched to another diver meanwhile.
  String? _enteredDiverId;

  /// Marks [diverId] in the water at [at] (now by default), wall clock
  /// flagged UTC. A second tap while that diver is already in the water
  /// keeps the open draft rather than making another.
  Future<Dive> enteredWater({required String diverId, DateTime? at}) async {
    _enteredDiverId = diverId;
    final open = await _drafts.openDraftFor(diverId);
    if (open != null) return open;
    final when = at ?? asWallClockUtc(_clock());
    return _drafts.createDraft(
      diverId: diverId,
      entryTime: when,
      entryLocation: await _positionAt(when),
    );
  }

  /// Closes the open draft at [at] (now by default): the draft of the diver
  /// who entered the water from here, else the current diver's. Null when
  /// there is no open draft.
  Future<Dive?> surfaced({DateTime? at}) async {
    final diverId = _enteredDiverId ?? _currentDiverId();
    if (diverId == null) return null;
    final open = await _drafts.openDraftFor(diverId);
    if (open == null) return null;
    final when = at ?? asWallClockUtc(_clock());
    await _drafts.closeDraft(
      open.id,
      exitTime: when,
      exitLocation: await _positionAt(when),
    );
    _enteredDiverId = null;
    return open.copyWith(exitTime: when);
  }

  Future<GeoPoint?> _positionAt(DateTime wallClock) async {
    final points = await _recordedPoints();
    final position = GpsTrackMatcher.positionAt(
      points,
      wallClock.millisecondsSinceEpoch ~/ 1000,
    );
    return position == null
        ? null
        : GeoPoint(position.latitude, position.longitude);
  }
}
