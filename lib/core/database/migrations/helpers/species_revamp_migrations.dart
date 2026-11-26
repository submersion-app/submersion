part of '../app_database_migrations.dart';

/// Species covers and ID practice (issue #5027).
extension SpeciesRevampMigrations on AppDatabase {
  /// Idempotent v383 schema: species_covers and species_practice. Called
  /// from the v383 rung and the beforeOpen backstop. Skipped on a partial
  /// migration-test fixture that lacks the tables their keys point at.
  Future<void> _assertSpeciesRevampSchema() async {
    if (!await _tableExists('divers')) return;
    if (!await _tableExists('species')) return;
    await Migrator(this).createTable(speciesCovers);
    await Migrator(this).createTable(speciesPractice);
  }
}
