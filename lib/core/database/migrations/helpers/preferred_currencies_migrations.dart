part of '../app_database_migrations.dart';

/// The currencies a diver lists first in the currency pickers (v395, issue
/// #4997).
extension PreferredCurrenciesMigrations on AppDatabase {
  /// `diver_settings.preferred_currency_codes` (v395, issue #4997). Nullable,
  /// no backfill: null reads as the built-in defaults. Safe from both the
  /// v395 rung and the beforeOpen backstop.
  Future<void> _assertPreferredCurrencyCodesColumn() =>
      _addColumnIfMissing('diver_settings', 'preferred_currency_codes', 'TEXT');
}
