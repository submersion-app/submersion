import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_stats_scope.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
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

  /// How a counted dive reaches a row of [subject]: a join (or none) and
  /// the row id it yields.
  static ({String join, String id}) _link(ParsedSubject subject) =>
      switch (subject) {
        ParsedSubject.sites => (join: '', id: 'd.site_id'),
        ParsedSubject.trips => (join: '', id: 'd.trip_id'),
        ParsedSubject.centers => (join: '', id: 'd.dive_center_id'),
        ParsedSubject.buddies => (
          join: 'JOIN dive_buddies j ON j.dive_id = d.id',
          id: 'j.buddy_id',
        ),
        ParsedSubject.species => (
          join: 'JOIN sightings s ON s.dive_id = d.id',
          id: 's.species_id',
        ),
        // The dive gear union: linked through dive_equipment, or a cylinder
        // matched through dive_tanks. UNION drops the pair both give.
        ParsedSubject.equipment => (
          join:
              'JOIN (SELECT dive_id, equipment_id FROM dive_equipment '
              'UNION SELECT dive_id, equipment_id FROM dive_tanks '
              'WHERE equipment_id IS NOT NULL) g ON g.dive_id = d.id',
          id: 'g.equipment_id',
        ),
        ParsedSubject.dives => throw ArgumentError.value(
          subject,
          'subject',
          'dives are counted by the dive queries',
        ),
      };

  /// The tables [diveCountsBySubject] reads besides `dives`.
  static Set<String> subjectCountTables(ParsedSubject subject) =>
      switch (subject) {
        ParsedSubject.buddies => const {'dive_buddies'},
        ParsedSubject.species => const {'sightings'},
        ParsedSubject.equipment => const {'dive_equipment', 'dive_tanks'},
        _ => const <String>{},
      };

  /// For each row of [subject] with a counted dive of [diverId] matching
  /// [diveScope], how many (descriptive, so the stats scope applies). The
  /// ranking and the one chart of a non-dive Explore answer read this.
  Future<Map<String, int>> diveCountsBySubject(
    ParsedSubject subject,
    QueryNode? diveScope, {
    String? diverId,
  }) async {
    final link = _link(subject);
    final f = buildFilteredDiveIdSubquery(DiveFilterState(query: diveScope));
    final params = <Object?>[];
    var where = '${link.id} IS NOT NULL ${DiveStatsScope.and(alias: 'd')}';
    if (diverId != null) {
      where += ' AND d.diver_id = ?';
      params.add(diverId);
    }
    if (f.subquery.isNotEmpty) {
      where += ' AND d.id IN (${f.subquery})';
      params.addAll(f.params);
    }
    final rows = await _db.customSelect('''
      SELECT ${link.id} AS id, COUNT(DISTINCT d.id) AS n
      FROM dives d ${link.join}
      WHERE $where
      GROUP BY ${link.id}
      ''', variables: params.map((p) => Variable(p)).toList()).get();
    return {for (final r in rows) r.read<String>('id'): r.read<int>('n')};
  }
}
