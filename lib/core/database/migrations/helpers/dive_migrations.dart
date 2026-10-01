part of '../app_database_migrations.dart';

/// Dives, dive tanks and the values derived from a dive.
extension DiveMigrations on AppDatabase {
  /// Idempotent DDL for dive_tanks.source_tank_index (v200, issue #1314).
  Future<void> _assertDiveTankSourceIndexColumn() async {
    final cols = await customSelect("PRAGMA table_info('dive_tanks')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.contains('source_tank_index')) return;
    await customStatement(
      'ALTER TABLE dive_tanks ADD COLUMN source_tank_index INTEGER',
    );
  }

  /// v210: gives `dive_tanks.equipment_id` the ON DELETE SET NULL action.
  ///
  /// The column carried a NO ACTION reference from the initial schema. It sat
  /// unused until the transmitter registry began writing it, after which
  /// deleting a linked gear item (locally, or from a peer's tombstone) failed
  /// with a foreign key error. Every other nullable link to equipment already
  /// sets null.
  ///
  /// SQLite cannot alter a constraint in place, so this rebuilds the table:
  /// it rewrites only the equipment_id clause of the table's STORED
  /// definition, which carries every column later rungs added, copies the
  /// rows across, and recreates the table's indexes. No column list is
  /// written out, so a column this code has never heard of survives too.
  ///
  /// Foreign keys must be off for the swap: with them on, the DROP deletes
  /// every row first and cascades into the tables that hang off the tanks.
  /// onUpgrade and the top of beforeOpen run before enforcement is switched
  /// on, but this switches it off itself, and refuses rather than risk the
  /// cascade if it cannot. The swap runs in one transaction so a crash can
  /// never leave the table dropped.
  ///
  /// Idempotent: a table whose link already sets null, or that has no
  /// equipment reference at all (minimal fixtures), is left untouched, so a
  /// steady-state open costs one PRAGMA. Called from the v210 onUpgrade block
  /// and the beforeOpen backstop.
  Future<void> _assertDiveTankEquipmentSetNull() async {
    final links = await customSelect(
      "PRAGMA foreign_key_list('dive_tanks')",
    ).get();
    final equipmentLink = links.where(
      (r) => r.read<String>('from') == 'equipment_id',
    );
    if (equipmentLink.isEmpty) return;
    // Only the initial schema's action is rewritten. SET NULL is done; any
    // other action is not this rung's to change.
    final action = equipmentLink.first.read<String>('on_delete').toUpperCase();
    if (action != 'NO ACTION' && action != 'RESTRICT') return;

    final stored = await customSelect(
      "SELECT sql FROM sqlite_master WHERE type = 'table' "
      "AND name = 'dive_tanks'",
    ).getSingle();
    final createSql = stored.read<String>('sql');
    // The column's own clause only: the character before it must not be a
    // name character, so regulator_equipment_id is never matched, and the
    // clause must end the column definition, so a clause followed by any
    // other action is not matched at all.
    final clause = RegExp(
      r'''(^|[\s,(])("?equipment_id"?\s+TEXT(?:\s+NULL)?\s+REFERENCES\s+'''
      r'''"?equipment"?\s*\(\s*"?id"?\s*\))(\s+ON\s+DELETE\s+'''
      r'''(?:NO\s+ACTION|RESTRICT))?(?=\s*[,)])''',
      caseSensitive: false,
    );
    final header = RegExp(
      r'^CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?"?dive_tanks"?',
      caseSensitive: false,
    );
    if (clause.allMatches(createSql).length != 1 ||
        !header.hasMatch(createSql)) {
      developer.log(
        'dive_tanks.equipment_id: stored definition not in a recognised '
        'shape, left as NO ACTION',
        name: 'AppDatabase',
      );
      return;
    }
    const scratch = 'dive_tanks_v210';
    final rebuiltSql = createSql
        .replaceFirstMapped(clause, (m) => '${m[1]}${m[2]} ON DELETE SET NULL')
        .replaceFirst(header, 'CREATE TABLE $scratch');
    final dependents = await customSelect(
      "SELECT sql FROM sqlite_master WHERE tbl_name = 'dive_tanks' "
      "AND type IN ('index', 'trigger') AND sql IS NOT NULL",
    ).get();

    Future<bool> enforced() async =>
        (await customSelect(
          'PRAGMA foreign_keys',
        ).getSingle()).read<int>('foreign_keys') ==
        1;
    final wasEnforced = await enforced();
    if (wasEnforced) {
      await customStatement('PRAGMA foreign_keys = OFF');
      // A no-op inside a transaction. Refuse rather than cascade.
      if (await enforced()) {
        developer.log(
          'dive_tanks.equipment_id: foreign keys could not be switched off, '
          'rebuild deferred to a later open',
          name: 'AppDatabase',
        );
        return;
      }
    }
    try {
      await transaction(() async {
        await customStatement('DROP TABLE IF EXISTS $scratch');
        await customStatement(rebuiltSql);
        await customStatement('INSERT INTO $scratch SELECT * FROM dive_tanks');
        await customStatement('DROP TABLE dive_tanks');
        await customStatement('ALTER TABLE $scratch RENAME TO dive_tanks');
        for (final row in dependents) {
          await customStatement(row.read<String>('sql'));
        }
      });
    } finally {
      if (wasEnforced) await customStatement('PRAGMA foreign_keys = ON');
    }
  }

  /// v132 data fix: older imports (Subsurface/MacDive/CSV routed through the
  /// UDDF entity importer) seeded `bottom_time` from the total-time `duration`,
  /// so bottom time was stored equal to `runtime`. For any such dive that also
  /// carries a profile, recompute bottom time from the PRIMARY profile the same
  /// way [Dive.calculateBottomTimeFromProfile] does (time at/above 85% of max
  /// depth) and correct it only when the derived value is shorter than runtime.
  ///
  /// Deterministic on every device, so `hlc` is left untouched and no sync
  /// traffic is needed to converge (LWW falls back to the existing hlc /
  /// updated_at, exactly like the v124 legacy-attribute copy). PRAGMA-guarded
  /// for minimal old-schema fixtures. onUpgrade only -- never beforeOpen -- so
  /// a dive a user deliberately left with bottom_time == runtime (and no
  /// profile to prove otherwise) is never re-touched.
  Future<void> _backfillBottomTimeFromProfile() async {
    // PRAGMA-guarded like every other migration helper: minimal old-schema
    // test fixtures (and any DB that reached this block through a guarded
    // path) may lack the tables or the specific columns this reads, in which
    // case there is simply nothing to backfill.
    final diveCols = await customSelect("PRAGMA table_info('dives')").get();
    final diveColNames = diveCols.map((c) => c.read<String>('name')).toSet();
    if (!diveColNames.contains('bottom_time') ||
        !diveColNames.contains('runtime')) {
      return;
    }
    final profileCols = await customSelect(
      "PRAGMA table_info('dive_profiles')",
    ).get();
    final profileColNames = profileCols
        .map((c) => c.read<String>('name'))
        .toSet();
    if (!profileColNames.contains('dive_id') ||
        !profileColNames.contains('is_primary') ||
        !profileColNames.contains('timestamp') ||
        !profileColNames.contains('depth')) {
      return;
    }

    final candidates = await customSelect(
      'SELECT id, runtime FROM dives '
      'WHERE bottom_time IS NOT NULL AND runtime IS NOT NULL '
      'AND bottom_time = runtime',
    ).get();

    var processed = 0;
    for (final candidate in candidates) {
      // On an imported library nearly every dive is a candidate, and during a
      // migration the executor is a synchronous main-isolate NativeDatabase:
      // drift's awaits complete in microtasks, so this loop would run as one
      // unbroken microtask chain that never reaches the timer/vsync queue —
      // freezing the migration spinner for the whole step. A real event-loop
      // yield every few dives lets the UI animate while the backfill runs.
      if (processed++ % 25 == 24) {
        await Future<void>.delayed(Duration.zero);
      }
      final diveId = candidate.read<String>('id');
      final runtimeSeconds = candidate.read<int>('runtime');

      // Primary profile rows only, mirroring the domain profile hydration in
      // DiveRepositoryImpl (is_primary = 1); mixing a secondary computer's rows
      // would compute the wrong bottom window.
      final points = await customSelect(
        'SELECT timestamp, depth FROM dive_profiles '
        'WHERE dive_id = ? AND is_primary = 1 '
        'ORDER BY timestamp ASC',
        variables: [Variable<String>(diveId)],
      ).get();

      final bottomSeconds = _bottomTimeSecondsFromProfileRows(points);
      if (bottomSeconds != null && bottomSeconds < runtimeSeconds) {
        await customStatement('UPDATE dives SET bottom_time = ? WHERE id = ?', [
          bottomSeconds,
          diveId,
        ]);
      }
    }
  }

  /// Bottom time in seconds from timestamp-ordered profile rows, replicating
  /// [Dive.calculateBottomTimeFromProfile]: the span between the first and last
  /// samples at/above 85% of max depth. Returns null when the profile is too
  /// small or lacks a clear bottom window.
  int? _bottomTimeSecondsFromProfileRows(List<QueryRow> points) {
    if (points.length < 3) return null;

    var maxDepth = 0.0;
    for (final point in points) {
      final depth = point.read<double>('depth');
      if (depth > maxDepth) maxDepth = depth;
    }
    if (maxDepth <= 0) return null;

    final threshold = maxDepth * 0.85;

    int? descentEnd;
    for (final point in points) {
      if (point.read<double>('depth') >= threshold) {
        descentEnd = point.read<int>('timestamp');
        break;
      }
    }

    int? ascentStart;
    for (var i = points.length - 1; i >= 0; i--) {
      if (points[i].read<double>('depth') >= threshold) {
        ascentStart = points[i].read<int>('timestamp');
        break;
      }
    }

    if (descentEnd == null || ascentStart == null) return null;
    if (ascentStart <= descentEnd) return null;
    return ascentStart - descentEnd;
  }

  /// v146 data fix: the retired bottom-time heuristic (time at/above 85% of
  /// max depth -- kept frozen above in [_bottomTimeSecondsFromProfileRows])
  /// collapsed multilevel dives to their deepest segment: 10 min at 29 m
  /// followed by 40 min at 15 m reported ~9 min of bottom time. For any dive
  /// whose stored bottom_time exactly reproduces the old heuristic's output
  /// for its primary profile (in practice machine-derived by an import,
  /// download, or the v132 backfill; a user-typed value that coincidentally
  /// reproduces it is recomputed too, which still yields a
  /// profile-consistent result), recompute it with the multilevel-correct
  /// rule in [_multilevelBottomTimeSecondsFromProfileRows].
  ///
  /// Both algorithms are frozen private copies so every device computes
  /// identical values no matter which app version it migrates with; `hlc`
  /// is left untouched (deterministic local recompute, no sync traffic
  /// needed to converge, exactly like v132). onUpgrade only.
  Future<void> _recomputeMultilevelBottomTimes() async {
    final diveCols = await customSelect("PRAGMA table_info('dives')").get();
    final diveColNames = diveCols.map((c) => c.read<String>('name')).toSet();
    if (!diveColNames.contains('bottom_time')) {
      return;
    }
    final profileCols = await customSelect(
      "PRAGMA table_info('dive_profiles')",
    ).get();
    final profileColNames = profileCols
        .map((c) => c.read<String>('name'))
        .toSet();
    if (!profileColNames.contains('dive_id') ||
        !profileColNames.contains('is_primary') ||
        !profileColNames.contains('timestamp') ||
        !profileColNames.contains('depth')) {
      return;
    }

    final candidates = await customSelect(
      'SELECT id, bottom_time FROM dives WHERE bottom_time IS NOT NULL',
    ).get();

    var processed = 0;
    for (final candidate in candidates) {
      // Same event-loop yield as the v132 backfill: during a migration the
      // executor completes drift awaits in microtasks, so an unbroken loop
      // would freeze the migration progress spinner.
      if (processed++ % 25 == 24) {
        await Future<void>.delayed(Duration.zero);
      }
      final diveId = candidate.read<String>('id');
      final storedSeconds = candidate.read<int>('bottom_time');

      final points = await customSelect(
        'SELECT timestamp, depth FROM dive_profiles '
        'WHERE dive_id = ? AND is_primary = 1 '
        'ORDER BY timestamp ASC',
        variables: [Variable<String>(diveId)],
      ).get();

      // Fingerprint check: a value reproducing the old heuristic is
      // treated as machine-written and replaced (a coincidental user match
      // is recomputed too); anything else is user data and stays.
      final oldSeconds = _bottomTimeSecondsFromProfileRows(points);
      if (oldSeconds == null || oldSeconds != storedSeconds) continue;

      final newSeconds = _multilevelBottomTimeSecondsFromProfileRows(points);
      if (newSeconds != null && newSeconds != storedSeconds) {
        await customStatement('UPDATE dives SET bottom_time = ? WHERE id = ?', [
          newSeconds,
          diveId,
        ]);
      }
    }
  }

  /// Multilevel-correct bottom time in seconds from timestamp-ordered
  /// profile rows: surface departure (first sample) to the last sample
  /// at/deeper than min(max(6 m, 33% of max depth), 85% of max depth).
  /// Frozen copy of the v146-era BottomTimeCalculator so the migration is
  /// deterministic across app versions; do not sync with later changes to
  /// the domain calculator.
  int? _multilevelBottomTimeSecondsFromProfileRows(List<QueryRow> points) {
    if (points.length < 3) return null;

    var maxDepth = 0.0;
    for (final point in points) {
      final depth = point.read<double>('depth');
      if (depth > maxDepth) maxDepth = depth;
    }
    if (maxDepth <= 0) return null;

    var threshold = maxDepth * 0.33;
    if (threshold < 6.0) threshold = 6.0;
    final cap = maxDepth * 0.85;
    if (threshold > cap) threshold = cap;

    int? ascentStart;
    for (var i = points.length - 1; i >= 0; i--) {
      if (points[i].read<double>('depth') >= threshold) {
        ascentStart = points[i].read<int>('timestamp');
        break;
      }
    }
    if (ascentStart == null) return null;

    final firstTimestamp = points.first.read<int>('timestamp');
    final bottomSeconds = ascentStart - firstTimestamp;
    return bottomSeconds > 0 ? bottomSeconds : null;
  }

  /// Idempotent DDL for the v137 weather code column. Called from the v137
  /// onUpgrade step and the beforeOpen backstop, matching the
  /// _assertMediaStoreSchema pattern so a schema-version collision cannot
  /// strand a database without it. Self-guarding when the table is absent
  /// (minimal migration-test fixtures).
  Future<void> _assertWeatherCodeColumn() async {
    final cols = await customSelect("PRAGMA table_info('dives')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('weather_code')) {
      await customStatement(
        'ALTER TABLE dives ADD COLUMN weather_code INTEGER',
      );
    }
  }

  /// Idempotent DDL for the v144 dives.visibility_meters column. Called from
  /// the v144 onUpgrade step and the beforeOpen backstop, matching the
  /// _assertTripReturnFlightColumn pattern so a schema-version collision
  /// cannot strand a database without it. Self-guarding when the table is
  /// absent (minimal migration-test fixtures).
  ///
  /// Deliberately does not backfill the legacy `visibility` bucket: a bucket
  /// only says the dive fell somewhere in a range, so deriving a number would
  /// fabricate precision the diver never entered.
  Future<void> _assertVisibilityMetersColumn() async {
    final cols = await customSelect("PRAGMA table_info('dives')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('visibility_meters')) {
      await customStatement(
        'ALTER TABLE dives ADD COLUMN visibility_meters REAL',
      );
    }
  }

  /// v179: site_suggestion_dismissed_at on dives. Null means the site
  /// suggestion (from photo GPS or dive-computer GPS) was never dismissed.
  Future<void> _assertSiteSuggestionDismissedAtColumn() async {
    final cols = await customSelect("PRAGMA table_info('dives')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('site_suggestion_dismissed_at')) {
      await customStatement(
        'ALTER TABLE dives ADD COLUMN site_suggestion_dismissed_at INTEGER',
      );
    }
  }

  /// Idempotent DDL for the v168 buddies.is_favorite column (issue #638),
  /// letting frequently-dived buddies be pinned to the top of the "Add
  /// buddy" picker regardless of sort. Self-guards on the table existing, and
  /// defaults every pre-existing row to not-favorited.
  /// Idempotent DDL for the v180 dives.excluded_from_stats and
  /// dives.excluded_from_gas_stats columns (issues #526 and #1272), letting a
  /// diver keep a dive in the logbook while removing it from statistics.
  /// Self-guards on the table existing, and defaults every pre-existing row to
  /// included. Same dual-call contract (onUpgrade + beforeOpen backstop) as
  /// the other column-assert helpers.
  Future<void> _assertDiveStatsExclusionColumns() async {
    final cols = await customSelect("PRAGMA table_info('dives')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('excluded_from_stats')) {
      await customStatement(
        'ALTER TABLE dives ADD COLUMN excluded_from_stats '
        'INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (!names.contains('excluded_from_gas_stats')) {
      await customStatement(
        'ALTER TABLE dives ADD COLUMN excluded_from_gas_stats '
        'INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  /// Idempotent DDL for the v182 pre_dive_session_items.overdue_services
  /// column (issue #814 phase 2): the frozen snapshot of overdue-service
  /// entries for a resolved checklist item, written by the repository the
  /// moment an item leaves pending and cleared on reset. Self-guards on the
  /// table existing. Same dual-call contract (onUpgrade + beforeOpen
  /// backstop) as the other column-assert helpers.
  /// Idempotent DDL for the v194 dive_tanks.transmitter_serial column. Called
  /// from the v194 rung and re-asserted in beforeOpen (parallel-branch
  /// version-collision backstop) like the other column-assert helpers.
  Future<void> _assertTankTransmitterSerialColumn() async {
    final cols = await customSelect("PRAGMA table_info('dive_tanks')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.contains('transmitter_serial')) return;
    await customStatement(
      'ALTER TABLE dive_tanks ADD COLUMN transmitter_serial TEXT',
    );
  }

  /// Idempotent DDL for the v254 dive_tanks.role_source column (issue
  /// #2595). Called from the v254 rung and re-asserted in beforeOpen like
  /// the other column-assert helpers.
  Future<void> _assertTankRoleSourceColumn() async {
    final cols = await customSelect("PRAGMA table_info('dive_tanks')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (names.contains('role_source')) return;
    await customStatement('ALTER TABLE dive_tanks ADD COLUMN role_source TEXT');
  }

  /// One-time clear of weather descriptions this app generated itself.
  ///
  /// Only rows whose weather_source is 'openMeteo' are touched -- those are
  /// the English, metric strings the old WeatherMapper built and persisted.
  /// They are now rendered at display time from the structured fields, so the
  /// frozen copy would override the localized one. Manually entered and
  /// imported descriptions are user data and are left verbatim.
  Future<void> _clearGeneratedWeatherDescriptions() async {
    final cols = await customSelect("PRAGMA table_info('dives')").get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    if (!names.contains('weather_source') ||
        !names.contains('weather_description')) {
      return;
    }
    await customStatement(
      "UPDATE dives SET weather_description = NULL "
      "WHERE weather_source = 'openMeteo'",
    );
  }

  /// Test-only wrapper. The column assert is exercised through beforeOpen, but
  /// the one-time clear only runs on upgrade, so it needs a direct handle.
  Future<void> clearGeneratedWeatherDescriptionsForTesting() =>
      _clearGeneratedWeatherDescriptions();
}
