import 'package:drift/drift.dart';

import 'package:submersion/core/constants/dive_search.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/sql_templates.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_picker_row.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';

/// One page of [DivePickerRow]s, newest first, in the logbook's date order.
///
/// A single statement however large the logbook is (#3828). [query] matches
/// part of the dive number, the dive name or the site name, deliberately not
/// the wider logbook search: the picker names a dive the diver already has in
/// mind, by what its rows show. [cursor] is the last row of the previous page.
// stats-scope-exempt: a picker over the logbook, not a statistic. An excluded
// dive is still a dive media can be moved to.
Future<List<DivePickerRow>> divePickerRows(
  AppDatabase db, {
  String? diverId,
  String query = '',
  DiveSummaryCursor? cursor,
  int limit = kDivePickerPageSize,
}) async {
  // SQLite reads a negative LIMIT as no limit, which is the unbounded read
  // this query exists to avoid.
  if (limit <= 0) return const [];

  final where = <String>[];
  final args = <Variable<Object>>[];

  if (diverId != null) {
    where.add('d.diver_id = ?');
    args.add(Variable(diverId));
  }

  final term = query.trim();
  if (term.isNotEmpty) {
    // Folded by unicode_lower on the column and by Dart here, which is the
    // same folding: LIKE and LOWER() only fold ASCII.
    final like = '%${escapeLike(term.toLowerCase())}%';
    where.add(
      "(CAST(d.dive_number AS TEXT) LIKE ? ESCAPE '\\' "
      "OR unicode_lower(d.name) LIKE ? ESCAPE '\\' "
      "OR unicode_lower(s.name) LIKE ? ESCAPE '\\')",
    );
    args.addAll([Variable(like), Variable(like), Variable(like)]);
  }

  if (cursor != null) {
    where.add(
      '(COALESCE(d.entry_time, d.dive_date_time), '
      'COALESCE(d.dive_number, 0), d.id) < (?, ?, ?)',
    );
    args.addAll([
      Variable(cursor.sortTimestamp),
      Variable(cursor.diveNumber),
      Variable(cursor.id),
    ]);
  }

  final rows = await db
      .customSelect(
        'SELECT d.id, d.dive_number, d.name AS dive_name, d.dive_date_time, '
        'COALESCE(d.entry_time, d.dive_date_time) AS sort_timestamp, '
        's.name AS site_name '
        'FROM dives d '
        'LEFT JOIN dive_sites s ON d.site_id = s.id '
        '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')} '}'
        'ORDER BY sort_timestamp DESC, '
        'COALESCE(d.dive_number, 0) DESC, d.id DESC '
        'LIMIT ?',
        variables: [...args, Variable(limit)],
        readsFrom: {db.dives, db.diveSites},
      )
      .get();

  return [
    for (final row in rows)
      DivePickerRow(
        id: row.read<String>('id'),
        diveNumber: row.readNullable<int>('dive_number'),
        name: row.readNullable<String>('dive_name'),
        siteName: row.readNullable<String>('site_name'),
        dateTime: wallClockUtcFromMillis(row.read<int>('dive_date_time')),
        sortTimestamp: row.read<int>('sort_timestamp'),
      ),
  ];
}
