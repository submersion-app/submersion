import 'package:submersion/core/database/database.dart';

/// Copies each library site's newest private notes and rating (from any
/// local profile) onto the site's row (issue #2567). Library site rows are
/// outside personal sync and the notes outside the library document, so
/// this is how notes written on a profile's other device reach this one.
/// Written straight to the row: neither a library edit nor a personal one.
Future<void> applyLibrarySiteNotes(AppDatabase db) async {
  const newest =
      'FROM library_site_notes n WHERE n.site_id = dive_sites.id '
      'ORDER BY n.updated_at DESC LIMIT 1';
  await db.customUpdate(
    'UPDATE dive_sites SET '
    'notes = (SELECT n.notes $newest), '
    'rating = (SELECT n.rating $newest) '
    'WHERE shared_library_id IS NOT NULL '
    'AND id IN (SELECT site_id FROM library_site_notes) '
    'AND (notes IS NOT (SELECT n.notes $newest) '
    'OR rating IS NOT (SELECT n.rating $newest))',
    updates: {db.diveSites},
  );
}
