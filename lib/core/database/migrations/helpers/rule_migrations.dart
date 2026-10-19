part of '../app_database_migrations.dart';

/// Logbook rules and their run history (#3513).
extension RuleMigrations on AppDatabase {
  /// Idempotent creation of the v301 rules tables and their indexes. Called
  /// from the v301 rung and the beforeOpen backstop. Skipped on a partial
  /// migration-test fixture that lacks the divers table the foreign keys
  /// point at.
  Future<void> _assertRuleSchema() async {
    if (!await _tableExists('divers')) return;
    final m = Migrator(this);
    await m.createTable(rules);
    await m.createTable(ruleRuns);
    await m.createTable(ruleRunChanges);
    for (final ddl in const [
      'CREATE INDEX IF NOT EXISTS idx_rules_diver '
          'ON rules(diver_id, subject, sort_order)',
      'CREATE INDEX IF NOT EXISTS idx_rule_runs_diver '
          'ON rule_runs(diver_id, ran_at)',
      'CREATE INDEX IF NOT EXISTS idx_rule_run_changes_run '
          'ON rule_run_changes(run_id, sort_order, rule_name)',
    ]) {
      await customStatement(ddl);
    }
  }
}
