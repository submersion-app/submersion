import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';

/// SQL over a `dives` row for "has the diver written anything of their own
/// onto this dive?", in the two shapes the app asks it in.
///
/// The scalar columns and the seven child tables below are the ones a dive
/// computer download never fills in. Tanks, dive types, profile series and
/// their events are deliberately absent: every download produces them, so
/// their presence says nothing about whether a human has worked on the dive.
///
/// [kDiverDataExistsSql] and [kDiverDataCountsSql] must stay in step. They
/// cannot be one string, because the boolean is inlined into a query that
/// runs for every dive in the library and relies on `OR` short-circuiting,
/// while the counts necessarily evaluate all fourteen tests. `agrees with
/// carriesDiverData` in `diver_data_query_test.dart` walks the signals one at
/// a time and fails if either shape learns about a signal the other has not:
/// a dialog that told a diver a copy holds nothing, while the detector had
/// withheld the repair because it holds something, would be worse than the
/// silence it replaced (#1729).

/// Whether a `dives` row reachable as `dives` in the enclosing query carries
/// anything the diver put there themselves, as a 1/0 expression. `OR`
/// short-circuits, so an annotated dive stops at its first hit instead of
/// running all fourteen tests.
const String kDiverDataExistsSql =
    "(dives.notes IS NOT NULL AND TRIM(dives.notes) != '') "
    'OR dives.rating IS NOT NULL '
    'OR dives.is_favorite = 1 '
    'OR dives.site_id IS NOT NULL '
    'OR dives.trip_id IS NOT NULL '
    'OR dives.dive_center_id IS NOT NULL '
    'OR dives.course_id IS NOT NULL '
    'OR EXISTS (SELECT 1 FROM dive_equipment c WHERE c.dive_id = dives.id) '
    'OR EXISTS (SELECT 1 FROM dive_buddies c WHERE c.dive_id = dives.id) '
    'OR EXISTS (SELECT 1 FROM dive_tags c WHERE c.dive_id = dives.id) '
    'OR EXISTS (SELECT 1 FROM dive_weights c WHERE c.dive_id = dives.id) '
    'OR EXISTS (SELECT 1 FROM dive_custom_fields c '
    'WHERE c.dive_id = dives.id) '
    'OR EXISTS (SELECT 1 FROM sightings c WHERE c.dive_id = dives.id) '
    'OR EXISTS (SELECT 1 FROM media c WHERE c.dive_id = dives.id)';

/// The same signals as a projection list, one column each: how much of every
/// countable kind the dive carries, and a 1/0 for every kind that is simply
/// there or not. Select it against `dives` for one row.
///
/// Every child table is counted whole rather than filtered, so a count can
/// never read as zero where [kDiverDataExistsSql] reads as true. That is why
/// gear counts assembly parts as well as the assemblies themselves (#1487):
/// each row is a link the delete would take with it.
///
/// `media` is the one table split in two, because it holds more than its
/// name suggests: signatures, documents and maps share it with photos and
/// videos. The halves are exact complements (the `COALESCE` keeps a NULL
/// `file_type` from falling out of both), so together they still count every
/// row, and a type added later lands among the attachments rather than being
/// called a photo.
const String kDiverDataCountsSql =
    '(SELECT COUNT(*) FROM dive_equipment c WHERE c.dive_id = dives.id) '
    'AS gear_count, '
    '(SELECT COUNT(*) FROM dive_buddies c WHERE c.dive_id = dives.id) '
    'AS buddy_count, '
    '(SELECT COUNT(*) FROM dive_tags c WHERE c.dive_id = dives.id) '
    'AS tag_count, '
    '(SELECT COUNT(*) FROM dive_weights c WHERE c.dive_id = dives.id) '
    'AS weight_count, '
    '(SELECT COUNT(*) FROM dive_custom_fields c WHERE c.dive_id = dives.id) '
    'AS custom_field_count, '
    '(SELECT COUNT(*) FROM sightings c WHERE c.dive_id = dives.id) '
    'AS sighting_count, '
    '(SELECT COUNT(*) FROM media c WHERE c.dive_id = dives.id '
    "AND c.file_type IN ('photo', 'video')) AS photo_video_count, "
    '(SELECT COUNT(*) FROM media c WHERE c.dive_id = dives.id '
    "AND COALESCE(c.file_type, '') NOT IN ('photo', 'video')) "
    'AS attachment_count, '
    "(dives.notes IS NOT NULL AND TRIM(dives.notes) != '') AS has_notes, "
    '(dives.rating IS NOT NULL) AS has_rating, '
    '(dives.is_favorite = 1) AS has_favorite, '
    '(dives.site_id IS NOT NULL) AS has_site, '
    '(dives.trip_id IS NOT NULL) AS has_trip, '
    '(dives.dive_center_id IS NOT NULL) AS has_dive_center, '
    '(dives.course_id IS NOT NULL) AS has_course';

/// Every table both fragments read, so a write to any of them invalidates a
/// query that carries either one.
Set<ResultSetImplementation<dynamic, dynamic>> diverDataTables(
  AppDatabase db,
) => {
  db.dives,
  db.diveEquipment,
  db.diveBuddies,
  db.diveTags,
  db.diveWeights,
  db.diveCustomFields,
  db.sightings,
  db.media,
};
