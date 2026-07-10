import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:submersion/core/database/performance_indexes.dart';

/// SQL-level benchmark harness for the large-DB performance program.
///
/// Runs the app's real hot-query shapes against a database COPY (never the
/// live file). Usage:
///
///     dart run tools/db_bench.dart bench <db-path> [--json] [--term blue]
///     dart run tools/db_bench.dart plans <db-path>
///     dart run tools/db_bench.dart create-indexes <db-path>
///
/// Query shapes are copied from dive_repository_impl.dart (getDiveSummaries,
/// getDiveCount, searchDives, _mapRowToDive, getPreviousDive). Keep them in
/// sync when those queries change materially.
void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln(
      'Usage: dart run tools/db_bench.dart <bench|plans|create-indexes> '
      '<db-path> [--json] [--term <search-term>]',
    );
    exit(64);
  }
  final mode = args[0];
  final dbPath = args[1];
  final asJson = args.contains('--json');
  final termIdx = args.indexOf('--term');
  final searchTerm = termIdx >= 0 && termIdx + 1 < args.length
      ? args[termIdx + 1]
      : 'blue';

  if (!File(dbPath).existsSync()) {
    stderr.writeln('No such file: $dbPath');
    exit(66);
  }

  final db = sqlite3.open(dbPath);
  try {
    switch (mode) {
      case 'bench':
        _bench(db, searchTerm, asJson);
      case 'plans':
        _plans(db, searchTerm);
      case 'create-indexes':
        _createIndexes(db);
      default:
        stderr.writeln('Unknown mode: $mode');
        exit(64);
    }
  } finally {
    db.dispose();
  }
}

/// The paginated dive list page-1 query, verbatim shape from
/// getDiveSummaries (default date sort, no cursor, no filters).
const _summariesSql =
    'SELECT '
    'd.id, d.dive_number, d.name AS dive_name, '
    'd.dive_date_time, d.entry_time, '
    'd.max_depth, d.bottom_time, d.runtime, d.water_temp, d.rating, '
    'd.is_favorite, d.dive_type, '
    'COALESCE(d.entry_time, d.dive_date_time) AS sort_timestamp, '
    's.name AS site_name, s.country AS site_country, '
    's.region AS site_region, s.latitude AS site_latitude, '
    's.longitude AS site_longitude '
    'FROM dives d '
    'LEFT JOIN dive_sites s ON d.site_id = s.id '
    'WHERE d.diver_id = ? '
    'ORDER BY sort_timestamp DESC, COALESCE(d.dive_number, 0) DESC, d.id DESC '
    'LIMIT 50';

/// The search match query, verbatim shape from searchDives.
const _searchSql = '''
    SELECT DISTINCT d.id
    FROM dives d
    LEFT JOIN dive_sites ds ON d.site_id = ds.id
    LEFT JOIN dive_centers dc ON d.dive_center_id = dc.id
    LEFT JOIN dive_buddies db ON db.dive_id = d.id
    LEFT JOIN buddies b ON db.buddy_id = b.id
    LEFT JOIN dive_tags dt ON dt.dive_id = d.id
    LEFT JOIN tags t ON dt.tag_id = t.id
    LEFT JOIN dive_custom_fields cf ON cf.dive_id = d.id
    WHERE (
      d.notes LIKE ?
      OR d.name LIKE ?
      OR d.buddy LIKE ?
      OR d.dive_master LIKE ?
      OR ds.name LIKE ?
      OR ds.country LIKE ?
      OR ds.region LIKE ?
      OR dc.name LIKE ?
      OR b.name LIKE ?
      OR t.name LIKE ?
      OR cf.field_key LIKE ?
      OR cf.field_value LIKE ?
    )
    AND d.diver_id = ?
    ''';

({String diverId, String denseDiveId, int denseSamples}) _pickTargets(
  Database db,
) {
  final diver = db.select(
    'SELECT diver_id, COUNT(*) AS n FROM dives '
    'GROUP BY diver_id ORDER BY n DESC LIMIT 1',
  );
  final dense = db.select(
    'SELECT dive_id, COUNT(*) AS n FROM dive_profiles '
    'GROUP BY dive_id ORDER BY n DESC LIMIT 1',
  );
  return (
    diverId: diver.first['diver_id'] as String,
    denseDiveId: dense.first['dive_id'] as String,
    denseSamples: dense.first['n'] as int,
  );
}

List<({String label, String sql, List<Object?> params})> _queries(
  Database db,
  String term,
) {
  final t = _pickTargets(db);
  final like = '%$term%';
  final searchParams = <Object?>[...List.filled(12, like), t.diverId];
  final page = db.select(_summariesSql, [t.diverId]);
  final pageIds = page.map((r) => r['id'] as String).toList();
  final inList = List.filled(pageIds.length, '?').join(',');
  return [
    (
      label: 'profile_fetch_densest (${t.denseSamples} rows)',
      sql:
          'SELECT * FROM dive_profiles WHERE dive_id = ? '
          'ORDER BY timestamp ASC',
      params: [t.denseDiveId],
    ),
    (
      label: 'pressure_fetch_densest',
      sql:
          'SELECT * FROM tank_pressure_profiles WHERE dive_id = ? '
          'ORDER BY timestamp ASC',
      params: [t.denseDiveId],
    ),
    (
      label: 'tanks_fetch',
      sql: 'SELECT * FROM dive_tanks WHERE dive_id = ?',
      params: [t.denseDiveId],
    ),
    (label: 'summaries_page1', sql: _summariesSql, params: [t.diverId]),
    (
      label: 'dive_count',
      sql: 'SELECT COUNT(*) AS count FROM dives d WHERE d.diver_id = ?',
      params: [t.diverId],
    ),
    (
      label: 'search_match_ids (term "$term")',
      sql: _searchSql,
      params: searchParams,
    ),
    (
      label: 'prev_dive',
      sql:
          'SELECT * FROM dives WHERE id != ? AND (entry_time < ? OR '
          '(entry_time IS NULL AND dive_date_time < ?)) '
          'ORDER BY entry_time DESC, dive_date_time DESC LIMIT 1',
      params: [t.denseDiveId, 9999999999999, 9999999999999],
    ),
    (
      label: 'tags_for_page (${pageIds.length} ids)',
      sql: 'SELECT * FROM dive_tags WHERE dive_id IN ($inList)',
      params: pageIds,
    ),
  ];
}

void _bench(Database db, String term, bool asJson) {
  final results = <Map<String, Object>>[];
  for (final q in _queries(db, term)) {
    final times = <int>[];
    var rows = 0;
    for (var i = 0; i < 5; i++) {
      final sw = Stopwatch()..start();
      final rs = db.select(q.sql, q.params);
      sw.stop();
      rows = rs.length;
      times.add(sw.elapsedMicroseconds);
    }
    times.sort();
    results.add({
      'query': q.label,
      'rows': rows,
      'median_ms': times[2] / 1000.0,
      'min_ms': times.first / 1000.0,
    });
  }
  // Approximate searchDives' N+1 hydration: the 3 heavy per-dive queries
  // for the first 20 matched dives (the app runs ~10 per match).
  final matched = db.select(_searchSql, [
    ...List.filled(12, '%$term%'),
    _pickTargets(db).diverId,
  ]);
  final hydrateIds = matched.take(20).map((r) => r['id'] as String).toList();
  // Measure with the same median-of-5 methodology as the per-query loop above
  // so the median_ms/min_ms labels are accurate and comparable, not a single
  // run reported under both keys.
  final hydrateTimes = <int>[];
  for (var i = 0; i < 5; i++) {
    final sw = Stopwatch()..start();
    for (final id in hydrateIds) {
      db.select(
        'SELECT * FROM dive_profiles WHERE dive_id = ? ORDER BY timestamp ASC',
        [id],
      );
      db.select(
        'SELECT * FROM tank_pressure_profiles WHERE dive_id = ? '
        'ORDER BY timestamp ASC',
        [id],
      );
      db.select('SELECT * FROM dive_tanks WHERE dive_id = ?', [id]);
    }
    sw.stop();
    hydrateTimes.add(sw.elapsedMicroseconds);
  }
  hydrateTimes.sort();
  results.add({
    'query': 'search_hydration_first20 (${matched.length} matches total)',
    'rows': hydrateIds.length,
    'median_ms': hydrateTimes[2] / 1000.0,
    'min_ms': hydrateTimes.first / 1000.0,
  });

  if (asJson) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(results));
  } else {
    stdout.writeln(
      '${'query'.padRight(52)}${'rows'.padLeft(9)}${'median ms'.padLeft(12)}',
    );
    for (final r in results) {
      final label = r['query']! as String;
      final rows = '${r['rows']}';
      final median = (r['median_ms']! as double).toStringAsFixed(1);
      stdout.writeln(
        '${label.padRight(52)}${rows.padLeft(9)}${median.padLeft(12)}',
      );
    }
  }
}

void _plans(Database db, String term) {
  for (final q in _queries(db, term)) {
    stdout.writeln('-- ${q.label}');
    final plan = db.select('EXPLAIN QUERY PLAN ${q.sql}', q.params);
    for (final row in plan) {
      stdout.writeln('   ${row['detail']}');
    }
  }
}

void _createIndexes(Database db) {
  final existing = db
      .select("SELECT name FROM sqlite_master WHERE type = 'index'")
      .map((r) => r['name'] as String)
      .toSet();
  final total = Stopwatch()..start();
  var created = 0;
  for (final idx in kPerformanceIndexes) {
    if (existing.contains(idx.name)) {
      stdout.writeln('exists   ${idx.name}');
      continue;
    }
    final sw = Stopwatch()..start();
    db.execute(idx.ddl);
    sw.stop();
    created++;
    stdout.writeln(
      'created  ${idx.name.padRight(44)} ${sw.elapsedMilliseconds} ms',
    );
  }
  if (created > 0) {
    final sw = Stopwatch()..start();
    db.execute('PRAGMA analysis_limit = 400');
    db.execute('ANALYZE');
    sw.stop();
    stdout.writeln('ANALYZE  ${sw.elapsedMilliseconds} ms');
  }
  total.stop();
  stdout.writeln(
    'Done: $created created, total ${total.elapsedMilliseconds} ms',
  );
}
