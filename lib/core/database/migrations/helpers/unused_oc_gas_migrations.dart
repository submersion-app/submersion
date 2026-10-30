part of '../app_database_migrations.dart';

/// Whether a rebreather download leaves out an open-circuit gas no
/// transmitter read and the diver never breathed (issue #3668). Off for every
/// diver, existing ones included: the column is new, so no saved choice is
/// overwritten.
extension UnusedOcGasMigrations on AppDatabase {
  /// v315: diver_settings.omit_unused_oc_gases. Idempotent; called from the
  /// rung and the beforeOpen backstop.
  Future<void> _assertOmitUnusedOcGasesColumn() async {
    await _addColumnIfMissing(
      'diver_settings',
      'omit_unused_oc_gases',
      'INTEGER NOT NULL DEFAULT 0 CHECK (omit_unused_oc_gases IN (0, 1))',
    );
  }
}
