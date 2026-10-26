part of '../app_database_migrations.dart';

/// The dive-level tissue state a dive computer reports
/// (`dives.computer_tissue_json`, issue #1977).
extension ComputerTissueMigrations on AppDatabase {
  /// v318: moves the CNS, OTU and deco model out of stored snapshots into
  /// their own columns (#2555). Guarded on the columns it reads and writes,
  /// as the other helpers are, for migration fixtures that build only part
  /// of the schema: the dive rewrite needs the dive columns, and the source
  /// fill runs only where the sources table has its own.
  Future<void> _moveComputerTissueScalars() async {
    final dives = await customSelect("PRAGMA table_info('dives')").get();
    final diveColumns = dives.map((c) => c.read<String>('name')).toSet();
    final sources = await customSelect(
      "PRAGMA table_info('dive_data_sources')",
    ).get();
    final sourceColumns = sources.map((c) => c.read<String>('name')).toSet();
    if (!diveColumns.containsAll(const [
      'id',
      'computer_tissue_json',
      'cns_start',
      'cns_end',
      'otu',
      'deco_algorithm',
    ])) {
      return;
    }
    await moveComputerTissueScalars(
      this,
      fillSources: sourceColumns.containsAll(const [
        'dive_id',
        'is_primary',
        'cns',
        'otu',
        'deco_algorithm',
      ]),
    );
  }
}
