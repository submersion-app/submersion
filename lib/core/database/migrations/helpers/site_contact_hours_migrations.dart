part of '../app_database_migrations.dart';

/// A dive site's address, contact details and opening hours (v387, issue
/// #5073).
extension SiteContactHoursMigrations on AppDatabase {
  /// The five `dive_sites` columns. All nullable, so an older peer omits
  /// them and a row from before simply has none. Safe from both the v387
  /// rung and the beforeOpen backstop.
  Future<void> _assertSiteContactHoursColumns() async {
    for (final column in const [
      'address',
      'phone',
      'email',
      'website',
      'opening_hours',
    ]) {
      await _addColumnIfMissing('dive_sites', column, 'TEXT');
    }
  }
}
