# Large-DB Performance: Baseline + WS0 (Index Integrity) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Capture a reproducible SQL-level performance baseline against the 1,032-dive database, then make every performance index self-healing so fresh, restored, and sync-adopted databases stop running million-row full scans.

**Architecture:** A pure-Dart canonical index module (`lib/core/database/performance_indexes.dart`) holds every intended index as (name, ddl) records; `AppDatabase.beforeOpen` diffs it against `sqlite_master` and creates only what's missing (then `ANALYZE`), following the codebase's existing beforeOpen re-assert pattern. Two committed pure-Dart tools (`tools/db_bench.dart`, `tools/vmcap.dart`) provide the before/after measurement gates for this and every later workstream.

**Tech Stack:** Flutter 3.x, Drift ORM, `package:sqlite3` ^2.9.4 (direct dependency), dart:developer VM-service protocol.

**Spec:** `docs/superpowers/specs/2026-07-10-large-db-performance-design.md`

## Global Constraints

- Schema version stays at **102** — WS0 uses `beforeOpen` only, no migration block, no version bump.
- `lib/core/database/database.dart` and everything it imports must stay **Flutter-free** (currently imports only `dart:convert` + `package:drift/drift.dart`). Same for `tools/*.dart` (they run via `dart run`).
- No emojis in code, comments, or docs. All code passes `dart format .` with no changes.
- Before every commit: `dart format .` then `flutter analyze` (whole project, never piped through `tail`/`head`).
- Run tests as specific files (`flutter test test/core/database/performance_indexes_test.dart`), never broad directories.
- Performance targets (from spec): search < 500 ms, detail open < 500 ms, chart toggle < 200 ms, startup < 2 s, zero UI-thread DB blocks.
- The live debug DB is `~/Library/Containers/app.submersion/Data/Documents/Submersion/submersion.db` (335 MB, 1,032 dives, 1,077,216 dive_profiles rows, 784,752 tank_pressure_profiles rows). Never benchmark against it directly and never open it while the app is running — always work on `.backup` copies.
- Commit messages: conventional prefixes (`perf:`, `feat:`, `test:`, `docs:`, `chore:`), no Co-Authored-By lines.

---

### Task 1: Canonical index list + db_bench tool + SQL-level baseline capture

The measurement comes first: this task produces the before/after numbers that justify (or resize) everything downstream, without touching app code paths.

**Files:**
- Create: `lib/core/database/performance_indexes.dart` (const list only in this task)
- Create: `tools/db_bench.dart`
- Create: `docs/superpowers/specs/2026-07-10-large-db-performance-findings.md`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `kPerformanceIndexes` — `const List<({String name, String ddl})>` in `package:submersion/core/database/performance_indexes.dart`. Task 3 adds `ensurePerformanceIndexes()` to this same file; Task 4's tests import the list. `tools/db_bench.dart` CLI with modes `bench` / `plans` / `create-indexes`.

- [ ] **Step 1: Write the canonical index list**

Create `lib/core/database/performance_indexes.dart`. The list is every `CREATE INDEX` ever defined in `database.dart` migration blocks, deduped, minus `idx_dive_computer_data_dive_id` (its table was renamed to `dive_data_sources` in the v50-era migration and the index explicitly dropped), plus one new expression index matching the paginated list's real sort key (`getDiveSummaries` sorts by `COALESCE(entry_time, dive_date_time)`; no existing index covers that expression). Keep-or-drop for the new index is decided empirically in Step 6 and Task 4.

```dart
/// Canonical performance-index set for the Submersion database.
///
/// Historically these indexes were created only inside onUpgrade migration
/// blocks, so a database created fresh at a recent schema version -- or
/// arriving via restore or sync-adopt -- never got them and every child-table
/// lookup degraded to a full table scan (issue: large-DB performance,
/// docs/superpowers/specs/2026-07-10-large-db-performance-design.md).
///
/// This list is asserted idempotently on every open from
/// AppDatabase.beforeOpen. Keep it in sync: any migration that adds a
/// performance index must also add it here (the fresh-DB test in
/// test/core/database/performance_indexes_test.dart fails if the DDL
/// references a table missing from the current schema).
///
/// This file must stay Flutter-free: it is imported by tools/db_bench.dart,
/// which runs on the plain Dart VM.
library;

typedef PerformanceIndex = ({String name, String ddl});

const List<PerformanceIndex> kPerformanceIndexes = [
  // -- dives ----------------------------------------------------------------
  (
    name: 'idx_dives_diver_datetime',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_dives_diver_datetime '
        'ON dives(diver_id, dive_date_time DESC)',
  ),
  (
    name: 'idx_dives_diver_entrytime',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_dives_diver_entrytime '
        'ON dives(diver_id, entry_time DESC)',
  ),
  (
    name: 'idx_dives_diver_exittime',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_dives_diver_exittime '
        'ON dives(diver_id, exit_time DESC)',
  ),
  // Matches the paginated dive list's ORDER BY expression exactly
  // (dive_repository_impl.dart getDiveSummaries: sort_timestamp =
  // COALESCE(entry_time, dive_date_time)). Empirically validated in the
  // WS0 baseline; remove if EXPLAIN QUERY PLAN never selects it.
  (
    name: 'idx_dives_diver_sort_timestamp',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_dives_diver_sort_timestamp '
        'ON dives(diver_id, COALESCE(entry_time, dive_date_time) DESC)',
  ),
  (
    name: 'idx_dives_site_id',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_dives_site_id ON dives(site_id)',
  ),
  (
    name: 'idx_dives_trip_id',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_dives_trip_id ON dives(trip_id)',
  ),
  (
    name: 'idx_dives_dive_center_id',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_dives_dive_center_id '
        'ON dives(dive_center_id)',
  ),
  (
    name: 'idx_dives_course_id',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_dives_course_id ON dives(course_id)',
  ),
  (
    name: 'idx_dives_favorite',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_dives_favorite '
        'ON dives(diver_id, is_favorite)',
  ),
  // -- per-dive child tables (the million-row scans) ------------------------
  (
    name: 'idx_dive_profiles_dive_id',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_dive_profiles_dive_id '
        'ON dive_profiles(dive_id)',
  ),
  (
    name: 'idx_tank_pressure_dive_tank',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_tank_pressure_dive_tank '
        'ON tank_pressure_profiles(dive_id, tank_id, timestamp)',
  ),
  (
    name: 'idx_dive_tanks_dive_id',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_dive_tanks_dive_id '
        'ON dive_tanks(dive_id)',
  ),
  (
    name: 'idx_dive_equipment_dive_id',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_dive_equipment_dive_id '
        'ON dive_equipment(dive_id)',
  ),
  (
    name: 'idx_dive_weights_dive_id',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_dive_weights_dive_id '
        'ON dive_weights(dive_id)',
  ),
  (
    name: 'idx_dive_tags_dive_id',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_dive_tags_dive_id '
        'ON dive_tags(dive_id)',
  ),
  (
    name: 'idx_dive_tags_tag_id',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_dive_tags_tag_id '
        'ON dive_tags(tag_id)',
  ),
  (
    name: 'idx_dive_buddies_dive_id',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_dive_buddies_dive_id '
        'ON dive_buddies(dive_id)',
  ),
  (
    name: 'idx_dive_custom_fields_dive_id',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_dive_custom_fields_dive_id '
        'ON dive_custom_fields(dive_id)',
  ),
  (
    name: 'idx_dive_custom_fields_key',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_dive_custom_fields_key '
        'ON dive_custom_fields(field_key)',
  ),
  (
    name: 'idx_dive_data_sources_dive_id',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_dive_data_sources_dive_id '
        'ON dive_data_sources(dive_id)',
  ),
  (
    name: 'idx_tide_records_dive',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_tide_records_dive '
        'ON tide_records(dive_id)',
  ),
  // -- sync ------------------------------------------------------------------
  (
    name: 'idx_sync_records_entity_record',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_sync_records_entity_record '
        'ON sync_records(entity_type, record_id)',
  ),
  // -- reference / feature tables --------------------------------------------
  (
    name: 'idx_site_species_site',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_site_species_site '
        'ON site_species(site_id)',
  ),
  (
    name: 'idx_courses_diver',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_courses_diver ON courses(diver_id)',
  ),
  (
    name: 'idx_media_platform_asset_id',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_media_platform_asset_id '
        'ON media(platform_asset_id)',
  ),
  (
    name: 'idx_media_enrichment_media',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_media_enrichment_media '
        'ON media_enrichment(media_id)',
  ),
  (
    name: 'idx_media_enrichment_dive',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_media_enrichment_dive '
        'ON media_enrichment(dive_id)',
  ),
  (
    name: 'idx_media_species_media',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_media_species_media '
        'ON media_species(media_id)',
  ),
  (
    name: 'idx_media_species_species',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_media_species_species '
        'ON media_species(species_id)',
  ),
  (
    name: 'idx_pending_photo_suggestions_dive',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_pending_photo_suggestions_dive '
        'ON pending_photo_suggestions(dive_id)',
  ),
  (
    name: 'idx_scheduled_notifications_equipment',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_scheduled_notifications_equipment '
        'ON scheduled_notifications(equipment_id)',
  ),
  (
    name: 'idx_view_configs_diver',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_view_configs_diver '
        'ON view_configs(diver_id, view_mode)',
  ),
  (
    name: 'idx_field_presets_diver',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_field_presets_diver '
        'ON field_presets(diver_id, view_mode)',
  ),
  (
    name: 'idx_media_source_type',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_media_source_type '
        'ON media(source_type)',
  ),
  (
    name: 'idx_media_connector_account',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_media_connector_account '
        'ON media(connector_account_id)',
  ),
  (
    name: 'idx_media_origin_device',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_media_origin_device '
        'ON media(origin_device_id)',
  ),
  (
    name: 'idx_checklist_template_items_template_id',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_checklist_template_items_template_id '
        'ON checklist_template_items(template_id)',
  ),
  (
    name: 'idx_trip_checklist_items_trip_id',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_trip_checklist_items_trip_id '
        'ON trip_checklist_items(trip_id)',
  ),
  (
    name: 'idx_dive_plan_tanks_plan_id',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_dive_plan_tanks_plan_id '
        'ON dive_plan_tanks(plan_id)',
  ),
  (
    name: 'idx_dive_plan_segments_plan_id',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_dive_plan_segments_plan_id '
        'ON dive_plan_segments(plan_id)',
  ),
  (
    name: 'idx_gps_track_points_local_track_id',
    ddl: 'CREATE INDEX IF NOT EXISTS idx_gps_track_points_local_track_id '
        'ON gps_track_points_local(track_id)',
  ),
];
```

- [ ] **Step 2: Write tools/db_bench.dart**

Pure Dart CLI. Opens a database copy with `package:sqlite3`, discovers the busiest diver and densest dive from the data, then times the app's real hot-query shapes (SQL copied from `dive_repository_impl.dart`). Three modes: `bench` (median-of-5 timings), `plans` (EXPLAIN QUERY PLAN dump), `create-indexes` (applies `kPerformanceIndexes`, timing each build).

```dart
import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:submersion/core/database/performance_indexes.dart';

/// SQL-level benchmark harness for the large-DB performance program.
///
/// Runs the app's real hot-query shapes against a database COPY (never the
/// live file). Usage:
///
///   dart run tools/db_bench.dart bench <db-path> [--json] [--term blue]
///   dart run tools/db_bench.dart plans <db-path>
///   dart run tools/db_bench.dart create-indexes <db-path>
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
    (
      label: 'summaries_page1',
      sql: _summariesSql,
      params: [t.diverId],
    ),
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
  results.add({
    'query': 'search_hydration_first20 (${matched.length} matches total)',
    'rows': hydrateIds.length,
    'median_ms': sw.elapsedMilliseconds.toDouble(),
    'min_ms': sw.elapsedMilliseconds.toDouble(),
  });

  if (asJson) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(results));
  } else {
    stdout.writeln(
      'query'.padRight(52) + 'rows'.padLeft(9) + 'median ms'.padLeft(12),
    );
    for (final r in results) {
      stdout.writeln(
        (r['query']! as String).padRight(52) +
            '${r['rows']}'.padLeft(9) +
            (r['median_ms']! as double).toStringAsFixed(1).padLeft(12),
      );
    }
  }
}

void _plans(Database db, String term) {
  for (final q in _queries(db, term)) {
    stdout.writeln('-- ${q.label}');
    final plan = db.select(
      'EXPLAIN QUERY PLAN ${q.sql}',
      q.params,
    );
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
```

- [ ] **Step 3: Verify the tool compiles and is format-clean**

Run: `dart format lib/core/database/performance_indexes.dart tools/db_bench.dart && flutter analyze`
Expected: format reports no changes needed (or fix and re-run); analyze reports `No issues found!`

- [ ] **Step 4: Create the pristine fixture (app must be CLOSED)**

Run:
```bash
mkdir -p ~/SubmersionBench
sqlite3 ~/Library/Containers/app.submersion/Data/Documents/Submersion/submersion.db ".backup '$HOME/SubmersionBench/pristine-20260710.db'"
cp ~/SubmersionBench/pristine-20260710.db ~/SubmersionBench/work.db
ls -lh ~/SubmersionBench/
```
Expected: two ~335 MB files. `.backup` produces a consistent snapshot even for a WAL database. The pristine copy is never modified again — it lets any future workstream re-measure the true "before" state.

- [ ] **Step 5: Capture BEFORE numbers and plans**

Run:
```bash
dart run tools/db_bench.dart bench ~/SubmersionBench/work.db
dart run tools/db_bench.dart plans ~/SubmersionBench/work.db
```
Expected: bench prints the timing table (profile_fetch_densest should be tens of ms — it is a 1.08M-row scan; search_hydration_first20 likely seconds). Plans show `SCAN dive_profiles`, `SCAN tank_pressure_profiles`, `SCAN dives` etc. Save both outputs.

- [ ] **Step 6: Apply indexes to the working copy, capture build cost and AFTER numbers**

Run:
```bash
dart run tools/db_bench.dart create-indexes ~/SubmersionBench/work.db
dart run tools/db_bench.dart bench ~/SubmersionBench/work.db
dart run tools/db_bench.dart plans ~/SubmersionBench/work.db
```
Expected: per-index build times plus total (this number is the one-time first-open stall users will pay; if total exceeds ~10 s, flag it at the Task 5 checkpoint — the spec then calls for progress UI). AFTER bench should show the per-dive fetches dropping from tens of ms to sub-ms; plans show `SEARCH ... USING INDEX idx_...`. Note specifically whether `summaries_page1` uses `idx_dives_diver_sort_timestamp` — this is the expression index's empirical keep/drop evidence for Task 4.

- [ ] **Step 7: Write the findings doc**

Create `docs/superpowers/specs/2026-07-10-large-db-performance-findings.md` with the structure below, filling in the real numbers from Steps 5-6:

```markdown
# Large-DB Performance Findings (Phase 3)

Fixture: pristine-20260710.db -- 1,032 dives / 1,077,216 dive_profiles rows /
784,752 tank_pressure_profiles rows / 34 multi-computer dives / 335 MB.
Machine: <fill in from `sysctl -n machdep.cpu.brand_string` or Apple chip name>.
Tool: tools/db_bench.dart (median of 5).

## WS0 SQL-level A/B (same fixture, before vs after kPerformanceIndexes)

| Query | Rows | Before (ms) | After (ms) |
|---|---|---|---|
| profile_fetch_densest | <n> | <ms> | <ms> |
| pressure_fetch_densest | <n> | <ms> | <ms> |
| tanks_fetch | <n> | <ms> | <ms> |
| summaries_page1 | 50 | <ms> | <ms> |
| dive_count | 1 | <ms> | <ms> |
| search_match_ids | <n> | <ms> | <ms> |
| prev_dive | 1 | <ms> | <ms> |
| tags_for_page | <n> | <ms> | <ms> |
| search_hydration_first20 | 20 | <ms> | <ms> |

Index build cost (one-time first-open stall): <total> ms total; slowest
single index <name> at <ms> ms. ANALYZE: <ms> ms.

## Query plan evidence

Before: <paste the SCAN lines for the hot queries>
After: <paste the USING INDEX lines>

## Decision log

- Expression index idx_dives_diver_sort_timestamp: <used / not used> by
  summaries_page1 -> <kept / dropped>.
- <anything unexpected>

## In-app verification (filled in at Task 5)

- Live DB healed on first open: <index count before/after>
- beforeOpen ensure cost on already-healed DB: <ms>
- Subjective: <search / detail-open / scroll notes>
```

(The template placeholders above are filled with measured values in THIS step — the committed file must contain real numbers for everything except the "In-app verification" section, which Task 5 fills.)

- [ ] **Step 8: Commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
dart format . && flutter analyze
git add lib/core/database/performance_indexes.dart tools/db_bench.dart docs/superpowers/specs/2026-07-10-large-db-performance-findings.md
git commit -m "perf(db): canonical index list, db_bench tool, WS0 SQL baseline"
```

---

### Task 2: vmcap VM-service profiler tool + measurement runbook

The June-era vmcap tool lived only in a session scratchpad and is lost; this recreates it as a committed tool so UI-level measurement is reproducible for the whole program (post-WS0 re-baseline, then WS1-WS5 gates).

**Files:**
- Create: `tools/vmcap.dart`
- Create: `docs/superpowers/specs/2026-07-10-large-db-performance-baseline-runbook.md`

**Interfaces:**
- Consumes: nothing.
- Produces: `dart run tools/vmcap.dart <ws-uri> <probe|clear|read|frames> [seconds]` CLI used by the runbook and all later workstream gates.

- [ ] **Step 1: Write tools/vmcap.dart**

Pure Dart (dart:io WebSocket, no package deps). JSON-RPC 2.0 against the Flutter VM service. Modes: `probe` (list isolates), `clear` (enable profiler + clear CPU samples — MUST be called right before the interaction window, or the profiler's own JSON serialization dominates the samples), `read` (aggregate CPU samples by function, top 30 self/inclusive), `frames N` (subscribe to Extension stream for N seconds and report Flutter.Frame events — note: the frame buffer REPLAYS on subscribe, so only events with a timestamp after subscribe-time are counted).

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Minimal VM-service CPU/frame capture for user-paced profiling.
///
/// Usage:
///   flutter run --profile -d macos   # note the ws://127.0.0.1:PORT/TOKEN=/ws URI
///   dart run tools/vmcap.dart <ws-uri> probe
///   dart run tools/vmcap.dart <ws-uri> clear     # right BEFORE interacting
///   <interact with the app>
///   dart run tools/vmcap.dart <ws-uri> read      # right AFTER interacting
///   dart run tools/vmcap.dart <ws-uri> frames 10 # frame events for 10 s
///
/// Gotchas (learned in the June 2026 Phase 1 effort):
/// - Always `clear` immediately before the window; otherwise the VM service's
///   own serialization functions dominate the profile.
/// - `frames` counts only events timestamped after subscribe, because the VM
///   replays the historical frame buffer to new subscribers.
Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln(
      'Usage: dart run tools/vmcap.dart <ws-uri> <probe|clear|read|frames> '
      '[seconds]',
    );
    exit(64);
  }
  final uri = args[0];
  final mode = args[1];
  final seconds = args.length > 2 ? int.parse(args[2]) : 10;

  final ws = await WebSocket.connect(uri);
  final client = _RpcClient(ws);
  try {
    final vm = await client.call('getVM');
    final isolates = (vm['isolates'] as List).cast<Map<String, dynamic>>();
    if (isolates.isEmpty) {
      stderr.writeln('No isolates.');
      exit(1);
    }
    final main = isolates.first['id'] as String;

    switch (mode) {
      case 'probe':
        for (final iso in isolates) {
          stdout.writeln('${iso['id']}  ${iso['name']}');
        }
      case 'clear':
        await client.call('setFlag', {'name': 'profiler', 'value': 'true'});
        await client.call('clearCpuSamples', {'isolateId': main});
        stdout.writeln('Profiler on, samples cleared. Interact now.');
      case 'read':
        final samples = await client.call('getCpuSamples', {
          'isolateId': main,
          'timeOriginMicros': 0,
          'timeExtentMicros': 0x7fffffffffffffff,
        });
        _report(samples);
      case 'frames':
        await _frames(client, seconds);
      default:
        stderr.writeln('Unknown mode: $mode');
        exit(64);
    }
  } finally {
    await ws.close();
  }
}

void _report(Map<String, dynamic> samples) {
  final functions = (samples['functions'] as List? ?? [])
      .cast<Map<String, dynamic>>();
  String nameOf(int i) {
    final f = functions[i]['function'] as Map<String, dynamic>?;
    return (f?['name'] as String?) ?? '<unknown>';
  }

  final self = <int, int>{};
  final incl = <int, int>{};
  final sampleList = (samples['samples'] as List? ?? [])
      .cast<Map<String, dynamic>>();
  for (final s in sampleList) {
    final stack = (s['stack'] as List).cast<int>();
    if (stack.isEmpty) continue;
    self[stack.first] = (self[stack.first] ?? 0) + 1;
    for (final f in stack.toSet()) {
      incl[f] = (incl[f] ?? 0) + 1;
    }
  }
  final total = sampleList.length;
  stdout.writeln('Samples: $total over '
      '${samples['timeExtentMicros']} us window');
  final top = self.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  stdout.writeln('\n-- top self --');
  for (final e in top.take(30)) {
    final pct = (e.value * 100 / total).toStringAsFixed(1);
    stdout.writeln('${'$pct%'.padLeft(7)}  ${nameOf(e.key)}');
  }
  final topIncl = incl.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  stdout.writeln('\n-- top inclusive --');
  for (final e in topIncl.take(30)) {
    final pct = (e.value * 100 / total).toStringAsFixed(1);
    stdout.writeln('${'$pct%'.padLeft(7)}  ${nameOf(e.key)}');
  }
}

Future<void> _frames(_RpcClient client, int seconds) async {
  final subscribedAt = DateTime.now().microsecondsSinceEpoch;
  var count = 0, slow = 0;
  client.onEvent = (event) {
    if (event['extensionKind'] != 'Flutter.Frame') return;
    final data = event['extensionData'] as Map<String, dynamic>;
    final ts = event['timestamp'] as int? ?? 0;
    if (ts * 1000 < subscribedAt) return; // replayed history
    count++;
    final elapsed = (data['elapsed'] as num).toInt();
    if (elapsed > 16667) slow++;
  };
  await client.call('streamListen', {'streamId': 'Extension'});
  stdout.writeln('Capturing frames for $seconds s. Interact now.');
  await Future<void>.delayed(Duration(seconds: seconds));
  stdout.writeln('Frames: $count, over-16.7ms: $slow');
}

class _RpcClient {
  _RpcClient(this._ws) {
    _ws.listen((raw) {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      if (msg.containsKey('id')) {
        final completer = _pending.remove(msg['id']);
        if (msg.containsKey('error')) {
          completer?.completeError(StateError(jsonEncode(msg['error'])));
        } else {
          completer?.complete(msg['result'] as Map<String, dynamic>);
        }
      } else if (msg['method'] == 'streamNotify') {
        final event =
            (msg['params'] as Map<String, dynamic>)['event']
                as Map<String, dynamic>;
        onEvent?.call(event);
      }
    });
  }

  final WebSocket _ws;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  int _nextId = 1;
  void Function(Map<String, dynamic> event)? onEvent;

  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, dynamic>? params,
  ]) {
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _ws.add(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        if (params != null) 'params': params,
      }),
    );
    return completer.future;
  }
}
```

- [ ] **Step 2: Smoke-test the tool**

Run: `dart run tools/vmcap.dart ws://127.0.0.1:1/ws probe 2>&1 | head -3; echo "exit: $?"`
Expected: a socket connection error (nothing is listening on port 1) and a NON-zero exit — proves the tool compiles and reaches the connect call. Then `dart format tools/vmcap.dart && flutter analyze` — no changes, no issues.

- [ ] **Step 3: Write the runbook**

Create `docs/superpowers/specs/2026-07-10-large-db-performance-baseline-runbook.md`:

```markdown
# Large-DB Performance Measurement Runbook (Phase 3)

Applies to every workstream gate in the Phase 3 program. Two layers:

## Layer 1: SQL-level (automated, per-PR)

1. App CLOSED. Fixture (already created once):
   sqlite3 <live-db> ".backup '$HOME/SubmersionBench/pristine-20260710.db'"
   Live DB: ~/Library/Containers/app.submersion/Data/Documents/Submersion/submersion.db
2. Fresh working copy: cp ~/SubmersionBench/pristine-20260710.db ~/SubmersionBench/work.db
3. Before: dart run tools/db_bench.dart bench ~/SubmersionBench/work.db
4. Apply the change under test (for WS0: dart run tools/db_bench.dart
   create-indexes ~/SubmersionBench/work.db).
5. After: dart run tools/db_bench.dart bench ~/SubmersionBench/work.db
6. Plans: dart run tools/db_bench.dart plans ~/SubmersionBench/work.db
7. Record medians + plans in the findings doc.

CAUTION: after WS0 ships, opening ANY copy with the app (or any AppDatabase)
heals its indexes -- for a true "before", always start from the pristine file.

## Layer 2: UI-level (user-paced, per-workstream re-baseline)

Launch: flutter run --profile -d macos
(debug builds overstate costs; profile mode is the honest one)
Copy the VM service ws:// URI from the launch output.

The five anchor scenarios (record wall time + vmcap output for each):

1. Cold start: quit app; time launch -> dashboard interactive (stopwatch);
   then vmcap read for startup CPU attribution.
2. Search: vmcap clear -> type a term matching many dives in dive search ->
   results visible -> vmcap read. Record wall time to results.
3. Detail open x3: densest single-computer dive, a 2-computer dive, a dive
   at the end of a dense repetitive week. vmcap clear before each tap,
   vmcap read when the page settles.
4. Chart toggles: on the dense technical dive -- ceiling calculated <->
   computer, one overlay on/off. vmcap frames 10 while toggling.
5. List stress: table view mode on, then a fast scroll through the paginated
   card list. vmcap frames 10.

Record everything in 2026-07-10-large-db-performance-findings.md with date
and commit hash.
```

- [ ] **Step 4: Commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
dart format . && flutter analyze
git add tools/vmcap.dart docs/superpowers/specs/2026-07-10-large-db-performance-baseline-runbook.md
git commit -m "perf: vmcap VM-service profiler tool and measurement runbook"
```

---

### Task 3: ensurePerformanceIndexes + beforeOpen wiring (TDD)

**Files:**
- Modify: `lib/core/database/performance_indexes.dart` (add the ensure function)
- Modify: `lib/core/database/database.dart:4983-5037` (beforeOpen) and `:1` (imports)
- Test: `test/core/database/performance_indexes_test.dart`

**Interfaces:**
- Consumes: `kPerformanceIndexes` from Task 1.
- Produces: `Future<List<String>> ensurePerformanceIndexes(GeneratedDatabase db)` — returns the names of indexes actually created (empty list when everything already exists). Task 4's tests and any future migration code rely on this exact signature.

- [ ] **Step 1: Write the failing tests**

Create `test/core/database/performance_indexes_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/performance_indexes.dart';

Future<Set<String>> indexNames(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  test('fresh database has every canonical performance index', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // Force open so onCreate + beforeOpen run.
    await db.customSelect('SELECT 1').get();

    final names = await indexNames(db);
    for (final idx in kPerformanceIndexes) {
      expect(names, contains(idx.name), reason: '${idx.name} missing');
    }
  });

  test('ensurePerformanceIndexes is idempotent', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    final created = await ensurePerformanceIndexes(db);
    expect(created, isEmpty);
  });

  test('ensurePerformanceIndexes heals a dropped index', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    await db.customStatement('DROP INDEX idx_dive_profiles_dive_id');
    expect(await indexNames(db), isNot(contains('idx_dive_profiles_dive_id')));

    final created = await ensurePerformanceIndexes(db);
    expect(created, equals(['idx_dive_profiles_dive_id']));
    expect(await indexNames(db), contains('idx_dive_profiles_dive_id'));
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/database/performance_indexes_test.dart`
Expected: FAIL — first test's `expect(names, contains(...))` fails (fresh DB has no canonical indexes yet); second and third fail to compile-or-run only if `ensurePerformanceIndexes` is missing — the suite must be red for the right reason: the function does not exist yet, so this is a compile error mentioning `ensurePerformanceIndexes`. That counts as the failing state.

- [ ] **Step 3: Implement ensurePerformanceIndexes**

Append to `lib/core/database/performance_indexes.dart` (add the drift import at the top of the file, below the library doc comment):

```dart
import 'package:drift/drift.dart';
```

and at the end of the file:

```dart
/// Creates any canonical index missing from [db], returning the names of
/// indexes actually created (empty when the database was already healed).
///
/// Runs ANALYZE (bounded by analysis_limit) only when something was created,
/// so the query planner picks up the new indexes; every later open is a
/// single sqlite_master read.
Future<List<String>> ensurePerformanceIndexes(GeneratedDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
      .get();
  final existing = rows.map((r) => r.read<String>('name')).toSet();

  final created = <String>[];
  for (final index in kPerformanceIndexes) {
    if (existing.contains(index.name)) continue;
    await db.customStatement(index.ddl);
    created.add(index.name);
  }
  if (created.isNotEmpty) {
    await db.customStatement('PRAGMA analysis_limit = 400');
    await db.customStatement('ANALYZE');
  }
  return created;
}
```

- [ ] **Step 4: Wire into beforeOpen**

In `lib/core/database/database.dart`, update the import block at the top of the file (it currently imports only `dart:convert` and `package:drift/drift.dart`; keep it Flutter-free) so it becomes:

```dart
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:drift/drift.dart';

import 'performance_indexes.dart';
```

Then in `beforeOpen` (currently ending at the `idx_dive_plan_segments_plan_id` customStatement around line 5036), append AFTER the dive-plan index re-asserts and BEFORE the closing `},`:

```dart
        // Performance indexes historically existed only in onUpgrade blocks,
        // so a database created fresh at a recent schema version -- or
        // arriving via restore or sync-adopt -- never got them, and per-dive
        // child lookups degraded to full scans of million-row tables.
        // Re-assert the canonical set on every open (IF NOT EXISTS: free
        // after the first heal). ANALYZE runs inside only when something was
        // actually created.
        final createdIndexes = await ensurePerformanceIndexes(this);
        assert(() {
          if (createdIndexes.isNotEmpty) {
            developer.log(
              'Healed ${createdIndexes.length} performance indexes: '
              '${createdIndexes.join(', ')}',
              name: 'AppDatabase',
            );
          }
          return true;
        }());
```

(The `assert(() {...}())` pattern gives debug-only logging without importing Flutter's `kDebugMode` into this deliberately Flutter-free file. `developer.log` is `dart:developer`, pure SDK. No `onCreate` change is needed: `beforeOpen` runs after `onCreate` on the very first open, so fresh databases are covered by the same single wiring point.)

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/core/database/performance_indexes_test.dart`
Expected: 3 tests PASS. If the fresh-DB test fails with "no such table", the canonical list references a table that no longer exists in the current schema — fix the list, do not skip the test (this failure mode is exactly what the test exists to catch).

- [ ] **Step 6: Run the neighboring DB test files to catch regressions**

Run: `flutter test test/core/database/migration_v86_test.dart test/core/database/migration_v85_test.dart test/core/database/migration_v58_test.dart`
Expected: PASS (beforeOpen now does more work, but all DDL is idempotent; these tests open old-schema fixtures through the full ladder).

- [ ] **Step 7: Commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
dart format . && flutter analyze
git add lib/core/database/performance_indexes.dart lib/core/database/database.dart test/core/database/performance_indexes_test.dart
git commit -m "perf(db): self-heal performance indexes in beforeOpen"
```

---

### Task 4: Query-plan regression tests (+ expression-index verdict)

Query-plan assertions are CI-stable where timing assertions are not: they pin the *mechanism* (index used) rather than the *speed*.

**Files:**
- Test: `test/core/database/query_plan_test.dart`
- Possibly modify: `lib/core/database/performance_indexes.dart` (drop the expression index if the verdict is negative)

**Interfaces:**
- Consumes: `kPerformanceIndexes`, `AppDatabase` (fresh in-memory, healed by beforeOpen from Task 3).
- Produces: nothing new — a regression net.

- [ ] **Step 1: Write the query-plan tests**

Create `test/core/database/query_plan_test.dart`. The summaries SQL is the page-1 shape from `DiveRepository.getDiveSummaries` (`dive_repository_impl.dart:1511`); keep the two in sync when that query changes.

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Returns the concatenated EXPLAIN QUERY PLAN detail lines for [sql].
Future<String> plan(AppDatabase db, String sql) async {
  final rows = await db.customSelect('EXPLAIN QUERY PLAN $sql').get();
  return rows.map((r) => r.read<String>('detail')).join('\n');
}

const _summariesPage1Sql =
    "SELECT d.id, COALESCE(d.entry_time, d.dive_date_time) AS sort_timestamp "
    "FROM dives d LEFT JOIN dive_sites s ON d.site_id = s.id "
    "WHERE d.diver_id = 'x' "
    "ORDER BY sort_timestamp DESC, COALESCE(d.dive_number, 0) DESC, d.id DESC "
    "LIMIT 50";

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get(); // open: onCreate + beforeOpen
  });

  tearDown(() => db.close());

  test('per-dive profile fetch uses idx_dive_profiles_dive_id', () async {
    final p = await plan(
      db,
      "SELECT * FROM dive_profiles WHERE dive_id = 'x' ORDER BY timestamp",
    );
    expect(p, contains('idx_dive_profiles_dive_id'));
  });

  test('per-dive pressure fetch uses idx_tank_pressure_dive_tank', () async {
    final p = await plan(
      db,
      "SELECT * FROM tank_pressure_profiles WHERE dive_id = 'x' "
      'ORDER BY timestamp',
    );
    expect(p, contains('idx_tank_pressure_dive_tank'));
  });

  test('per-dive tanks fetch uses idx_dive_tanks_dive_id', () async {
    final p = await plan(db, "SELECT * FROM dive_tanks WHERE dive_id = 'x'");
    expect(p, contains('idx_dive_tanks_dive_id'));
  });

  test('paginated summaries page 1 does not scan dives', () async {
    final p = await plan(db, _summariesPage1Sql);
    expect(p, isNot(contains('SCAN dives')));
    expect(p, contains('USING INDEX'));
  });

  test('per-dive data sources fetch uses idx_dive_data_sources_dive_id',
      () async {
    final p = await plan(
      db,
      "SELECT * FROM dive_data_sources WHERE dive_id = 'x'",
    );
    expect(p, contains('idx_dive_data_sources_dive_id'));
  });
}
```

- [ ] **Step 2: Run the tests**

Run: `flutter test test/core/database/query_plan_test.dart`
Expected: PASS. (These go green immediately because Task 3 already landed — they are the regression net that keeps it green forever, including on fresh schemas where the old onUpgrade-only bug would silently return.)

- [ ] **Step 3: Expression-index verdict**

Combine two pieces of evidence: (a) Task 1 Step 6 — did the fixture's `summaries_page1` plan select `idx_dives_diver_sort_timestamp`? (b) this task's `paginated summaries` test plan output (print it with `debugPrint(p)` temporarily if needed).

- If the planner uses the expression index in either place: keep it; done.
- If the planner never selects it (it may prefer `idx_dives_diver_datetime` for the WHERE and sort separately): remove the `idx_dives_diver_sort_timestamp` entry from `kPerformanceIndexes`, re-run both test files from Tasks 3-4 (expected: still green — no test names it), and record the drop with the plan text as evidence in the findings doc Decision log.

- [ ] **Step 4: Commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
dart format . && flutter analyze
git add test/core/database/query_plan_test.dart lib/core/database/performance_indexes.dart docs/superpowers/specs/2026-07-10-large-db-performance-findings.md
git commit -m "test(db): query-plan regression tests for performance indexes"
```

---

### Task 5: In-app verification on the live DB (USER CHECKPOINT)

This task needs Eric at the keyboard: it heals his real 335 MB database and captures the UI-level re-baseline that prioritizes WS1+.

**Files:**
- Modify: `docs/superpowers/specs/2026-07-10-large-db-performance-findings.md` (fill "In-app verification" + post-WS0 UI re-baseline)

**Interfaces:**
- Consumes: everything above.
- Produces: the re-baseline data that decides WS1/WS2/WS3 ordering (the spec's "Re-baseline after WS0" gate).

- [ ] **Step 1: Pre-flight — report the expected one-time stall**

From Task 1 Step 6, the measured total index-build time on the fixture is the stall the first open will pay. State it to the user before they launch. If it exceeded ~10 s, STOP and ask whether to add progress reporting to the startup path before proceeding (spec risk item; out of scope for this plan unless triggered).

- [ ] **Step 2: Record live-DB index count before healing**

Run (app closed):
```bash
sqlite3 -readonly ~/Library/Containers/app.submersion/Data/Documents/Submersion/submersion.db "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_autoindex%';"
```
Expected: 6 (the pre-WS0 state).

- [ ] **Step 3: User launches the app once**

Ask Eric to run `flutter run -d macos` (debug is fine for the heal; the timing of interest was already measured on the fixture) and quit after the dashboard loads. Watch the console for the `Healed N performance indexes` developer.log line.

- [ ] **Step 4: Verify the heal and the steady state**

Run (app closed again):
```bash
sqlite3 -readonly ~/Library/Containers/app.submersion/Data/Documents/Submersion/submersion.db "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_autoindex%';"
sqlite3 -readonly ~/Library/Containers/app.submersion/Data/Documents/Submersion/submersion.db "EXPLAIN QUERY PLAN SELECT * FROM dive_profiles WHERE dive_id='x';"
```
Expected: count equals the canonical list size (40 or 41 depending on the Task 4 verdict, plus any pre-existing extras); the plan line says `SEARCH dive_profiles USING INDEX idx_dive_profiles_dive_id`. Then ask Eric to launch once more — console should show NO heal line (already healed; steady-state cost is one sqlite_master read).

- [ ] **Step 5: UI-level re-baseline (runbook Layer 2, with Eric)**

Run the five runbook scenarios in `--profile` mode with vmcap. Record wall times and top-CPU attributions into the findings doc. This is the program's decision data: expect search and detail-open to improve but NOT to targets (the N+1 hydration, double profile read, lookback chains, and undecimated chart are untouched) — the attribution tells us which of WS1/WS2/WS3 now dominates.

- [ ] **Step 6: Update findings + memory of record, commit**

Fill the "In-app verification" section and a "Post-WS0 UI re-baseline" section in the findings doc; note the recommended next workstream order with one sentence of evidence each.

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
git add docs/superpowers/specs/2026-07-10-large-db-performance-findings.md
git commit -m "docs: WS0 in-app verification and post-WS0 UI re-baseline"
```

---

### Task 6: Final verification sweep

**Files:** none new.

- [ ] **Step 1: Whole-project format and analyze**

Run: `dart format . && flutter analyze`
Expected: no formatting changes, `No issues found!` (never pipe analyze through tail).

- [ ] **Step 2: Run the touched test surface**

Run: `flutter test test/core/database/performance_indexes_test.dart test/core/database/query_plan_test.dart test/core/database/migration_v86_test.dart test/core/database/migration_v85_test.dart test/core/database/migration_v58_test.dart`
Expected: all PASS.

- [ ] **Step 3: Commit anything the sweep changed; otherwise confirm clean**

Run: `git status --short`
Expected: clean (or a final `chore:` commit for stragglers). The branch is then ready for the finishing-a-development-branch flow (PR to main with the findings table in the description).
