part of '../app_database_migrations.dart';

/// Whether a dive card shows one of the dive's photos behind its text. Off
/// for every diver, existing ones included: the column is new, so no saved
/// choice is overwritten.
extension DiveCardPhotoMigrations on AppDatabase {
  /// v343: diver_settings.show_photo_background_on_dive_cards and the
  /// overlay opacity for each theme. Idempotent; called from the rung and
  /// the beforeOpen backstop.
  Future<void> _assertDiveCardPhotoBackgroundColumn() async {
    await _addColumnIfMissing(
      'diver_settings',
      'show_photo_background_on_dive_cards',
      'INTEGER NOT NULL DEFAULT 0 '
          'CHECK (show_photo_background_on_dive_cards IN (0, 1))',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'card_photo_overlay_dark',
      'REAL NOT NULL DEFAULT 0.6',
    );
    await _addColumnIfMissing(
      'diver_settings',
      'card_photo_overlay_light',
      'REAL NOT NULL DEFAULT 0.6',
    );
  }
}
