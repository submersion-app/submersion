part of '../app_database_migrations.dart';

/// A site's stored country code (v360, issue #4426).
extension SiteCountryCodeMigrations on AppDatabase {
  /// `dive_sites.country_code`. Nullable, so an older peer omits it. Safe
  /// from both the v360 rung and the beforeOpen backstop.
  Future<void> _assertSiteCountryCodeColumn() =>
      _addColumnIfMissing('dive_sites', 'country_code', 'TEXT');

  /// Fills `country_code` for every site whose country text names one
  /// country, with the same recognizer the flags use. Offline and
  /// deterministic, so every synced device writes the same codes; a code
  /// already stored (a geocoder's) is left alone. Rung only: a site written
  /// later gets its code from the editor or the geocoder.
  Future<void> _backfillSiteCountryCodes() async {
    // A partial database (a restore, a test fixture) may lack the table or
    // its columns; there is then nothing to fill.
    final columns = {
      for (final column in await customSelect(
        "PRAGMA table_info('dive_sites')",
      ).get())
        column.read<String>('name'),
    };
    if (!columns.contains('country') || !columns.contains('country_code')) {
      return;
    }
    final rows = await customSelect(
      'SELECT id, country FROM dive_sites '
      'WHERE country_code IS NULL AND country IS NOT NULL',
    ).get();
    for (final row in rows) {
      final code = countryCodeFor(row.read<String>('country'));
      if (code == null) continue;
      await customStatement(
        'UPDATE dive_sites SET country_code = ? WHERE id = ?',
        [code, row.read<String>('id')],
      );
    }
  }
}
