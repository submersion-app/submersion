import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/passport_usage.dart';

/// The dives a tagged cylinder was used on (issue #2650), derived from
/// `dive_tanks.passport_id`. Read-only: stamping happens where tanks are
/// edited.
class PassportUsageRepository {
  AppDatabase get _db => DatabaseService.instance.database;

  /// The distinct logged dives (never a planned one) with a tank whose
  /// passport id is [passportId], newest first. [diverId] limits them to that diver's dives (all dives
  /// when null, like the dive list); [excludeDiveId] leaves one out.
  Future<List<PassportUsageDive>> usageFor(
    String passportId, {
    required String? diverId,
    String? excludeDiveId,
  }) async {
    // IN rather than a join, so a dive with two tanks from one tag is one
    // row without a DISTINCT; and rather than a correlated EXISTS, which
    // scans every dive, so the lookup starts from idx_dive_tanks_passport_id.
    final rows = await _db
        .customSelect(
          'SELECT d.id AS dive_id, d.dive_date_time AS dive_date_time, '
          'd.dive_number AS dive_number, s.name AS site_name '
          'FROM dives d '
          'LEFT JOIN dive_sites s ON s.id = d.site_id '
          'WHERE d.id IN (SELECT t.dive_id FROM dive_tanks t '
          'WHERE t.passport_id = ?) '
          // A planned dive has not happened: the cylinder is not used yet.
          'AND d.is_planned = 0 '
          '${diverId == null ? '' : 'AND d.diver_id = ? '}'
          '${excludeDiveId == null ? '' : 'AND d.id != ? '}'
          'ORDER BY d.dive_date_time DESC, d.id',
          variables: [
            Variable.withString(passportId),
            if (diverId != null) Variable.withString(diverId),
            if (excludeDiveId != null) Variable.withString(excludeDiveId),
          ],
          readsFrom: {_db.dives, _db.diveTanks, _db.diveSites},
        )
        .get();
    return [
      for (final r in rows)
        PassportUsageDive(
          diveId: r.read<String>('dive_id'),
          dateTime: DateTime.fromMillisecondsSinceEpoch(
            r.read<int>('dive_date_time'),
            isUtc: true,
          ),
          diveNumber: r.read<int?>('dive_number'),
          siteName: r.read<String?>('site_name'),
        ),
    ];
  }

  /// Ticks when a dive, a tank or a site changes, so a usage card refreshes.
  Stream<void> watchChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.dives),
      TableUpdateQuery.onTable(_db.diveTanks),
      TableUpdateQuery.onTable(_db.diveSites),
    ]),
  );
}
