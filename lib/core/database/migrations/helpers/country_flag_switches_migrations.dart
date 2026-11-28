part of '../app_database_migrations.dart';

/// The Dives, Buddies and Trips country flag switches (v396, issue #5001).
/// Until then `show_country_flags` covered every flag; it now covers sites.
extension CountryFlagSwitchesMigrations on AppDatabase {
  static const _switchColumns = [
    'show_dive_country_flags',
    'show_buddy_country_flags',
    'show_trip_country_flags',
  ];

  /// Adds each switch column, defaulted on. Safe from both the v396 rung
  /// and the beforeOpen backstop; never copies a value.
  Future<void> _assertCountryFlagSwitchColumns() async {
    for (final column in _switchColumns) {
      // The CHECK matches the constraint Drift gives a fresh install's
      // boolean column, so an upgraded database has the same schema.
      await _addColumnIfMissing(
        'diver_settings',
        column,
        'INTEGER NOT NULL DEFAULT 1 CHECK ($column IN (0, 1))',
      );
    }
  }

  /// Ladder only: adds the switch columns and gives each one this rung
  /// creates the diver's existing switch, so a diver who turned flags off
  /// keeps them off on dives, buddies and trips. A column that was already
  /// there keeps its value. Stamps neither updated_at nor the HLC: each
  /// device copies its own row, and a stamp would let one device's upgrade
  /// outrank newer settings from another.
  Future<void> _seedCountryFlagSwitches() async {
    final present = await tableColumnNames(this, 'diver_settings');
    if (present.isEmpty) return; // partial fixture database: table absent
    final created = [
      for (final column in _switchColumns)
        if (!present.contains(column)) column,
    ];
    await _assertCountryFlagSwitchColumns();
    if (created.isEmpty || !present.contains('show_country_flags')) return;
    await customStatement(
      'UPDATE diver_settings SET '
      '${created.map((c) => '$c = show_country_flags').join(', ')}',
    );
  }
}
