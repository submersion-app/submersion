import 'package:drift/drift.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/certifications/domain/entities/dive_activity_index.dart';
import 'package:submersion/features/certifications/domain/services/calendar_days.dart';

/// The three aggregates behind activity clocks (issue #2267). Dive times are
/// wall-clock UTC, read exactly as daysSinceLastDiveProvider reads them, so
/// the currency chip and the last-dive chip never disagree by a day.
class DiveActivityRepository {
  AppDatabase get _db => DatabaseService.instance.database;

  static const _when = 'COALESCE(d.entry_time, d.dive_date_time)';

  Stream<void> watchDiveChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.dives),
      TableUpdateQuery.onTable(_db.diveDiveTypes),
    ]),
  );

  Future<DiveActivityIndex> buildIndex({String? diverId}) async {
    final scope = diverId == null ? '' : 'AND d.diver_id = ?';
    final vars = [if (diverId != null) Variable.withString(diverId)];

    final last = await _db
        .customSelect(
          'SELECT MAX($_when) AS t FROM dives d WHERE d.is_planned = 0 $scope',
          variables: vars,
        )
        .getSingle();
    final byType = await _db
        .customSelect(
          'SELECT ddt.dive_type_id AS k, MAX($_when) AS t '
          'FROM dive_dive_types ddt JOIN dives d ON d.id = ddt.dive_id '
          'WHERE d.is_planned = 0 $scope GROUP BY ddt.dive_type_id',
          variables: vars,
        )
        .get();
    final byMode = await _db
        .customSelect(
          'SELECT d.dive_mode AS k, MAX($_when) AS t FROM dives d '
          'WHERE d.is_planned = 0 $scope GROUP BY d.dive_mode',
          variables: vars,
        )
        .get();

    return DiveActivityIndex(
      lastDiveAt: _day(last.read<int?>('t')),
      lastDiveByTypeId: {
        for (final r in byType) r.read<String>('k'): ?_day(r.read<int?>('t')),
      },
      lastDiveByMode: {
        for (final r in byMode)
          DiveMode.fromCode(r.read<String>('k')): ?_day(r.read<int?>('t')),
      },
    );
  }

  static DateTime? _day(int? ms) => ms == null
      ? null
      : calendarDay(DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true));
}
