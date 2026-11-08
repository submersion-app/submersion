import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_times_sql.dart';

/// The id of the logged dive that ended last after [endedAfter] and at or
/// before [notAfter], or null when none did: the dive the planner offers to
/// follow (issue #4250). One indexed lookup ([latestEndedDiveSql]) rather
/// than a read of the whole log.
///
/// [diverId] scopes it to one diver, and null reads every diver. A dive that
/// started more than [longestDive] before [endedAfter] is not read, however
/// late it ended.
// stats-scope-exempt: the planner's latest dive, not a statistic
Future<String?> latestEndedDiveId(
  AppDatabase db, {
  String? diverId,
  required DateTime endedAfter,
  required DateTime notAfter,
  Duration longestDive = const Duration(days: 1),
}) async {
  final rows = await db
      .customSelect(
        latestEndedDiveSql(scopedToDiver: diverId != null),
        variables: [
          Variable<int>(
            endedAfter.subtract(longestDive).millisecondsSinceEpoch,
          ),
          Variable<int>(endedAfter.millisecondsSinceEpoch),
          Variable<int>(notAfter.millisecondsSinceEpoch),
          if (diverId != null) Variable<String>(diverId),
        ],
        readsFrom: {db.dives, db.diveProfileSeries, db.diveDataSources},
      )
      .get();
  return rows.isEmpty ? null : rows.first.read<String>('id');
}
