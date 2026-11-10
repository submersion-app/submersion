import 'package:drift/drift.dart';

/// Puts every dive's rating back on the 1 to 5 star scale (v358, #4415), and
/// returns how many dives it rewrote.
///
/// A UDDF import stored the file's 1 to 10 `<ratingvalue>` as it was, and 0
/// for an unrated dive. The edit form saves neither, so a stored value says
/// which it is: above 5 is halved, a half star rounding up and the result
/// capped at 5, and 0 or below becomes null. A rating of 2 or 4 that came from
/// a 1 to 10 file cannot be told apart from a star count and stays. This is
/// `DiveRatingScale.normalize` in SQL; keep the two in step.
///
/// Cheap enough to run again after every inbound sync apply, which is how a
/// row from a peer below v358, which can still import such a file, gets the
/// same repair. The sync stamp (`updated_at`, `hlc`) does not move: every
/// device runs this same rewrite, so they agree without a sync round.
///
/// Raw SQL, as the other ladder helpers, so it keeps compiling against any
/// later shape of the generated classes.
Future<int> repairOutOfScaleDiveRatings(DatabaseConnectionUser db) =>
    db.customUpdate(
      'UPDATE dives SET rating = CASE '
      'WHEN rating > 5 THEN MIN(5, (rating + 1) / 2) '
      'ELSE NULL END '
      'WHERE rating > 5 OR rating <= 0',
    );
