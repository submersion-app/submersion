import 'package:drift/drift.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    as domain;

/// The buddy card columns (issue #3728), written and read the same way by
/// every repository that touches a buddy row.
///
/// The last dive is a calendar date, stored as the start of that day in
/// wall-clock UTC, so a synced device in another time zone reads the same
/// day. The received time is an instant; the diving-since value is a year.
abstract final class BuddyCardColumns {
  /// [buddy]'s card columns, for an insert or an update.
  static BuddiesCompanion of(domain.Buddy buddy) => BuddiesCompanion(
    cardId: Value(buddy.cardId),
    socialHandle: Value(buddy.socialHandle),
    cardDiveCount: Value(buddy.cardDiveCount),
    cardDivingSince: Value(buddy.cardDivingSince?.year),
    cardLastDive: Value(
      buddy.cardLastDive == null
          ? null
          : wallClockUtcDayStart(buddy.cardLastDive!).millisecondsSinceEpoch,
    ),
    cardReceivedAt: Value(buddy.cardReceivedAt?.millisecondsSinceEpoch),
  );

  static DateTime? divingSince(int? year) =>
      year == null ? null : DateTime(year);

  static DateTime? lastDive(int? ms) =>
      ms == null ? null : fromWallClockUtc(wallClockUtcFromMillis(ms));

  static DateTime? receivedAt(int? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
}
