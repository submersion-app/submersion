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
    final columns = await tableColumnNames(this, 'dive_sites');
    if (!columns.containsAll(const {'country', 'country_code'})) return;
    // One write per distinct country text, not per site: a logbook holds
    // thousands of sites in a few dozen countries.
    final rows = await customSelect(
      'SELECT DISTINCT country FROM dive_sites '
      'WHERE country_code IS NULL AND country IS NOT NULL',
    ).get();
    for (final row in rows) {
      final country = row.read<String>('country');
      final code = countryCodeFor(country);
      if (code == null) continue;
      await customStatement(
        'UPDATE dive_sites SET country_code = ? '
        'WHERE country = ? AND country_code IS NULL',
        [code, country],
      );
    }
  }
}
