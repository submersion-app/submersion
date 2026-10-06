part of '../app_database_migrations.dart';

/// Certification currency: the rule catalog, its overrides and its ledger.
extension CertificationCurrencyMigrations on AppDatabase {
  /// v271 (issue #2267): the certification currency tables and the built-in
  /// rule catalog. Idempotent; called from the rung AND the beforeOpen
  /// backstop. Parallel branches have collided on this ladder before, and a
  /// device that upgraded across a collision can arrive with the rung
  /// recorded and the tables absent. The seed is INSERT OR IGNORE, so it
  /// heals a stranded catalog without rewriting a rule the diver tuned.
  /// Sync adopt clears every synced entity and refills from an export that
  /// omits built-ins, so the beforeOpen re-seed is what keeps the catalog
  /// alive across an adopt.
  ///
  /// Skipped on a partial migration-test fixture that lacks a parent table,
  /// so a fixture written for an older rung does not gain tables whose
  /// foreign keys point nowhere.
  Future<void> _assertCertificationCurrencySchema() async {
    for (final parent in const ['certifications', 'divers']) {
      if (!await _tableExists(parent)) return;
    }
    await Migrator(this).createTable(certificationCurrencyRules);
    await Migrator(this).createTable(certificationCurrencyPrefs);
    await Migrator(this).createTable(certificationCurrencyEvents);
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_certification_currency_prefs_cert '
      'ON certification_currency_prefs(certification_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_certification_currency_events_cert '
      'ON certification_currency_events(certification_id)',
    );
    await customStatement(kSeedBuiltInCurrencyRulesSql);
  }
}
