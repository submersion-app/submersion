import 'package:submersion/core/database/database.dart';

/// Copies onto each library site's row what its profiles keep for it
/// (issue #2567): the newest private notes and rating from any local
/// profile, and the newest built-in catalogue link and answers any of them
/// holds. Library site rows are outside personal sync and all four are
/// outside the library document, so this is how what a profile wrote on
/// its other device reaches this one. Written straight to the row: neither
/// a library edit nor a personal one.
///
/// A record with no link, or no answers, never clears the row's: a profile
/// that only wrote notes has said nothing about the catalogue.
Future<void> applyLibrarySiteNotes(AppDatabase db) async {
  const ofThisSite =
      'FROM library_site_notes n WHERE n.site_id = dive_sites.id';
  const newest = '$ofThisSite ORDER BY n.updated_at DESC LIMIT 1';
  String newestWith(String column) =>
      'COALESCE((SELECT n.$column $ofThisSite AND n.$column IS NOT NULL '
      'ORDER BY n.updated_at DESC LIMIT 1), $column)';
  final link = newestWith('catalogue_id');
  final answers = newestWith('catalogue_answers');
  await db.customUpdate(
    'UPDATE dive_sites SET '
    'notes = (SELECT n.notes $newest), '
    'rating = (SELECT n.rating $newest), '
    'catalogue_id = $link, '
    'catalogue_answers = $answers '
    'WHERE shared_library_id IS NOT NULL '
    'AND id IN (SELECT site_id FROM library_site_notes) '
    'AND (notes IS NOT (SELECT n.notes $newest) '
    'OR rating IS NOT (SELECT n.rating $newest) '
    'OR catalogue_id IS NOT $link '
    'OR catalogue_answers IS NOT $answers)',
    updates: {db.diveSites},
  );
}
