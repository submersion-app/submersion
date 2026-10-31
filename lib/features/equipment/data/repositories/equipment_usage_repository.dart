import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_stats_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/core/utils/stream_debounce.dart';
import 'package:submersion/features/equipment/data/repositories/dive_gear_usage_sql.dart';
import 'package:submersion/features/equipment/domain/reports/cost_of_ownership.dart';

/// Whole-library usage figures for the equipment reports, one query each, so
/// the Insights sections never read every dive's samples to add up a total.
class EquipmentUsageRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final _log = LoggerService.forClass(EquipmentUsageRepository);

  static const _tickDebounce = Duration(milliseconds: 300);

  /// `diveGearUsageSql` lists a pair once per link, so a dive on a tank and
  /// the gear list reads twice there; here it reads once.
  static final _distinctPairsSql =
      '(SELECT DISTINCT dive_id, equipment_id FROM (${diveGearUsageSql()}))';

  /// Fires when a dive, or any link between a dive and gear, changes.
  Stream<void> watchChanges() => _db
      .tableUpdates(
        TableUpdateQuery.allOf([
          TableUpdateQuery.onTable(_db.dives),
          TableUpdateQuery.onTable(_db.diveEquipment),
          TableUpdateQuery.onTable(_db.diveTanks),
          TableUpdateQuery.onTable(_db.transmitters),
        ]),
      )
      .debounce(_tickDebounce);

  ({String clause, List<Variable<Object>> variables}) _diverFilter(
    String? diverId,
  ) => diverId == null
      ? (clause: '', variables: const [])
      : (clause: 'AND d.diver_id = ?', variables: [Variable(diverId)]);

  /// Each item's dives and hours among the dives that count toward
  /// statistics. Items with none are absent.
  Future<Map<String, GearUsageTotals>> getUsageTotals({String? diverId}) async {
    try {
      final diver = _diverFilter(diverId);
      final rows = await _db.customSelect('''
        SELECT u.equipment_id AS equipment_id,
               COUNT(*) AS dive_count,
               SUM($diveLengthSql) AS seconds
        FROM $_distinctPairsSql u
        JOIN dives d ON d.id = u.dive_id
        WHERE 1 = 1 ${diver.clause} ${DiveStatsScope.and(alias: 'd')}
        GROUP BY u.equipment_id
        ''', variables: diver.variables).get();
      return {
        for (final row in rows)
          row.read<String>('equipment_id'): GearUsageTotals(
            diveCount: row.read<int>('dive_count'),
            hours: row.read<int>('seconds') / 3600,
          ),
      };
    } catch (e, stackTrace) {
      _log.error(
        'Failed to read gear usage totals',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// When each item was last in the water, as the wall clock flagged UTC.
  /// Items never dived are absent.
  Future<Map<String, DateTime>> getLastDiveDates({String? diverId}) async {
    try {
      final diver = _diverFilter(diverId);
      // stats-scope-exempt: a dive left out of statistics still put the gear
      // in the water, so it counts as use. A planned dive did not.
      final rows = await _db.customSelect('''
        SELECT u.equipment_id AS equipment_id,
               MAX(d.dive_date_time) AS last_ms
        FROM $_distinctPairsSql u
        JOIN dives d ON d.id = u.dive_id
        WHERE d.is_planned = 0 ${diver.clause}
        GROUP BY u.equipment_id
        ''', variables: diver.variables).get();
      return {
        for (final row in rows)
          row.read<String>('equipment_id'): wallClockUtcFromMillis(
            row.read<int>('last_ms'),
          ),
      };
    } catch (e, stackTrace) {
      _log.error(
        'Failed to read last dive dates',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// The diver's dives that count toward statistics.
  Future<int> getStatsDiveCount({String? diverId}) async {
    try {
      final diver = _diverFilter(diverId);
      final row = await _db.customSelect('''
        SELECT COUNT(*) AS total
        FROM dives d
        WHERE 1 = 1 ${diver.clause} ${DiveStatsScope.and(alias: 'd')}
        ''', variables: diver.variables).getSingle();
      return row.read<int>('total');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to count statistics dives',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
