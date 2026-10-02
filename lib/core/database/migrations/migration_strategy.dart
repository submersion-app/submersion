part of 'app_database_migrations.dart';

/// Assembles what [AppDatabase.migration] returns.
extension AppDatabaseMigrationStrategy on AppDatabase {
  /// The strategy drift runs when it opens this database.
  MigrationStrategy buildMigrationStrategy() {
    return MigrationStrategy(
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      beforeOpen: _beforeOpen,
    );
  }

  Future<void> _onCreate(Migrator m) async {
    await m.createAll();

    // Seed built-in dive types (the same set the v93 migration backfills
    // for databases created before this seed existed).
    await customStatement(kSeedBuiltInDiveTypesSql);

    // Seed built-in dive roles (the v103 migration backfills these for
    // upgraded databases).
    await customStatement(kSeedBuiltInDiveRolesSql);

    // Seed built-in pre-dive checklist templates (the v127 migration
    // backfills these for upgraded databases).
    await _seedBuiltInPreDiveTemplates();

    // Seed built-in service kinds (the v122 migration backfills these
    // for upgraded databases; beforeOpen re-asserts).
    await customStatement(kSeedBuiltInServiceKindsSql);

    // Tag uniqueness indexes (v149, issue #1032): createAll() never builds
    // raw-SQL indexes, so a fresh install would otherwise be the one
    // device in the library without them.
    await assertTagUniqueness(this);

    // Dive-type junction uniqueness index (v178, issue #1360): same
    // reason as the tag indexes above -- createAll() does not build
    // raw-SQL indexes.
    await assertDiveTypeUniqueness(this);

    // Built-in site types and the site junction unique indexes (v217,
    // issue #1765). createAll() builds the tables but never raw-SQL
    // indexes or seeds.
    await customStatement(kSeedBuiltInSiteTypesSql);
    await assertSiteClassificationUniqueness(this);

    // Equipment tag junction unique index (v219, issue #1942), for the
    // same reason: createAll() never builds raw-SQL indexes.
    await assertEquipmentTagUniqueness(this);

    // Equipment share pair unique index (v234, issue #2046), for the
    // same reason.
    await assertEquipmentShareUniqueness(this);
  }

  /// Runs every rung above [from], oldest first. The rungs are split
  /// across the files under `ladder/` by version range, and must run in
  /// that order.
  Future<void> _onUpgrade(Migrator m, int from, int to) async {
    int completedSteps = 0;
    final totalSteps = AppDatabase.migrationStepCount(from);

    Future<void> reportProgress() async {
      completedSteps++;
      onMigrationProgress?.call(completedSteps, totalSteps);
      // Yield to the event loop so the UI can repaint (update the progress
      // bar). With synchronous NativeDatabase, DDL blocks the main thread
      // during each step, but this yield between steps gives the framework
      // a chance to schedule a frame after setState.
      await Future<void>.delayed(Duration.zero);
    }

    await _rungsV2ToV29(m, from, reportProgress);
    await _rungsV30ToV54(m, from, reportProgress);
    await _rungsV55ToV71(m, from, reportProgress);
    await _rungsV72ToV95(m, from, reportProgress);
    await _rungsV96ToV148(m, from, reportProgress);
    await _rungsV149ToV230(m, from, reportProgress);
    await _rungsFromV231(m, from, reportProgress);
  }
}
