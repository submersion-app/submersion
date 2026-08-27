import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/services/trip_media_scanner.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';

/// Answers "which dive was this taken on?" for one timestamp, the way every
/// creator has to before it may insert a media row.
///
/// One implementation shared by the import review, the URL tab, the
/// manifest panel and the subscription poller, so a photo gets the same
/// answer whichever door it came in through.
class DiveLinkMatcher {
  DiveLinkMatcher({
    required DiveRepository diveRepository,
    DivePhotoMatcher matcher = const DivePhotoMatcher(),
  }) : _diveRepository = diveRepository,
       _matcher = matcher;

  final DiveRepository _diveRepository;
  final DivePhotoMatcher _matcher;

  /// Candidate window either side of the timestamp. Two days covers a
  /// camera clock a day off in either direction.
  static const Duration window = Duration(days: 2);

  /// Matcher bounds for [dives]: entryTime falling back to dateTime,
  /// exitTime falling back to dateTime + effectiveRuntime, else 60 minutes.
  /// Everything is normalized to wall-clock UTC so photo timestamps (stored
  /// wall-clock-as-UTC) compare against dive times (local wall clock) on
  /// one basis.
  static List<DiveBounds> boundsFor(List<Dive> dives) {
    return [
      for (final dive in dives)
        () {
          final entry = dive.entryTime ?? dive.dateTime;
          final exit =
              dive.exitTime ??
              (dive.effectiveRuntime != null
                  ? dive.dateTime.add(dive.effectiveRuntime!)
                  : dive.dateTime.add(const Duration(minutes: 60)));
          return DiveBounds(
            diveId: dive.id,
            entryTime: TripMediaScanner.toWallClockUtc(entry),
            exitTime: TripMediaScanner.toWallClockUtc(exit),
          );
        }(),
    ];
  }

  /// Pure match of [takenAt] against [candidateDives].
  static TimestampMatch matchAgainst({
    required DateTime takenAt,
    required List<Dive> candidateDives,
    DivePhotoMatcher matcher = const DivePhotoMatcher(),
  }) {
    return matcher.matchTimestamp(
      takenAt: TripMediaScanner.toWallClockUtc(takenAt),
      dives: boundsFor(candidateDives),
    );
  }

  /// Loads the dives within [window] of [takenAt] and matches against them.
  Future<TimestampMatch> match(DateTime takenAt, {String? diverId}) async {
    final dives = await _diveRepository.getDivesInRange(
      takenAt.subtract(window),
      takenAt.add(window),
      diverId: diverId,
    );
    return matchAgainst(
      takenAt: takenAt,
      candidateDives: dives,
      matcher: _matcher,
    );
  }
}
