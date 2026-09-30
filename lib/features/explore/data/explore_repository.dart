import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_stats_scope.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/data/dive_filter_sql.dart';

/// Queries Explore needs that no existing repository offers.
class ExploreRepository {
  ExploreRepository({AppDatabase? db}) : _dbOverride = db;
  final AppDatabase? _dbOverride;
  AppDatabase get _db => _dbOverride ?? DatabaseService.instance.database;

  /// Dives per site under [filter], descriptive, so the stats scope applies.
  Future<List<({String siteId, String name, int count})>> diveCountBySite(
    DiveFilterState filter, {
    String? diverId,
    int limit = 10,
  }) async {
    final f = buildFilteredDiveIdSubquery(filter);
    final params = <Object?>[];
    var where = 'd.site_id IS NOT NULL ${DiveStatsScope.and(alias: 'd')}';
    if (diverId != null) {
      where += ' AND d.diver_id = ?';
      params.add(diverId);
    }
    if (f.subquery.isNotEmpty) {
      where += ' AND d.id IN (${f.subquery})';
      params.addAll(f.params);
    }
    params.add(limit);
    final rows = await _db.customSelect('''
      SELECT d.site_id AS site_id, s.name AS name, COUNT(*) AS n
      FROM dives d JOIN dive_sites s ON s.id = d.site_id
      WHERE $where
      GROUP BY d.site_id ORDER BY n DESC, s.name ASC LIMIT ?
      ''', variables: params.map((p) => Variable(p)).toList()).get();
    return rows
        .map(
          (r) => (
            siteId: r.read<String>('site_id'),
            name: r.read<String>('name'),
            count: r.read<int>('n'),
          ),
        )
        .toList();
  }

  /// The distinct legacy `dives.buddy` texts, as sentence-only buddies.
  /// Explore's alone (#2641): kept out of the shared name index, whose
  /// reload would otherwise follow every dive write.
  Future<List<NameEntry>> legacyBuddyNames({String? diverId}) async {
    final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
    final rows = await _db
        .customSelect(
          'SELECT DISTINCT buddy FROM dives '
          "WHERE buddy IS NOT NULL AND buddy <> '' $diverFilter "
          'ORDER BY buddy',
          variables: [if (diverId != null) Variable<String>(diverId)],
        )
        .get();
    return [
      for (final r in rows)
        NameEntry(
          subject: QuerySubject.buddies,
          label: r.read<String>('buddy'),
          ids: const [],
          target: NameTarget.legacyBuddyName,
          rank: 1,
        ),
    ];
  }
}
