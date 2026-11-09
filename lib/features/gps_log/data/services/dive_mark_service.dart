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
    required Future<List<GpsTrackPoint>> Function() recordedPoints,
    DateTime Function()? clock,
  }) : _drafts = drafts,
       _recordedPoints = recordedPoints,
       _clock = clock ?? DateTime.now;

  final DiveDraftRepository _drafts;

  /// The running recording's points so far, empty when nothing records.
  final Future<List<GpsTrackPoint>> Function() _recordedPoints;
  final DateTime Function() _clock;

  /// The marks, one at a time: each reads the open dive and then writes, so
  /// two quick taps (or a button and a lock screen tap) must not both find
  /// none open and make two drafts.
  Future<void> _last = Future.value();

  Future<T> _inTurn<T>(Future<T> Function() mark) {
    final result = _last.then((_) => mark());
    _last = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  /// Marks [diverId] in the water at [at] (now by default), wall clock
  /// flagged UTC. While a dive is open on this device, whoever's it is, the
  /// tap keeps it rather than making another: the buttons then offer
  /// Surfaced, so this is a late or repeated tap.
  Future<Dive> enteredWater({required String diverId, DateTime? at}) =>
      _inTurn(() async {
        final open = await _drafts.openDraftFor(null);
        if (open != null) return open;
        final when = at ?? asWallClockUtc(_clock());
        return _drafts.createDraft(
          diverId: diverId,
          entryTime: when,
          entryLocation: await _positionAt(when),
        );
      });

  /// Closes the dive open on this device at [at] (now by default), whoever's
  /// it is, so a diver switch or a restart between the taps cannot strand
  /// it. Null when no dive is open.
  Future<Dive?> surfaced({DateTime? at}) => _inTurn(() async {
    final open = await _drafts.openDraftFor(null);
    if (open == null) return null;
    final when = at ?? asWallClockUtc(_clock());
    await _drafts.closeDraft(
      open.id,
      exitTime: when,
      exitLocation: await _positionAt(when),
    );
    return open.copyWith(exitTime: when);
  });

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
